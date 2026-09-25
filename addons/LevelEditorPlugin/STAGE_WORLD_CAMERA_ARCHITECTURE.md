# Continuous Multi-Stage World & Camera Navigation Architecture

This document details the refactored **Continuous Multi-Stage World & Camera Navigation** architecture for **Laser Mind**, transforming multi-stage puzzles from isolated screen swaps into one cohesive, continuous 2D puzzle world.

---

## 1. Previous Architecture vs New Architecture

### Previous Architecture (Screen-Swap / Stage Replacement)
In the previous implementation:
```text
Load Stage 1
    ↓
Spawn Stage 1 Nodes
    ↓
Solve Stage 1
    ↓
Slide Out Stage 1 & Destroy Stage 1 Nodes (queue_free)
    ↓
Spawn Stage 2 Nodes
    ↓
Slide In Stage 2
```
* **Limitation**: Stages replaced each other at the same fixed viewport coordinates. Stages did not coexist in world space, and laser beams could not visually traverse through the world gap between stages.

---

### New Architecture (Continuous Multi-Stage World)
In the refactored implementation:
```text
Load Level Data (LaserLevelData)
    ↓
Calculate World Positions for All Stages (stage_position / transition_direction)
    ↓
All Stage Grids & Puzzle Objects Coexist Simultaneously in World Space
    ↓
Laser Traverses Stage 1
    ↓
Laser Exits Stage 1 & Travels Across World Gap
    ↓
Camera Smoothly Follows Laser Progression to Stage 2
    ↓
Laser Enters Stage 2 Entry Gate
    ↓
Laser Solves Stage 2 & Travels Across World Gap
    ↓
Camera Smoothly Follows Laser Progression to Stage 3
    ↓
Laser Enters Stage 3 & Strikes Final Target
```
* **Advantage**: The entire level exists as **one continuous world**. The player visually experiences the laser traversing across grids while the camera glides smoothly across the world map.

---

## 2. Stage World Position Calculation

Stage positions are determined using editor-configured data from [LaserStageData](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_stage_data.gd):

1. **Stage 1 (Anchor Stage)**:
   * Positioned centered in the primary viewport:
     `origin_1 = compute_auto_center(stage_1)["grid_origin"]`
   * Or at custom `stage_screen_position` if explicitly set in the editor (`> -9000.0`).
2. **Subsequent Stages ($N+1$)**:
   * If `stage_has_custom_position(stage_{N+1})`:
     `origin_{N+1} = stage_{N+1}.stage_screen_position`
   * Otherwise, positioned relative to Stage $N$ based on `stage_{N+1}.stage_transition_direction`:
     * `TransitionDir.RIGHT`: `origin_{N+1} = origin_N + Vector2(step_x, 0)`
     * `TransitionDir.LEFT`: `origin_{N+1} = origin_N + Vector2(-step_x, 0)`
     * `TransitionDir.DOWN`: `origin_{N+1} = origin_N + Vector2(0, step_y)`
     * `TransitionDir.UP`: `origin_{N+1} = origin_N + Vector2(0, -step_y)`
   * `step_x` and `step_y` dynamically accommodate viewport sizing and grid dimensions (`maxf(vp_size.x, grid_w * cell_sz.x + 300.0)`).

---

## 3. How Stages Are Instantiated & Coexist

* **Simultaneous World Instantiation**: When `load_level_by_number()` is called, [GamePlay](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/GamePlay.gd) instantiates puzzle objects for **all stages in the level** at their respective world coordinates.
* **Tracking & Ownership**: Each object's ID is registered in `spawned_nodes[obj.id]` and mapped to its stage index via `object_to_stage_idx[obj.id]`.
* **Board Rendering**: [GridRenderer](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/grid_renderer.gd) draws background tiles, borders, and corner frames for all stages in `stage_world_data` in a single unified draw pass.

---

## 4. Continuous Laser Traversal Across Stages

The laser traversal system operates as **one continuous, unified timeline**:

1. **Stage 1 Beam**: Traverses from `LASER_SOURCE` through Stage 1 puzzle objects until reaching Stage 1 `EXIT_GATE`.
2. **Inter-Stage Transition Beam**: When Stage 1's Exit Gate is hit, a **world transition segment** is added connecting:
   `p_exit_world (Stage 1 Exit Gate)` ──► `p_entry_world (Stage 2 Entry Gate)`
3. **Stage 2 Beam**: Traverses through Stage 2 with the carried laser color and direction until reaching Stage 2 `EXIT_GATE`.
4. **Inter-Stage Transition Beam**: Connects Stage 2 Exit Gate ──► Stage 3 Entry Gate.
5. **Stage 3 Beam**: Traverses Stage 3 puzzle until striking the `GOAL` / `TARGET`.

[BeamRenderer](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/beam_renderer.gd) receives the unified list of world segments and smoothly traverses the entire path at `laser_travel_speed` (default 650 px/s).

---

## 5. Camera Navigation & Fixed UI

### Camera2D Controller
* `Camera2D` is attached to `GamePlay` with `anchor_mode = ANCHOR_MODE_FIXED_TOP_LEFT`.
* Each stage defines a target camera position:
  `camera_pos_i = origin_i - origin_1`
* When a stage is cleared, [GamePlay.pan_camera_to_stage()](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/GamePlay.gd#L705) creates a cubic-eased tween (`Tween.TRANS_CUBIC`, `Tween.EASE_IN_OUT`, 0.7s) to glide the camera smoothly from Stage $N$ to Stage $N+1$.

### Fixed UI Architecture
* **HUD & Hint Dialog**: Fixed to viewport via `CanvasLayer` (Layer 5 for HUD/Hint Button, Layer 25 for Hint Dialog).
* **Background Wallpaper**: Anchored via `CanvasLayer` (Layer -10), preventing the background from drifting as the camera navigates the world.
* **Input Mapping**: Mouse/touch coordinates are mapped from screen space to world space:
  `world_pos = screen_pos + camera.position`

---

## 6. Stage & Laser Lifecycles

| Event | Action in Continuous World |
| :--- | :--- |
| **Level Start** | `LaserLevelData` loaded; all stage world positions computed; all stage nodes spawned in world space. Camera centered on Stage 1. |
| **Stage 1 Solved** | Laser hits Exit Gate. Screen flash plays (+5s bonus). Camera smoothly pans to Stage 2. Laser traverses inter-stage gap. |
| **Stage 2 Active** | Laser enters Stage 2 Entry Gate. Player can drag/rotate Stage 2 objects. |
| **Object Interaction in Stage 2** | `_on_object_modified()` updates node transform; `recalculate_simulation()` re-evaluates continuous laser. **Stage 1 nodes are NOT destroyed.** |
| **Final Target Hit** | Level completed celebration; transitions to next level. |

---

## 7. Direct Answers to Core Architectural Questions

* **Are all stage nodes instantiated?**
  **YES**. All stages in the loaded level have their nodes instantiated at their respective world positions upon level load.
* **Is stage data still loaded all at once?**
  **YES**. `LaserLevelData` and its child `LaserStageData` resources are deserialized once when loading the level file.
* **Is the laser path continuous?**
  **YES**. `BeamRenderer` renders a single continuous beam path spanning Stage 1, the inter-stage world gap, Stage 2, and Stage 3.
* **Is the camera following the laser?**
  **YES**. `Camera2D` smoothly pans from stage to stage as the laser crosses the inter-stage boundaries.
* **Does UI remain fixed?**
  **YES**. All UI controls and dialogs reside on dedicated `CanvasLayer` nodes and stay fixed on screen.
* **Is `StageTransitioner` still required?**
  **NO**. The old screen-swapping `StageTransitioner` has been replaced by the continuous world camera controller in `GamePlay.gd`.

---

## 8. Runtime Flow Diagram

```text
                     [Level Load / LevelMigration]
                                   │
                                   ▼
                       ┌──────────────────────┐
                       │    LaserLevelData    │
                       └───────────┬──────────┘
                                   │ computes world origins (Right / Down / Custom)
                                   ▼
             ┌─────────────────────────────────────────────────┐
             │            CONTINUOUS WORLD SPACE               │
             │                                                 │
             │   ┌─────────────┐        ┌─────────────┐        │
             │   │   STAGE 1   │───────►│   STAGE 2   │        │
             │   │ (Origin 1)  │  Gap   │ (Origin 2)  │        │
             │   └─────────────┘        └──────┬──────┘        │
             │                                 │               │
             │                                 │ Gap (Down)    │
             │                                 ▼               │
             │                          ┌─────────────┐        │
             │                          │   STAGE 3   │        │
             │                          │ (Origin 3)  │        │
             │                          └─────────────┘        │
             └─────────────────────────────────────────────────┘
                                   │
                                   ▼
                       ┌──────────────────────┐
                       │  Camera2D Controller │ (Smoothly pans along laser path)
                       └──────────────────────┘
                                   │
                                   ▼
                       ┌──────────────────────┐
                       │ CanvasLayer (HUD/UI) │ (Fixed to screen viewport)
                       └──────────────────────┘
```

---

## 9. Verification & Test Suite Summary

All 35 automated test suites pass with 100% compliance:
```powershell
& "C:\Users\CT_USER\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --script addons/LevelEditorPlugin/test_runner.gd
```
* **Section 31**: Actual Game Runtime Validation (Passed)
* **Section 32**: Continuous Multi-Stage Laser Flow Validation (Passed)
* **Section 33**: Progressive Multi-Stage Laser Traversal Validation (Passed)
* **Section 34**: Laser Gameplay Refinements (Passed)
* **Section 35**: Continuous Multi-Stage World & Camera Navigation Validation (Passed)
