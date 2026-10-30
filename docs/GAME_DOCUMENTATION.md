# Carrom Board 3D — Complete Documentation

> Remaster of an original C++ OpenGL project, rebuilt from scratch in Godot 4.6 with modern architecture, real carrom physics, and full game rules.

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Project Structure](#2-project-structure)
3. [How to Run](#3-how-to-run)
4. [How to Play](#4-how-to-play)
5. [Testing Plan](#5-testing-plan)
6. [Architecture Overview](#6-architecture-overview)
7. [Scripts Reference](#7-scripts-reference)
8. [Scenes Reference](#8-scenes-reference)
9. [Physics Configuration](#9-physics-configuration)
10. [Audio System](#10-audio-system)
11. [Signal Flow](#11-signal-flow)
12. [Game Rules Implemented](#12-game-rules-implemented)
13. [Known Limitations](#13-known-limitations)
14. [Coordinate System](#14-coordinate-system)

---

## 1. Quick Start

**Requirements:**
- Godot 4.6 (Forward Plus renderer)
- Desktop OS (Windows / macOS / Linux)

**Steps:**
1. Open Godot 4.6 editor
2. Import project: `godot/project.godot`
3. Press F5 (or Play button) to run
4. Main menu appears → click **Play**

---

## 2. Project Structure

```
godot/
├── project.godot                     # Engine config, autoloads, physics, input
├── autoload/
│   ├── game_manager.gd               # [Autoload] State machine, rules, scoring
│   └── audio_manager.gd              # [Autoload] Sound pool, collision audio
├── scenes/
│   ├── game/
│   │   ├── main.tscn                 # Game scene — board, camera, lights, HUD
│   │   ├── board.gd                  # Procedural board, pieces, pockets, walls
│   │   ├── striker.gd                # Mouse input, aim indicator
│   │   └── camera_controller.gd      # State-based camera presets + tweens
│   └── ui/
│       ├── main_menu.tscn            # Launch scene — Play / Settings / Quit
│       ├── main_menu.gd              # Menu button handlers
│       ├── hud.tscn                  # HUD overlay — scores, power bar, labels
│       ├── hud.gd                    # UI updates, foul display, game over panel
│       ├── settings.tscn             # Settings — audio toggle
│       └── settings.gd               # Audio toggle handler
└── assets/audio/
    ├── carrom_carrommen_cd.wav       # Piece-piece collision
    ├── Carrom_carrommen_wall.wav     # Piece-wall collision
    ├── carrom_striker_wall.wav       # Striker-wall collision
    ├── carrom_pot_sound.wav          # Pocket sound
    └── carrom_power_bar.wav          # Power charging loop
```

---

## 3. How to Run

### From Godot Editor
1. Open Godot 4.6
2. Click **Import** → navigate to `godot/project.godot` → **Import & Edit**
3. Press **F5** to run (launches `main_menu.tscn`)

### From Command Line
```bash
# macOS (adjust path to your Godot binary)
/Applications/Godot.app/Contents/MacOS/Godot --path godot/

# Linux
godot --path godot/

# Windows
godot.exe --path godot/
```

### Export (Desktop Build)
1. Editor → **Project** → **Export**
2. Add preset: Windows / macOS / Linux
3. Click **Export Project**
4. Choose output path → builds standalone executable

---

## 4. How to Play

### Controls

| State | Action | Input |
|-------|--------|-------|
| Place Striker | Move striker left/right | Mouse movement (X axis) |
| Place Striker | Confirm position | Left click |
| Aim | Adjust angle | Mouse movement (X axis) |
| Aim | Confirm angle | Left click |
| Power | Charge power | Hold (auto-charges) |
| Power | Fire striker | Release left click |
| Any | Reset board | R key |

### Game Flow
1. **Place Striker** — Move mouse to position striker on baseline. Click to confirm.
2. **Aim** — Move mouse left/right to angle the shot (-75 to +75 degrees). Click to confirm.
3. **Power** — Power charges automatically. Release mouse to fire.
4. **Watch** — Pieces collide and settle. Turn resolves automatically.

### Scoring
- Black piece pocketed: **10 pts**
- White piece pocketed: **20 pts**
- Queen (red) pocketed: **50 pts**

### Rules
- **Player 1** = Black pieces, **Player 2** = White pieces
- Pocket your own color → **extra turn**
- Pocket opponent's color → pieces return to board, points deducted
- **Queen** must be "covered" (pocket own piece in same turn after queen)
- Queen uncovered → queen returns to center, lose turn
- **Striker pocketed** = foul → one of your pocketed pieces returns, lose turn
- **Win**: pocket all 9 of your pieces + pocket and cover the queen

---

## 5. Testing Plan

### Phase 1: Basic Launch & Navigation

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 1.1 | Game launches | F5 in editor | Main menu appears with Play/Settings/Quit |
| 1.2 | Play button | Click Play | Game scene loads, board visible, "Place Striker" label |
| 1.3 | Settings | Click Settings | Settings scene with Audio toggle and Back button |
| 1.4 | Audio toggle | Toggle Audio off/on | Game sounds mute/unmute |
| 1.5 | Settings back | Click Back | Returns to main menu |
| 1.6 | Quit button | Click Quit | Application closes |

### Phase 2: Piece Count & Board Visuals

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 2.1 | Piece count | Start game, count pieces visually | 9 black + 9 white + 1 red queen = 19 |
| 2.2 | HUD piece counts | Check P1/P2 labels | "P1 left: 9" and "P2 left: 9" |
| 2.3 | Queen label | Check top-center | "Queen: On Board" |
| 2.4 | Center circle | Look at board center | Torus lies flat on board (not standing upright) |
| 2.5 | Board markings | Look at board | Two horizontal baselines + four diagonal corner lines visible |
| 2.6 | Turn indicator | Check top-center | "Player 1 (Black)" |

### Phase 3: Striker Placement & Aiming

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 3.1 | Placement | Move mouse left/right | Striker slides along bottom baseline |
| 3.2 | Placement clamp | Move mouse to edges | Striker stops at placement zone boundaries |
| 3.3 | Confirm placement | Left click | State changes to "Aim", camera angle shifts |
| 3.4 | Aim control | Move mouse left/right | Dotted aim line follows mouse direction |
| 3.5 | Aim direction P1 | Aim and fire | Striker moves toward board center (-Z direction) |
| 3.6 | Confirm aim | Left click | State changes to "Power", power bar appears |

### Phase 4: Power & Shooting

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 4.1 | Power charging | Hold after confirming aim | Power bar fills, charging sound plays |
| 4.2 | Fire striker | Release mouse button | Striker shoots, charging sound stops |
| 4.3 | Low power | Release immediately | Striker moves slowly |
| 4.4 | Max power | Hold until bar full | Striker moves fast, power caps at 5.0 |
| 4.5 | Simulation label | After firing | "Simulating..." shown |
| 4.6 | Pieces settle | Wait for all pieces to stop | Turn resolves, next player's turn begins |

### Phase 5: Collision Audio

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 5.1 | Piece-piece sound | Striker hits piece | Collision sound plays |
| 5.2 | Piece-wall sound | Piece hits wall | Wall collision sound plays |
| 5.3 | Striker-wall sound | Striker hits wall | Distinct striker-wall sound |
| 5.4 | Volume scaling | Hard vs soft hits | Louder sound for faster collisions |
| 5.5 | Pocket sound | Pocket a piece | Distinct pocketing sound plays |

### Phase 6: Turn Management

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 6.1 | Turn switch | No piece pocketed | Turn switches to Player 2 |
| 6.2 | Extra turn | Pocket own color piece | Same player gets another turn |
| 6.3 | Camera flip | Player 2's turn | Camera rotates 180 degrees to P2's side |
| 6.4 | P2 placement | Player 2 places striker | Striker on opposite baseline |
| 6.5 | P2 aim direction | Player 2 fires | Striker moves toward center from P2's side |

### Phase 7: Foul System

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 7.1 | Striker pocket | Aim striker directly at pocket | "FOUL P1: Striker pocketed!" appears in red |
| 7.2 | Foul message fade | Wait after foul | Red text fades out after ~2 seconds |
| 7.3 | Penalty piece | Foul after pocketing own piece | One of your pocketed pieces returns to center |
| 7.4 | Turn loss | After foul | Turn switches to other player |

### Phase 8: Opponent Piece Rules

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 8.1 | Opponent pocket | Pocket opponent's color piece | Piece returns to board center after turn |
| 8.2 | Score deduction | Check score after opponent piece returned | Points deducted for returned pieces |
| 8.3 | Piece count update | Check HUD | Piece count reflects returned piece |

### Phase 9: Queen Mechanics

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 9.1 | Queen pocketed | Pocket the red queen | "Queen: Needs Cover (P1)" in HUD |
| 9.2 | Queen covered | Pocket own piece after queen | "Queen: Covered" and +50 points kept |
| 9.3 | Queen uncovered | No own piece pocketed after queen | "FOUL: Queen not covered!", queen returns to center |
| 9.4 | Queen return | After uncovered foul | Queen visible at board center, queen label resets |

### Phase 10: Win Condition

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 10.1 | Win detection | Pocket all 9 pieces + covered queen | "Player X Wins!" panel appears |
| 10.2 | Restart button | Click "Play Again" | Board reloads, fresh game |
| 10.3 | Menu button | Click "Main Menu" | Returns to main menu |
| 10.4 | R key restart | Press R during game | Board resets immediately |

### Phase 11: Edge Cases

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 11.1 | Multiple pockets | Pocket several pieces in one shot | All scored correctly, extra turn if own piece included |
| 11.2 | Striker + piece pocket | Both pocketed same turn | Foul takes priority, piece still counted |
| 11.3 | Queen + own piece same shot | Pocket queen and own piece together | Queen covered immediately |
| 11.4 | No movement | Fire with minimal power | Turn still resolves when pieces settle |
| 11.5 | Rapid R presses | Press R multiple times | Game resets cleanly each time |

---

## 6. Architecture Overview

### Pattern: Singleton State Machine + Signal Bus

```
┌──────────────────────────────────────────────────┐
│                 GameManager (Autoload)            │
│  State machine: PLACE → AIM → POWER → SIMULATION │
│  Emits: state_changed, turn_changed, score_updated│
│         piece_pocketed, foul_committed, game_over │
└────────┬───────────┬──────────┬──────────────────┘
         │           │          │
    ┌────▼───┐  ┌────▼───┐  ┌──▼──────────┐
    │ Camera │  │  HUD   │  │  Striker     │
    │Controller│ │        │  │  (Input)     │
    └────────┘  └────────┘  └─────────────┘
                                   │
                            ┌──────▼──────┐
                            │    Board    │
                            │ (Procedural)│
                            └─────────────┘

    ┌─────────────────────────────┐
    │   AudioManager (Autoload)   │
    │   8-channel sound pool      │
    └─────────────────────────────┘
```

**Key design decisions:**
- GameManager and AudioManager are autoload singletons (persist across scene changes)
- All game state lives in GameManager; other scripts read from it
- Communication is signal-based (decoupled)
- Board is procedurally generated (no external mesh assets)
- Striker script is attached at runtime by board.gd

---

## 7. Scripts Reference

### game_manager.gd (Autoload)
- **States**: `PLACE_STRIKER → AIM → POWER → SIMULATION → (loop)`
- **Key vars**: `current_player`, `scores[2]`, `aim_angle`, `power`, `pieces[]`, `striker`, `queen`
- **Signals**: `state_changed`, `turn_changed`, `score_updated`, `piece_pocketed`, `foul_committed`, `game_over`
- **Methods**: `start_game()`, `place_striker_at()`, `confirm_placement()`, `set_aim_angle()`, `confirm_aim()`, `release_power()`, `on_piece_pocketed()`

### audio_manager.gd (Autoload)
- **SFX enum**: `PIECE_COLLISION, STRIKER_WALL, PIECE_WALL, POT, POWER_BAR`
- **Pool**: 8 AudioStreamPlayers + 1 dedicated looping player
- **Volume**: Dynamic scaling from per-SFX defaults based on collision velocity

### board.gd
- Builds entire board procedurally in `_ready()`
- Creates: surface, 4 walls, 4 pockets, center circle, board markings, 19 pieces, striker
- Pocket detection → `GameManager.on_piece_pocketed()`
- Collision sounds → `AudioManager.play_collision_sound()`

### striker.gd
- Handles mouse input per game state
- Raycast point-to-aim system with dotted line indicator and collision preview spheres
- Maps mouse X to world position (placement) or aim direction (aiming)

### camera_controller.gd
- 4 camera presets per player (8 total)
- Smooth tween transitions (0.5s cubic ease)
- Flips 180 degrees for Player 2

### hud.gd
- Updates: state label, turn label, scores, piece counts, queen status, power bar
- Foul display: timed 1.5s + 0.5s fade
- Game over panel: "Play Again" / "Main Menu" buttons

### main_menu.gd
- Button handlers: Play, Settings, Quit

### settings.gd
- Audio toggle: mutes/unmutes Master bus
- Back button: returns to main menu

---

## 8. Scenes Reference

### main_menu.tscn (Launch Scene)
- Dark background + centered VBox
- Buttons: Play, Settings, Quit

### main.tscn (Game Scene)
- Board (Node3D) + Camera3D + WorldEnvironment + 2 DirectionalLights + HUD instance
- Board script creates all gameplay nodes at runtime

### hud.tscn (Canvas Overlay)
- Labels: StateLabel, FoulLabel, TurnLabel, QueenLabel, ScoreP1/P2, PiecesP1/P2
- PowerBar (ProgressBar), PlacementIndicator (ColorRect)
- GameOverPanel with VBox containing label + 2 buttons

### settings.tscn
- Dark background + VBox: Title, AudioToggle (CheckButton), Back button

---

## 9. Physics Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| Gravity | 0.0 | Flat board, no vertical force |
| Scale | 1 unit = 1 cm | Board is 74x74 cm |
| Linear damp | 0.5 | Gentle surface friction (powdered board) |
| Angular damp | 2.0 | Moderate spin resistance |
| Piece mass | 5.0 g | ~5g carrom piece |
| Striker mass | 15.0 g | ~15g (3:1 ratio) |
| Piece bounce | 0.8 | Hard plastic, elastic collisions |
| Piece friction | 0.05 | Powdered board, near-frictionless |
| Wall bounce | 0.7 | Rubber cushion on wood frame |
| Wall friction | 0.1 | Smooth lacquered wood |
| Stop threshold | 0.5 cm/s | Below this = piece "stopped" |
| Max power | 5.0 | Impulse multiplied by 2.0 |

### Physics Layers
| Layer | Name | Used By |
|-------|------|---------|
| 1 (bit 1) | board | Board surface, walls |
| 2 (bit 2) | pieces | All 19 carrommen |
| 3 (bit 4) | striker | Striker piece |
| 4 (bit 8) | pockets | 4 corner Area3D triggers |

---

## 10. Audio System

### Sound Effects
| SFX | File | Default Gain | Trigger |
|-----|------|-------------|---------|
| PIECE_COLLISION | carrom_carrommen_cd.wav | 0.3 | Piece hits piece |
| STRIKER_WALL | carrom_striker_wall.wav | 0.7 | Striker hits wall |
| PIECE_WALL | Carrom_carrommen_wall.wav | 0.4 | Piece hits wall |
| POT | carrom_pot_sound.wav | 0.7 | Any body enters pocket |
| POWER_BAR | carrom_power_bar.wav | 0.7 | Charging (loops) |

### Volume Formula
For collisions: `gain = clamp(default_gain * velocity * 0.5, 0.1, 1.0)`
- Scales from the per-SFX default
- Faster collisions = louder
- Clamped to prevent silence or clipping

---

## 11. Signal Flow

```
GameManager.state_changed ──► CameraController._on_state_changed
                           ──► HUD._on_state_changed
                           ──► Striker._on_state_changed

GameManager.turn_changed  ──► CameraController._on_turn_changed
                           ──► HUD._on_turn_changed

GameManager.score_updated ──► HUD._on_score_updated
GameManager.piece_pocketed──► HUD._on_piece_pocketed
GameManager.foul_committed──► HUD._on_foul
GameManager.game_over     ──► HUD._on_game_over

Board.pocket.body_entered ──► GameManager.on_piece_pocketed
Board.piece.body_entered  ──► Board._on_piece_collision ──► AudioManager
```

---

## 12. Game Rules Implemented

### Turn Flow
1. Player places striker on their baseline
2. Aims direction (-75 to +75 degrees)
3. Charges and releases power (0 to 5.0)
4. Simulation runs until all pieces stop
5. Turn resolves:
   - Striker pocketed? → Foul (return 1 piece, lose turn)
   - Queen pocketed but not covered? → Queen returns, lose turn
   - Queen pocketed and own piece also pocketed? → Queen covered
   - Opponent pieces pocketed? → Returned to center, score deducted
   - Own piece pocketed? → Extra turn
   - No own piece pocketed? → Switch turns
   - All own pieces + covered queen? → Win

### Piece Layout (19 pieces)
- 1 Queen (red) at exact center
- 9 Black pieces (Player 1) in ring pattern
- 9 White pieces (Player 2) in ring pattern
- Arranged using trigonometric spacing (30-degree increments)

---

## 13. Known Limitations

- **No AI opponent** — local 2-player only
- **No touch/gamepad input** — mouse only
- **No network multiplayer**
- **No undo/replay** system
- **No piece animations** for returning to center (instant teleport)
- **Score is cosmetic** — win is by piece count, not score threshold
- **No break rule** — first shot has no special constraints
- **Settings don't persist** — audio toggle resets on restart
- **No visual themes** — procedural geometry only, no textures

---

## 14. Coordinate System

```
        -Z (Player 1 shoots toward here)
         │
         │
 -X ─────┼───── +X
         │
         │
        +Z (Player 2 shoots toward here)

  Y = up (vertical, pieces at Y ≈ 0.2)
```

- Scale: 1 unit = 1 cm (no scale factor)
- Board: 74 x 74 cm on XZ plane
- Player 1 baseline: Z = +29 cm
- Player 2 baseline: Z = -29 cm
- Pockets: 4 corners at (+-33, 0, +-33)
