# LevelEditorPlugin Architecture Guide

Welcome to the **Laser Mind Level Editor Plugin** architectural guide. This document serves as the comprehensive reference for developers working on the Level Editor, the in-editor Play Test system, the shared Laser Core, or the Game runtime.

---

## 1. Overview

`LevelEditorPlugin` is a modular Godot 4 addon designed for building, testing, validating, and managing laser puzzle levels.

The plugin is architecturally divided into three distinct subsystems:
1. **Editor (`editor/`)**: The in-editor visual workstation containing panels, canvases, inspector tools, validators, and analyzers.
2. **Play Test (`playtest/`)**: A self-contained, modal testing sandbox that allows designers to test levels directly inside the editor without launching the full game.
3. **Shared Core (`core/`)**: The single source of truth for level data definitions, object contracts, board math, serialization, and laser physics simulation.

### Fundamental Dependency Rule

```
Editor ───────────────► Core ◄─────────────── Game
Play Test ────────────► Core
```

* **Game uses Core**: The actual game imports data structures, level migration routines, board calculations, and laser physics simulation from `core/`.
* **Game NEVER uses Editor**: The game has **0%** dependency on `editor/` (no UI controls, no plugin scripts, no editor tool code).
* **Game NEVER uses Play Test**: The game runtime never references `playtest/`.
* **Core has ZERO UI dependencies**: The `core/` folder is completely headless and decoupled from Godot Editor UI, making it safe for standalone execution in the shipping game.

---

## 2. Folder Structure

The repository organizes the addon under `addons/LevelEditorPlugin/`:

```
addons/LevelEditorPlugin/
├── plugin.cfg                  # Plugin descriptor pointing to plugin.gd
├── plugin.gd                   # Godot EditorPlugin entry point (instantiates Editor UI)
├── README.md                   # High-level overview
├── ARCHITECTURE_GUIDE.md       # This comprehensive developer reference
│
├── editor/                     # [EDITOR-ONLY] Level creation & editing UI
│   ├── editor_main.gd          # Main editor coordinator script
│   ├── editor_main.tscn        # Main editor workspace scene
│   ├── grid_canvas.gd          # Interactive 2D editing grid canvas
│   ├── inspector_panel.gd      # Object & level property inspector
│   ├── object_palette.gd       # Object placement palette & tool picker
│   ├── level_browser.gd        # Level file browser & manager panel
│   ├── stage_tabs.gd           # Multi-stage navigation bar
│   ├── bottom_panel.gd         # Status bar & validation reporting dock
│   ├── scene_drop_line_edit.gd # Drag-and-drop helper for scene assignment
│   ├── undo_manager.gd         # Editor command history & undo/redo stack
│   ├── level_validator.gd      # Rule-based level validation engine
│   ├── solvability_checker.gd  # Automated solver checking for valid solutions
│   └── difficulty_analyzer.gd  # Heuristic complexity & difficulty analyzer
│
├── core/                       # [SHARED CORE] Headless runtime data & simulation
│   ├── data/
│   │   ├── laser_level_data.gd         # LaserLevelData Resource definition
│   │   ├── laser_stage_data.gd         # LaserStageData Resource definition
│   │   ├── laser_object_data.gd        # LaserObjectData Resource & Enums
│   │   └── custom_elements_manager.gd  # Custom element templates registry
│   │
│   ├── simulation/
│   │   └── laser_simulation.gd         # Unified raycast & laser physics simulation
│   │
│   ├── serialization/
│   │   └── level_migration.gd          # JSON <-> .tres conversion & loading logic
│   │
│   └── board/
│       ├── board_layout_helper.gd      # Dynamic board sizing & grid placement math
│       └── board_visual_generator.gd   # Procedural cell & border visual generator
│
├── playtest/                   # [PLAY TEST] Standalone in-editor test sandbox
│   └── playtest_dialog.gd      # Self-contained modal dialog & lightweight renderer
│
└── assets/                     # [ADDON ASSETS] Default visual themes & SVGs
    └── default/
        ├── cells/              # Grid cell background SVGs (Cell_A, demo_cell_01, etc.)
        ├── borders/            # Outer frame border SVGs (Border_H, Border_V, etc.)
        └── corners/            # Frame corner SVGs (Border_Corner, demo_corner_01, etc.)
```

### Folder Responsibilities At a Glance

| Folder | Purpose | Used By | Required by Game? | Can Game Depend on It? |
| :--- | :--- | :--- | :--- | :--- |
| `editor/` | Level authoring, visual editing, validation, inspector tools | Godot Editor UI | **NO** | **NO** (Strictly Forbidden) |
| `playtest/` | In-editor preview dialog to test levels without starting game | Godot Editor UI | **NO** | **NO** (Strictly Forbidden) |
| `core/` | Single source of truth for level models, simulation, and board math | Editor, Play Test, Game | **YES** | **YES** (Core Required) |
| `assets/` | Shared default SVG tiles and visual frame assets | Editor, Play Test, Game | **YES** (default assets) | **YES** |

---

## 3. Editor Folder (`editor/`) — EDITOR ONLY

The `editor/` directory contains all visual and analytical components of the editor. Every file in this folder is marked `@tool` and is intended exclusively for the Godot editor workspace.

* [editor_main.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/editor_main.gd) / [editor_main.tscn](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/editor_main.tscn): The central root coordinator. Instantiates the main screen dock, synchronizes panels, handles file load/save requests, and opens the Play Test modal.
* [grid_canvas.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/grid_canvas.gd): The interactive 2D canvas. Manages mouse clicks, drags, object selection, placement tools, tile painting, movable area painting, and visual hint authoring.
* [inspector_panel.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/inspector_panel.gd): The contextual property editor. Displays and mutates properties of selected objects (rotation, color, movable area ID, gate pairing, custom textures) and stage parameters (grid width/height, time limits, theme assets).
* [object_palette.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/object_palette.gd): The tool palette. Houses item buttons for placing mirrors, sources, goals, splitters, switches, gates, glass, walls, and custom objects.
* [level_browser.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/level_browser.gd): The level management dock. Scans level directories, shows thumbnail lists, and lets designers create, duplicate, or delete levels.
* [stage_tabs.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/stage_tabs.gd): Multi-stage navigation bar allowing quick switching between Stage 1, Stage 2, and Stage 3 within a single level.
* [bottom_panel.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/bottom_panel.gd): Status bar showing current cursor coordinates, validation errors, solvability warnings, and difficulty scores.
* [scene_drop_line_edit.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/scene_drop_line_edit.gd): Drag-and-drop helper enabling designers to drag `.tscn` files from Godot's FileSystem dock into inspector line edits.
* [undo_manager.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/undo_manager.gd): Maintains an undo/redo action stack for object creation, deletion, movement, and parameter changes.
* [level_validator.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/level_validator.gd): Evaluates structural level rules (e.g., verifying each stage has a Laser Source, matching Entry/Exit gates, valid targets, no overlapping objects).
* [solvability_checker.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/solvability_checker.gd): Runs automated breadth-first permutation checks against rotatable/movable elements to mathematically prove whether a puzzle is solvable.
* [difficulty_analyzer.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/difficulty_analyzer.gd): Calculates heuristic difficulty scores based on grid size, movable/rotatable count, branch factors, and stage depth.

> **CRITICAL RULE**: The Game runtime must **NEVER** import or reference anything inside `editor/`.

---

## 4. Play Test Folder (`playtest/`) — PLAY TEST ONLY

The `playtest/` directory contains the in-editor isolated sandbox:

* [playtest_dialog.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/playtest/playtest_dialog.gd): A modal window (`AcceptDialog`) containing a custom `PlaytestCanvas`.

### Key Characteristics of Play Test
1. **Zero Game Scene Dependencies**: Play Test **does not instantiate** `GamePlay.tscn`, `BaseObject.gd`, or any actual game nodes. It draws puzzle objects and laser beams using lightweight procedural 2D canvas draw commands (`_draw()`).
2. **Uses Shared Core Directly**: Play Test consumes `LaserLevelData`, `LaserStageData`, `LaserObjectData`, and runs [LaserSimulation](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/simulation/laser_simulation.gd) directly from `core/`.
3. **Identical Rules**: Because Play Test and Game execute the exact same [LaserSimulation](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/simulation/laser_simulation.gd) engine, any laser reflection, refraction, gate unlocking, or switch toggling tested in Play Test is guaranteed to behave identically in the Game.

> **Key Distinction**: `Play Test ≠ Actual Game`. Play Test is an editor-side verification harness, whereas Game is the production runtime experience with full scene instantiation, animations, particle effects, and audio.

---

## 5. Shared Core (`core/`) — SHARED LASER SYSTEM

The `core/` folder is the central nervous system of the entire project. It contains zero editor UI code and is consumed equally by **Editor**, **Play Test**, and **Game**.

```
core/
├── data/           # Level and object data definitions
├── simulation/     # Laser physics & raycasting engine
├── serialization/  # Level loading & migration logic
└── board/          # Board layout & visual generation math
```

### 5.1. Core Data (`core/data/`)

* [laser_level_data.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_level_data.gd) (`class_name LaserLevelData`):
  * Root resource containing top-level level properties: `level_id`, `level_number`, `level_name`, `universal_timer`, star thresholds (`star_threshold_1/2/3`), coin rewards, and the `stages` array (`Array[LaserStageData]`).
* [laser_stage_data.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_stage_data.gd) (`class_name LaserStageData`):
  * Represents one stage inside a level (e.g., Stage 1, 2, or 3).
  * Stores `grid_width`, `grid_height`, `time_limit`, `time_bonus`, `objects` (`Array[LaserObjectData]`), `movable_areas` (freeform tile masks), theme asset paths (cells, borders, corners), and optional `hint_path` visual guides.
* [laser_object_data.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_object_data.gd) (`class_name LaserObjectData`):
  * The unified object contract defining every puzzle entity in the game.
  * Contains the canonical `ObjectType` enum: `LASER_SOURCE`, `FIXED_MIRROR`, `ROTATABLE_MIRROR`, `TARGET`, `SPLITTER`, `COLOR_GLASS`, `COLOR_WALL`, `SWITCH`, `SWITCH_GATE`, `ENTRY_GATE`, `EXIT_GATE`, `MOVABLE_OBJECT`, `MOVABLE_AREA`, `WALL`, `CUSTOM`.
  * Encapsulates all object properties: `id`, `grid_pos`, `rotation_deg`, `color`, `movable`, `rotatable`, `movable_area_id`, `target_id` (for switch/gate pairing), `custom_scene_path`, and `custom_properties`.
* [custom_elements_manager.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/custom_elements_manager.gd) (`class_name CustomElementsManager`):
  * Registry managing custom user-defined object presets and `.tscn` bindings.

### 5.2. Core Simulation (`core/simulation/`)

* [laser_simulation.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/simulation/laser_simulation.gd) (`class_name LaserSimulation`):
  * The pure, deterministic laser physics engine.
  * Computes continuous laser traversal paths, handling:
    * **Mirrors**: 90° and 45° angle reflections.
    * **Color Glass / Walls**: Wavelength filtering and tint modification.
    * **Splitters**: Branching 1 incoming beam into 2 concurrent outgoing beams.
    * **Switches & Switch Gates**: State triggers that open or block laser pathways.
    * **Entry & Exit Gates**: Cross-stage continuous laser handoff.
    * **Targets / Goals**: Win condition detection.
  * Used by **Editor** (for solvability & hint paths), **Play Test** (for live testing), and **Game** (for production gameplay).

### 5.3. Core Serialization (`core/serialization/`)

* [level_migration.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/serialization/level_migration.gd) (`class_name LevelMigration`):
  * Handles loading, saving, and format conversions for level files (`.tres` and legacy `.json`).
  * Provides `load_laser_level(path)` which automatically resolves paths and loads complete `LaserLevelData` resources into memory.

### 5.4. Core Board (`core/board/`)

* [board_layout_helper.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/board/board_layout_helper.gd) (`class_name BoardLayoutHelper`):
  * Pure mathematical helper for calculating responsive board scale, cell pixel sizes, margin offsets, and coordinate transformations between grid cells `(x, y)` and viewport pixels `(px_x, px_y)`.
* [board_visual_generator.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/board/board_visual_generator.gd) (`class_name BoardVisualGenerator`):
  * Utility for procedurally building background grid cell tiles, outer frame borders, and corner embellishments from configured SVG assets.

---

## 6. Why Core Is Located Inside the Addon

Godot addons often face an architectural dilemma: should shared models live in `res://Game/Core/` or inside `res://addons/MyPlugin/`?

In this project, `core/` is intentionally housed inside `addons/LevelEditorPlugin/core/` for the following reasons:
1. **Self-Contained Plugin Portability**: The plugin can be distributed to another project as a single standalone folder. Play Test and validation work out of the box without requiring external host project scripts.
2. **Explicit Dependency Boundaries**: Anyone inspecting the addon can immediately see:
   * `editor/` = optional editing tools.
   * `playtest/` = optional test sandbox.
   * `core/` = shared runtime engine.
3. **No Code Duplication**: Placing `core/` here prevents having one `LaserSimulation` in `Game/` and a duplicate copy in `addons/`, eliminating synchronization bugs when puzzle rules are updated.

> **Important**: `core/` is **NOT** Editor-only code. It is runtime-required shared code that happens to reside within the addon folder structure.

---

## 7. Actual Game Dependency on Core

The Game runtime currently depends on the following Core scripts:

```
Game/ ──► addons/LevelEditorPlugin/core/
```

### Specific Game Integrations

1. [GamePlay.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/GamePlay.gd):
   * Loads `LaserLevelData` resources via `LevelMigration.load_laser_level()`.
   * Evaluates laser physics via `LaserSimulation.simulate_stage()`.
   * Reads stage configs (`LaserStageData`) and object definitions (`LaserObjectData`).
2. [board_layout_manager.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/board_layout_manager.gd):
   * `extends "res://addons/LevelEditorPlugin/core/board/board_layout_helper.gd"` to calculate gameplay cell geometry.
3. [board_visual_generator.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/board_visual_generator.gd):
   * `extends "res://addons/LevelEditorPlugin/core/board/board_visual_generator.gd"` to render gameplay board tiles.
4. [Level_001.tres](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Data/LaserMindLevels/Level_001.tres) (and all saved levels):
   * References `res://addons/LevelEditorPlugin/core/data/laser_level_data.gd`, `laser_stage_data.gd`, and `laser_object_data.gd` as `ext_resource` scripts.

### Zero Leakage Verification

* **Game → `editor/` references**: **0** (Verified)
* **Game → `playtest/` references**: **0** (Verified)

---

## 8. Dependency Diagram

```
                 addons/LevelEditorPlugin/
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
         editor/        playtest/         core/
        (UI Only)      (Modal Only)     (Headless)
            │               │               ▲
            │               └───────────────┤
            │                               │
            └───────────────────────────────┤
                                            │
                                            ▲
                                            │
                                          Game/
                                    (Actual Runtime)
```

### Conceptual Model

```
Editor (UI) ──────────► ┌──────────────────────────────────────┐ ◄────────── Game (Runtime)
                        │           SHARED LASER CORE          │
Play Test (Modal) ────► │  • Data Models (Level/Stage/Object)  │
                        │  • Simulation (Laser Physics Engine) │
                        │  • Serialization (LevelMigration)    │
                        │  • Board Math (Layout / Visuals)     │
                        └──────────────────────────────────────┘
```

* **Editor** writes data to Core structures.
* **Play Test** reads Core data and renders with procedural lines.
* **Game** reads Core data and instantiates full runtime gameplay scenes.

---

## 9. Level Data Flow

The lifecycle of a puzzle level flows through the architecture as follows:

```
1. DESIGNER ACTION (Editor UI)
   Designer selects an item from ObjectPalette and clicks a cell on GridCanvas.
   ▼
2. DATA CREATION (Core Data)
   Editor instantiates a LaserObjectData instance (type, grid_pos, rotation_deg, color).
   LaserObjectData is appended to the active LaserStageData.objects array.
   ▼
3. SERIALIZATION (Core Serialization)
   Designer clicks Save. LevelMigration serializes LaserLevelData to a `.tres` resource.
   (e.g., res://Game/Data/LaserMindLevels/Level_001.tres)
   ▼
4. RUNTIME LOADING (Game / Play Test)
   LevelMigration loads the `.tres` file back into LaserLevelData at game startup or stage change.
   ▼
5. SIMULATION (Core Simulation)
   LaserSimulation parses LaserStageData.objects and calculates continuous raycast segments.
   ▼
6. RENDERING (Game Runtime)
   GamePlay passes simulated beam segments to BeamRenderer, spawner creates scene instances for objects.
```

The Editor **never** directly creates gameplay scene instances. It creates a declarative data description of the level, which the Game reads and instantiates.

---

## 10. Walkthrough Example: Adding a Splitter

To understand how the separation functions in practice, follow how a **Splitter** object moves through the pipeline:

1. **Selection in Editor**:
   The user clicks "Splitter" in [object_palette.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/object_palette.gd).
2. **Data Generation**:
   [grid_canvas.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/grid_canvas.gd) instantiates a [LaserObjectData](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_object_data.gd) resource:
   ```gdscript
   var obj = LaserObjectData.new()
   obj.type = LaserObjectData.ObjectType.SPLITTER
   obj.grid_pos = Vector2i(3, 4)
   obj.rotation_deg = 90
   obj.color = Color.WHITE
   ```
3. **Stage Storage**:
   The object is added to `current_stage.objects`.
4. **Saving**:
   [level_migration.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/serialization/level_migration.gd) saves the `LaserLevelData` to `Level_001.tres`.
5. **Play Test Execution**:
   [playtest_dialog.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/playtest/playtest_dialog.gd) calls `LaserSimulation.simulate_stage()`. When the laser strikes `(3, 4)`, simulation creates two outgoing laser raycast branches. `playtest_dialog.gd` renders them using procedural lines.
6. **Game Execution**:
   `GamePlay.gd` loads `Level_001.tres`. `ObjectSpawner` spawns `res://Game/Objects/Scenes/Splitter.tscn` at grid cell `(3, 4)`. `LaserSimulation` calculates the same two branches, and `BeamRenderer` animates the traveling laser beams.

---

## 11. What Can Be Safely Deleted / Exported?

If a developer wants to ship a lightweight game build without any editor tooling:

| Folder / File | Can Be Removed for Game Build? | Reason |
| :--- | :---: | :--- |
| `addons/LevelEditorPlugin/editor/` | **YES** | Contains only editor UI and validation docks. |
| `addons/LevelEditorPlugin/playtest/` | **YES** | Contains only the in-editor testing modal dialog. |
| `addons/LevelEditorPlugin/plugin.cfg` | **YES** (in export) | Plugin manifest ignored in exported PCK. |
| `addons/LevelEditorPlugin/plugin.gd` | **YES** (in export) | EditorPlugin entry point not used by game. |
| `addons/LevelEditorPlugin/core/` | **NO** | The Game currently depends on `core/` for data models and simulation. |
| `addons/LevelEditorPlugin/assets/` | **NO** | Default tile and border SVG assets used by the board generator. |

> **Summary**: To strip the editor from a release build, you can safely remove `editor/` and `playtest/`, but you must retain `core/` and `assets/`.

---

## 12. Sharing the Editor With Another Host Project

When copying `addons/LevelEditorPlugin/` into a completely new Godot project:

### Current Hardcoded vs Portable Paths
* **Portable (Self-Contained)**:
  * All Core data types, simulation, board layout math, and default SVG assets resolve internally via `res://addons/LevelEditorPlugin/...`.
* **Project-Specific Defaults**:
  * Default level save path: `res://Game/Data/LaserMindLevels/` (Configured in `LevelMigration.LEVELS_DIR`).
  * Custom scene folder: `res://Game/Objects/Scenes/` (Scanned by `CustomElementsManager` if present).

### Future Improvement
* A future update can expose an `EditorSettings` or `ProjectSettings` configuration key (e.g. `laser_editor/paths/levels_directory`) so host projects can configure their level paths without touching `level_migration.gd`.

---

## 13. Moving Core Later (Optional Future Migration)

If a team decides in the future to extract `core/` out of `addons/` and into the main game repository (e.g., `res://Game/Core/`):

### Steps Required for a Future Core Migration:
1. Move `addons/LevelEditorPlugin/core/` to `Game/Core/`.
2. Update all `extends` and `preload` paths in `Game/Scripts/` and `addons/LevelEditorPlugin/editor/`.
3. Update `ext_resource` script paths in existing `.tres` level files (or run a migration script).
4. Run `test_runner.gd` to verify 100% test passage.

*(Note: Do not perform this move now. The current structure intentionally keeps Core inside the addon for maximum modularity.)*

---

## 14. Rules for Future Developers

To maintain architectural integrity, follow these 10 Golden Rules:

1. **Never import `editor/` into `Game/`**: The Game must never reference editor scenes, docks, or inspector scripts.
2. **Never import `editor/` into `core/`**: `core/` must remain 100% headless.
3. **Never duplicate `LaserSimulation`**: All laser physics changes must be made in `core/simulation/laser_simulation.gd`. Do not create separate solver logic for Game or Play Test.
4. **Preserve `LaserObjectData` as the single object contract**: When adding a new puzzle object, add its enum value and properties to `laser_object_data.gd` first.
5. **Never reference Game scenes in `playtest/`**: Play Test must remain an independent, lightweight simulation sandbox.
6. **Maintain backward compatibility in `.tres` levels**: Do not arbitrarily rename exported properties in `LaserLevelData`, `LaserStageData`, or `LaserObjectData`.
7. **Keep board math in `BoardLayoutHelper`**: Viewport scaling and grid coordinate conversions belong in `core/board/board_layout_helper.gd`.
8. **Keep default assets in `assets/default/`**: Default SVG tiles must remain available to both Editor and Game.
9. **Always run automated tests before committing**: Execute `test_runner.gd` via Godot headless CLI to ensure all 34+ test suites pass.
10. **Do not delete `core/` when exporting**: If removing editor files for production, keep `core/` intact.

---

## 15. New Developer Quick Guide

| I want to... | Where should I look? |
| :--- | :--- |
| **Modify editor tools, palettes, or UI layout** | [addons/LevelEditorPlugin/editor/](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/editor/) |
| **Add a new puzzle object type** | [core/data/laser_object_data.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_object_data.gd) + [core/simulation/laser_simulation.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/simulation/laser_simulation.gd) |
| **Change laser physics / reflection rules** | [core/simulation/laser_simulation.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/simulation/laser_simulation.gd) |
| **Change level/stage data properties or timers** | [core/data/laser_level_data.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_level_data.gd) and [laser_stage_data.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/core/data/laser_stage_data.gd) |
| **Inspect or tweak in-editor Play Test** | [addons/LevelEditorPlugin/playtest/playtest_dialog.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/playtest/playtest_dialog.gd) |
| **Inspect actual game runtime & visual effects** | [Game/Scripts/GamePlay.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/GamePlay.gd) & [Game/Scripts/beam_renderer.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/Game/Scripts/beam_renderer.gd) |
| **Run automated regression test suites** | [addons/LevelEditorPlugin/test_runner.gd](file:///c:/Users/CT_USER/Documents/GitHub/LaserMindEditor/addons/LevelEditorPlugin/test_runner.gd) |

---

## 16. Architecture Summary

* **The Editor** creates and serializes declarative puzzle data.
* **The Play Test system** tests that data inside the editor using the shared simulation.
* **The Game** loads that data and executes it in the production game loop using the exact same simulation.
* **Editor UI** and **Play Test** are optional development tools.
* **Core** is the shared engine required by both development and runtime.
