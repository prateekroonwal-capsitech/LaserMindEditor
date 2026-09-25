# Laser-Synchronized Multi-Stage Progression Architecture & Centralized Timing Guide

## Overview
This document specifies the authoritative runtime architecture for **Multi-Stage Level Progression** in Laser Mind. 
The core design principles are:

1. **THE LASER IS THE MASTER TIMELINE (CLOCK)**: Stage movement, camera movement, and inter-stage traversal are strictly synchronized to the laser head's real-time world-space position.
2. **ZERO PLAYER CONTROL OVER STAGE ADVANCEMENT**: The player cannot manually change, skip, tap-to-advance, or select the next stage during gameplay. Stages advance **only** when the laser reaches an Exit Gate.
3. **CENTRALIZED DISTANCE-BASED TIMING CONFIGURATION**: All transition timing parameters are controlled from a single centralized component ([`StageTransitionController`](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/stage_transition_controller.gd)) and exposed directly on [`GamePlay.gd`](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/GamePlay.gd).

---

## 1. Centralized Transition Controller & Timing Parameters

All timing relationship logic is encapsulated within [`res://Game/Scripts/stage_transition_controller.gd`](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/stage_transition_controller.gd) and exposed in the Godot Inspector on `GamePlay`:

```gdscript
@export_group("Stage Transition Timing")
@export var transition_start_distance: float = 300.0
@export var laser_travel_speed: float = 650.0
@export var transition_camera_lead: float = 0.0
```

### Parameter Breakdown

| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **`transition_start_distance`** | `float` | `300.0` | **Distance-Based Timing**: The distance (in world pixels) *before* the Exit Gate at which camera/world movement begins. |
| **`laser_travel_speed`** | `float` | `650.0` | **Uniform Speed**: Laser speed in world pixels/second across both puzzle grids and inter-stage world gaps. |
| **`transition_camera_lead`** | `float` | `0.0` | Optional pixel lead offset ahead of the laser head for camera positioning. |

---

## 2. Distance-Based Timing Math

Given a transition from Stage $k$ to Stage $k+1$:
- $D_{\text{exit}}$: Cumulative world distance where the laser hits Stage $k$ Exit Gate.
- $D_{\text{entry}}$: Cumulative world distance where the laser arrives at Stage $k+1$ Entry Gate ($= D_{\text{exit}} + \text{distance}(P_{\text{exit}}, P_{\text{entry}})$).
- $S_{\text{lead}} = \text{transition\_start\_distance}$ (e.g. `300.0` px).

### Transition Window
1. **Transition Start**:
   $$D_{\text{start}} = \max(0.0, D_{\text{exit}} - S_{\text{lead}})$$
2. **Transition End**:
   $$D_{\text{end}} = D_{\text{entry}}$$
3. **Normalized Progress** $p \in [0.0, 1.0]$:
   $$p = \text{clampf}\left(\frac{d - D_{\text{start}}}{D_{\text{end}} - D_{\text{start}}}, 0.0, 1.0\right)$$
4. **Cubic Smoothstep Interpolation**:
   $$s = p^2 \cdot (3.0 - 2.0 \cdot p)$$
   $$\mathbf{P}_{\text{cam}}(d) = \text{lerp}(\mathbf{C}_k, \mathbf{C}_{k+1}, s)$$

### Physical Duration
The transition duration is strictly determined by physical distance and laser speed:
$$T_{\text{transition}} = \frac{D_{\text{end}} - D_{\text{start}}}{\text{laser\_travel\_speed}}$$

---

## 3. Simple Developer Tuning Guide

To tune how the transition feels, you only need to change **`transition_start_distance`** on `GamePlay`:

- **`transition_start_distance = 0.0`**:
  *Meaning*: Camera starts moving **only** when the laser strikes the Exit Gate.
- **`transition_start_distance = 300.0` (Recommended default)**:
  *Meaning*: Camera starts moving **300 pixels before** the laser strikes the Exit Gate. Stage 2 smoothly enters the viewport while the laser is finishing Stage 1 and crossing into Stage 2.
- **`transition_start_distance = 600.0`**:
  *Meaning*: Wide cinematic lead-in; camera begins panning early across the world board.

To change overall laser speed:
- Change **`laser_travel_speed`** (e.g. `800.0`). The laser traversal, inter-stage traversal, and camera movement all speed up proportionally in perfect 1:1 synchronization.

---

## 4. Removed Player Inputs for Stage Changing

To ensure players can never skip or manually advance stages:

1. **Tap / Click to Advance Removed**:
   - In [`GameInputController._handle_press()`](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/game_input_controller.gd), deleted `if stage_cleared: request_next_stage.emit(); return`.
   - Clicking or tapping on empty space, board tiles, or background does nothing to stage state.
2. **Keyboard Number Jumps Removed**:
   - In [`GameInputController.handle_input()`](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/game_input_controller.gd), deleted `KEY_1 .. KEY_9` stage jumping.
3. **Manual `request_next_stage` Signal Removed**:
   - Removed signal and connection from `GamePlay.gd`.
4. **Interactive Objects Retained**:
   - Dragging movable objects within `MOVABLE_AREA` is fully enabled.
   - Tapping rotatable mirrors / splitters is fully enabled.

---

## 5. Execution & Event Flow

```
Player interacts with puzzle objects
        ↓
Laser path calculates through Stage 1
        ↓
Laser head approaches within `transition_start_distance` of Exit Gate
        ↓
StageTransitionController begins camera interpolation towards Stage 2
        ↓
Laser head reaches Exit Gate
        ↓
Asynchronous non-blocking green exit glow triggers (no pause, no delay)
        ↓
Laser head traverses inter-stage world gap at constant `laser_travel_speed`
        ↓
Laser head arrives at Stage 2 Entry Gate (Camera reaches Stage 2 focus simultaneously)
        ↓
Stage metadata (grid origin, cell size, active stage index) switches to Stage 2
        ↓
Laser traverses through Stage 2
        ↓
...
        ↓
Laser reaches FINAL TARGET / GOAL
        ↓
🏆 Entire Level Completed (Celebration flash + next level advancement)
```

---

## 6. Verification & Automated Tests

All **36 test suites** in [`addons/LevelEditorPlugin/test_runner.gd`](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/test_runner.gd) execute headlessly with **100% compliance**:
- **Test 36.1**: Multi-stage continuous path distance chaining.
- **Test 36.2**: Player input isolation (screen clicks/touches during cleared state cannot advance stage).
- **Test 36.3**: Centralized `transition_start_distance` lead-in tuning on `StageTransitionController`.
- **Test 36.4**: Real-time laser-driven camera synchronization and zero-delay entry.
- **Test 36.5**: Final Target authoritative win condition.
