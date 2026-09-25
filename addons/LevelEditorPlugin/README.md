# LevelEditorPlugin Architecture

This addon is designed with a strict architectural separation between **Editor-Only UI**, **Play Test**, and the **Shared Core**.

```
addons/LevelEditorPlugin/
├── plugin.cfg                  # Plugin metadata pointing to plugin.gd
├── plugin.gd                   # EditorPlugin entry point (instantiates Editor UI)
├── README.md                   # This architectural documentation
│
├── core/                       # SHARED CORE (Runtime-Required by Game & Play Test)
│   ├── data/
│   │   ├── laser_level_data.gd         # LaserLevelData Resource
│   │   ├── laser_stage_data.gd         # LaserStageData Resource
│   │   ├── laser_object_data.gd        # LaserObjectData Resource & Enums
│   │   └── custom_elements_manager.gd  # Custom element templates registry
│   │
│   ├── simulation/
│   │   └── laser_simulation.gd         # Portable Laser Raycast & Physics Simulation
│   │
│   ├── serialization/
│   │   └── level_migration.gd          # Legacy JSON <-> .tres migration helper
│   │
│   └── board/
│       ├── board_layout_helper.gd      # Dynamic board layout & cell measurement math
│       └── board_visual_generator.gd   # Board border & cell rendering utilities
│
├── editor/                     # EDITOR-ONLY (Stripped / Ignored at Game Runtime)
│   ├── editor_main.gd                  # Main editor workspace controller
│   ├── editor_main.tscn                # Main editor scene root
│   ├── grid_canvas.gd                  # Interactive grid canvas & object positioning
│   ├── inspector_panel.gd              # Object & level property inspector
│   ├── object_palette.gd               # Object placement palette & tool selector
│   ├── level_browser.gd                # Level file browser & management panel
│   ├── stage_tabs.gd                   # Multi-stage navigation tabs
│   ├── bottom_panel.gd                 # Status bar & validation reporting panel
│   ├── scene_drop_line_edit.gd         # Drag-and-drop scene line edit helper
│   ├── undo_manager.gd                 # Editor command history & undo/redo stack
│   ├── level_validator.gd              # Level completeness & rule validation
│   ├── difficulty_analyzer.gd          # Heuristic difficulty scoring
│   └── solvability_checker.gd          # Automated puzzle solver & validator
│
├── playtest/                   # PLAY TEST (In-Editor Isolated Playtest Modal)
│   └── playtest_dialog.gd              # Self-contained Play Test modal dialog & canvas
│
└── assets/                     # ADDON ASSETS
    └── default/
        ├── cells/                      # Default cell textures & SVG tiles
        ├── borders/                    # Default border textures & SVG frames
        └── corners/                    # Default corner textures & SVG accents
```

---

## Architectural Dependency Rules

```
Editor ───────────────► Core ◄─────────────── Game
Play Test ────────────► Core
```

1. **Game -> Core**: The game runtime imports level resources (`LaserLevelData`, `LaserStageData`, `LaserObjectData`), simulation (`LaserSimulation`), and board calculation utilities from `core/`.
2. **Game -> NEVER Editor**: The game never references `editor/` or any `EditorPlugin` scripts.
3. **Game -> NEVER Play Test**: The game never references `playtest/`.
4. **Editor -> Core**: The editor consumes data models and simulation from `core/`.
5. **Play Test -> Core**: In-editor Play Test runs against `core/` models and simulation in isolation without depending on Game scenes.
6. **Core Independence**: `core/` has **zero dependencies** on `editor/`, `EditorPlugin`, or editor UI controls.

---

## Portability

If a host project desires to export or ship completely decoupled from the editor addon in the future, the `core/` folder can be copied or relocated directly into the host project's runtime structure without bringing along any editor panels or inspector UI.
