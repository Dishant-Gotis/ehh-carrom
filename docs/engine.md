# Engine Trace: Striker Release → Collisions → Simulation Stop

> Godot 4.6 remaster — GDScript physics engine architecture (replaces original C++ Hooke's law spring system)

Complete trace of the game engine from the moment the player releases the
mouse button to fire, through physics simulation and collisions, to the
simulation stop and turn resolution. Every function call, signal emission,
and side effect is documented with file references matching the current code.

---

## Timeline Overview

```
 BEFORE RELEASE                    RELEASE MOMENT                AFTER RELEASE
 ──────────────                    ──────────────                ─────────────
 POWER state active                Mouse button UP event         SIMULATION state
 is_charging = true                ├─ stop charging              ├─ Godot physics engine runs
 power increasing each frame       ├─ stop audio                 ├─ Piece-piece collisions
 power bar filling                 ├─ unfreeze striker           ├─ Wall collisions
 aim indicator visible             ├─ compute direction          ├─ Pocket detection (Area3D)
                                   ├─ apply impulse              ├─ Collision sounds fire
                                   ├─ clear turn tracking        ├─ Damping decelerates all
                                   └─ emit state_changed         ├─ Stop polling each frame
                                                                 └─ All stop → _resolve_turn()
```

---

## 1. BEFORE RELEASE — Power Charging

### Entry into POWER state

The player clicked to confirm aim. This triggered:

```
scenes/game/striker.gd:86   → event.pressed (mouse DOWN in AIM state)
scenes/game/striker.gd:87   → GameManager.confirm_aim()
autoload/game_manager.gd:120   power = 0.0
autoload/game_manager.gd:121   is_charging = false          ← NOT charging yet
autoload/game_manager.gd:122   _set_state(State.POWER)
autoload/game_manager.gd:85      current_state = POWER
autoload/game_manager.gd:86      state_changed.emit(POWER)
                           ├─ scenes/game/camera_controller.gd:62  → tween to POWER camera preset
                           ├─ scenes/ui/hud.gd:59                → state_label text updates
                           ├─ scenes/ui/hud.gd:60                → placement_indicator hidden
                           └─ scenes/game/striker.gd:37             → aim_indicator stays visible
```

The mouse button from the aim-confirm click is still held down.
When the player releases it, `_handle_power` sees `not event.pressed` but
`is_charging` is `false`, so nothing fires. This prevents the zero-power bug.

### Player clicks and holds (new click)

```
scenes/game/striker.gd:91   → InputEventMouseButton received
scenes/game/striker.gd:93   → button_index == MOUSE_BUTTON_LEFT ✓
scenes/game/striker.gd:94   → event.pressed = true (mouse DOWN)
scenes/game/striker.gd:96   → GameManager.is_charging = true       ← charging begins
scenes/game/striker.gd:97   → AudioManager.play_power_bar()
autoload/audio_manager.gd:78   → _power_bar_player.play()      ← looping charge sound starts
```

### Every frame while held (charging loop)

Two `_process()` calls run each frame:

```
autoload/game_manager.gd:63   _process(delta)
autoload/game_manager.gd:67     match current_state → State.POWER
autoload/game_manager.gd:69       is_charging == true
autoload/game_manager.gd:70       power = minf(power + POWER_CHARGE_SPEED * delta, MAX_POWER)
                          ← power += 3.0 * delta each frame, capped at 5.0
                          ← at 60fps: delta ≈ 0.0167, so +0.05/frame
                          ← 0 → 5.0 takes ~1.67 seconds

scenes/ui/hud.gd:50        _process(delta)
scenes/ui/hud.gd:51          current_state == POWER → true
scenes/ui/hud.gd:52          power_bar.value = (power / 5.0) * 100.0    ← bar fills 0→100%
scenes/ui/hud.gd:53          power_bar.visible = true
```

### State snapshot during charging

| Variable | Value | Location |
|----------|-------|----------|
| `current_state` | `POWER` | autoload/game_manager.gd:33 |
| `current_player` | `1` or `2` | autoload/game_manager.gd:34 |
| `is_charging` | `true` | autoload/game_manager.gd:38 |
| `power` | `0.0 → 5.0` (increasing) | autoload/game_manager.gd:37 |
| `aim_angle` | `-75.0 to +75.0` (locked) | autoload/game_manager.gd:36 |
| `striker.freeze` | `true` | set in place_striker_at:100 |
| `striker.linear_velocity` | `(0, 0, 0)` | frozen body can't move |
| `striker.global_position` | P1: `(x, 0.02, +2.9)`, P2: `(x, 0.02, -2.9)` | autoload/game_manager.gd:97 |
| `aim_indicator.visible` | `true` | scenes/game/striker.gd:38 |
| `power_bar.visible` | `true` | scenes/ui/hud.gd:53 |
| Audio | `power_bar.wav` looping | autoload/audio_manager.gd:79 |

---

## 2. RELEASE MOMENT — The Trigger

Player releases left mouse button. Godot delivers `InputEventMouseButton`
with `pressed = false` through `_unhandled_input`.

### Step 1: Input captured by striker

```
scenes/game/striker.gd:43   _unhandled_input(event)
scenes/game/striker.gd:44     GameManager.game_active == true → continue
scenes/game/striker.gd:47     match GameManager.current_state → State.POWER
scenes/game/striker.gd:53       → _handle_power(event)
scenes/game/striker.gd:91         event is InputEventMouseButton ✓
scenes/game/striker.gd:93         event.button_index == MOUSE_BUTTON_LEFT ✓
scenes/game/striker.gd:98         event.pressed == false (mouse UP)
scenes/game/striker.gd:100          GameManager.is_charging == true ✓
scenes/game/striker.gd:101          → GameManager.release_power()
```

### Step 2: Stop charging, stop audio

```
autoload/game_manager.gd:128  release_power()
autoload/game_manager.gd:129    current_state == POWER ✓ (guard passes)
autoload/game_manager.gd:131    is_charging = false                ← charging stops
autoload/game_manager.gd:132    AudioManager.stop_power_bar()
autoload/audio_manager.gd:84      _power_bar_player.stop()         ← sound stops instantly
autoload/game_manager.gd:133    → _shoot_striker()                  ← fire!
```

### Step 3: Unfreeze striker and compute impulse

```
autoload/game_manager.gd:136  _shoot_striker()
autoload/game_manager.gd:137    striker == null? → no, continue
autoload/game_manager.gd:139    striker.freeze = false               ← physics enabled on striker
```

**Direction computation:**

```
autoload/game_manager.gd:141    angle_rad = deg_to_rad(aim_angle)

autoload/game_manager.gd:142    direction = Vector3(sin(angle_rad), 0.0, -cos(angle_rad))
                        ← P1: negative Z component = shoots toward -Z (toward center)

autoload/game_manager.gd:143    if current_player == 2:
autoload/game_manager.gd:144      direction.z = -direction.z         ← P2: flip to shoot toward +Z
```

**Direction by player (angle = 0° straight shot):**

```
Player 1 (at Z = +2.9):  direction = (0, 0, -1)    → shoots toward -Z (center) ✓
Player 2 (at Z = -2.9):  direction = (0, 0, +1)    → shoots toward +Z (center) ✓
```

**Direction with angle (Player 1 examples):**

```
Angle =   0°:  direction = ( 0.00, 0, -1.00)  → straight ahead
Angle = +30°:  direction = (+0.50, 0, -0.87)  → angled right
Angle = -30°:  direction = (-0.50, 0, -0.87)  → angled left
Angle = +75°:  direction = (+0.97, 0, -0.26)  → hard right
Angle = -75°:  direction = (-0.97, 0, -0.26)  → hard left
```

**Impulse application:**

```
autoload/game_manager.gd:145    impulse = direction * power * 2.0    ← scale factor for feel

                        Example: power = 3.5, angle = 0° (P1)
                          impulse = (0, 0, -1) * 3.5 * 2.0
                                  = (0, 0, -7.0)

autoload/game_manager.gd:146    striker.apply_central_impulse(impulse)
                        ← Godot physics: impulse is instantaneous force
                           velocity += impulse / mass
                           mass = 18.0 (STRIKER_MASS from scenes/game/board.gd:14)
                           initial velocity = (0, 0, -7.0) / 18.0
                                            = (0, 0, -0.389) m/s
```

**Impulse → initial velocity table (straight shot):**

| Power | Impulse Magnitude | ÷ Mass (18) | Initial Speed |
|-------|------------------|-------------|---------------|
| 0.5 | 1.0 | 0.056 | Very slow |
| 2.0 | 4.0 | 0.222 | Moderate |
| 3.5 | 7.0 | 0.389 | Strong |
| 5.0 | 10.0 | 0.556 | Maximum |

### Step 4: Reset turn-tracking flags

```
autoload/game_manager.gd:148    pocketed_this_turn.clear()         ← empty the array
autoload/game_manager.gd:149    striker_pocketed = false            ← no foul yet
autoload/game_manager.gd:150    own_piece_pocketed = false          ← no extra turn yet
```

### Step 5: Transition to SIMULATION

```
autoload/game_manager.gd:151    _set_state(State.SIMULATION)
autoload/game_manager.gd:85       current_state = SIMULATION
autoload/game_manager.gd:86       state_changed.emit(SIMULATION)
```

**All signal receivers fire synchronously:**

```
scenes/game/camera_controller.gd:62   _on_state_changed(SIMULATION)
scenes/game/camera_controller.gd:63     _transition_to(SIMULATION, current_player)
                             ← P1: tween to pos(0, 7.0, 2.0), rot(-70°, 0°, 0°)
                             ← P2: tween to pos(0, 7.0, -2.0), rot(-70°, 180°, 0°)
                             ← 0.5s cubic ease-in-out transition

scenes/ui/hud.gd:59                _on_state_changed(SIMULATION)
scenes/ui/hud.gd:60                  state_label.text = "Simulating..."
scenes/ui/hud.gd:61                  placement_indicator.visible = false
scenes/ui/hud.gd:62                  _update_queen_status()    ← refresh queen label

scenes/game/striker.gd:33             _on_state_changed(SIMULATION)
scenes/game/striker.gd:40               _aim_indicator.visible = false   ← cone disappears
```

**On next frame:**

```
scenes/ui/hud.gd:50                _process(delta)
scenes/ui/hud.gd:51                  current_state == POWER? → false (now SIMULATION)
scenes/ui/hud.gd:54                  power_bar.visible = false         ← bar hides
scenes/ui/hud.gd:55                  power_bar.value = 0
```

---

## 3. AFTER RELEASE — Simulation Phase

### 3a. Godot Physics Engine (runs automatically)

Godot's built-in physics engine processes all RigidBody3D objects each
physics frame (~60Hz by default). Our code does NOT manually compute
collisions — Godot handles it all.

**Per physics frame, for each RigidBody3D (striker + 19 pieces):**

```
Step 1: Force accumulation
         ← gravity_scale = 0.0, so no gravity force
         ← no other forces applied (no wind, no magnets)
         ← net force = 0 for all bodies

Step 2: Velocity integration
         ← position += velocity * delta
         ← pieces slide across the XZ plane

Step 3: Collision detection (narrow phase)
         ← CylinderShape3D vs CylinderShape3D (piece↔piece)
         ← CylinderShape3D vs BoxShape3D (piece↔wall)
         ← CylinderShape3D vs SphereShape3D (piece↔pocket trigger)
         ← collision_layer/mask filtering determines which pairs check:
             pieces  (layer 2, mask 3) ↔ pieces (layer 2)  ✓ (2 & 3 = 2)
             pieces  (layer 2, mask 3) ↔ board  (layer 1)  ✓ (1 & 3 = 1)
             striker (layer 4, mask 3) ↔ pieces (layer 2)  ✓ (2 & 3 = 2)
             striker (layer 4, mask 3) ↔ board  (layer 1)  ✓ (1 & 3 = 1)
             striker (layer 4, mask 3) ↔ striker(layer 4)  ✗ (4 & 3 = 0)
             pockets (layer 8, mask 6) detects pieces(2)   ✓ (2 & 6 = 2)
             pockets (layer 8, mask 6) detects striker(4)  ✓ (4 & 6 = 4)

Step 4: Collision resolution
         ← PhysicsMaterial determines bounce behavior:
             pieces: bounce = 0.5, friction = 0.4
             walls:  bounce = 0.6, friction = 0.3
         ← velocities exchanged based on mass ratio:
             piece mass  = 12.0 kg
             striker mass = 18.0 kg (1.5x heavier)
         ← striker transfers more momentum to pieces than vice versa

Step 5: Damping (velocity reduction per frame)
         ← linear_velocity *= (1.0 - linear_damp * delta)
         ← pieces:  linear_damp = 3.0 (overrides global 2.0)
         ← striker: linear_damp = 3.0 (same as pieces)
         ← at 60fps: velocity *= (1.0 - 3.0 * 0.0167) ≈ velocity *= 0.95
         ← ~5% speed reduction per frame → exponential decay
         ← angular_damp = 8.0 (stops rotation quickly)

Step 6: Axis locks enforced
         ← axis_lock_linear_y = true   → no vertical movement
         ← axis_lock_angular_x = true  → no pitch
         ← axis_lock_angular_z = true  → no roll
         ← pieces stay flat on the XZ board plane
```

**Deceleration timeline (straight shot, power = 5.0, speed = 0.556):**

```
Frame 0:   speed = 0.556   ← just fired
Frame 10:  speed ≈ 0.336   ← 60% remaining (0.95^10)
Frame 30:  speed ≈ 0.122   ← 22% remaining
Frame 60:  speed ≈ 0.027   ← 5% remaining (1 second elapsed)
Frame 90:  speed ≈ 0.006   ← barely moving
Frame ~95: speed < 0.005   ← STOP_THRESHOLD reached
                              ← ~1.6 seconds total for striker alone
```

Note: collisions transfer energy to other pieces, extending total
simulation time. A shot that scatters many pieces may take 3-5 seconds.

---

### 3b. Collision Sound System

When two RigidBody3D objects collide, Godot fires the `body_entered` signal.
Each piece has this connected at creation time:

**Signal wiring (during board setup):**

```
scenes/game/board.gd:356    body.contact_monitor = true       ← enable collision signals
scenes/game/board.gd:357    body.max_contacts_reported = 4    ← track up to 4 contacts
scenes/game/board.gd:358    body.body_entered.connect(_on_piece_collision.bind(body))
                ← .bind(body) passes the owner piece as second argument
                ← Godot's body_entered passes the OTHER body as first argument
                ← callback signature: _on_piece_collision(other, piece)
```

**When a collision occurs:**

```
scenes/game/board.gd:363  _on_piece_collision(other: Node, piece: RigidBody3D)
scenes/game/board.gd:364    vel = piece.linear_velocity.length()
scenes/game/board.gd:365    vel < 0.05? → return (skip inaudible collisions)
```

**Branch: Wall collision (other is StaticBody3D)**

```
scenes/game/board.gd:368    other is StaticBody3D? → YES (wall or board surface)
scenes/game/board.gd:370      piece == GameManager.striker?
scenes/game/board.gd:371        YES → AudioManager.play_collision_sound(STRIKER_WALL, vel)
                           ← distinct heavy thud for striker hitting wall
scenes/game/board.gd:373        NO  → AudioManager.play_collision_sound(PIECE_WALL, vel)
                           ← lighter bounce sound for piece hitting wall
```

**Branch: Piece-piece collision (other is RigidBody3D)**

```
scenes/game/board.gd:374    other is RigidBody3D? → YES
scenes/game/board.gd:376      piece.get_instance_id() < other.get_instance_id()?
                  ← BOTH pieces fire body_entered for the same collision
                  ← this comparison ensures only ONE of them plays sound
                  ← the piece with the lower instance ID wins
scenes/game/board.gd:377        → AudioManager.play_collision_sound(PIECE_COLLISION, vel)
```

**Volume computation in AudioManager:**

```
autoload/audio_manager.gd:69   play_collision_sound(sfx, velocity)
autoload/audio_manager.gd:71     gain = DEFAULT_GAINS[sfx]
                         ← PIECE_COLLISION: 0.3
                         ← STRIKER_WALL:    0.7
                         ← PIECE_WALL:      0.4

autoload/audio_manager.gd:72     velocity > 0.01? (almost always true)
autoload/audio_manager.gd:73       gain = clampf(gain * velocity * 0.5, 0.1, 1.0)
                          ← scales the default gain by velocity
                          ← faster collision = louder sound
                          ← clamped to [0.1, 1.0] range

                          Examples (PIECE_COLLISION, default 0.3):
                            vel=0.1:  0.3 * 0.1 * 0.5 = 0.015 → clamped to 0.1
                            vel=1.0:  0.3 * 1.0 * 0.5 = 0.15
                            vel=3.0:  0.3 * 3.0 * 0.5 = 0.45
                            vel=5.0:  0.3 * 5.0 * 0.5 = 0.75

                          Examples (STRIKER_WALL, default 0.7):
                            vel=0.1:  0.7 * 0.1 * 0.5 = 0.035 → clamped to 0.1
                            vel=1.0:  0.7 * 1.0 * 0.5 = 0.35
                            vel=3.0:  0.7 * 3.0 * 0.5 = 1.05  → clamped to 1.0

autoload/audio_manager.gd:74     play_sound(sfx, gain)
```

**Sound playback from pool:**

```
autoload/audio_manager.gd:52   play_sound(sfx, volume)
autoload/audio_manager.gd:53     _streams.has(sfx)? ✓
autoload/audio_manager.gd:55     gain = volume (explicit override from play_collision_sound)
autoload/audio_manager.gd:57     for player in _players[0..7]:    ← pool of 8
autoload/audio_manager.gd:58       if not player.playing:          ← find idle player
autoload/audio_manager.gd:59         player.stream = _streams[sfx]
autoload/audio_manager.gd:60         player.volume_db = linear_to_db(gain)
autoload/audio_manager.gd:61         player.play()                 ← sound fires
autoload/audio_manager.gd:62         return
autoload/audio_manager.gd:64     _players[0].stream = ...          ← all 8 busy? interrupt first
autoload/audio_manager.gd:65     _players[0].volume_db = ...
autoload/audio_manager.gd:66     _players[0].play()                ← oldest sound cut off
```

**Concurrent sound limit:**

```
Maximum 8 simultaneous collision sounds + 1 dedicated power bar player.
In a hard scatter shot, 5-10 collisions may fire within 100ms.
Pool handles this with FIFO interruption — oldest sound gets replaced.
```

---

### 3c. Pocket Detection

Pockets are 4 Area3D nodes at board corners. They detect bodies entering
via a SphereShape3D trigger (radius 0.28 units).

**Pocket positions:**

```
scenes/game/board.gd:114    half = 3.7 (BOARD_SIZE/2 * S)
scenes/game/board.gd:115    offset = half * 0.95 = 3.515
scenes/game/board.gd:116-120  corners:
                    Pocket_0: (-3.515, 0, -3.515)  ← top-left
                    Pocket_1: (+3.515, 0, -3.515)  ← top-right
                    Pocket_2: (-3.515, 0, +3.515)  ← bottom-left
                    Pocket_3: (+3.515, 0, +3.515)  ← bottom-right

scenes/game/board.gd:145    area.collision_layer = 8   ← pocket layer (bit 3)
scenes/game/board.gd:146    area.collision_mask  = 6   ← detects pieces (bit 1) + striker (bit 2)
                ← mask=6 in binary = 0b110 = layers 2 and 3
                ← pieces on layer 2 (value 2): 2 & 6 = 2 ✓
                ← striker on layer 3 (value 4): 4 & 6 = 4 ✓
```

**When a body enters a pocket sphere:**

```
scenes/game/board.gd:147    area.body_entered.connect(_on_pocket_body_entered)
                ← Godot fires this when a RigidBody3D overlaps the SphereShape3D

scenes/game/board.gd:152  _on_pocket_body_entered(body: Node3D)
scenes/game/board.gd:153    body is RigidBody3D? ✓
scenes/game/board.gd:154    → GameManager.on_piece_pocketed(body)
```

**Pocket handler — striker case:**

```
autoload/game_manager.gd:298  on_piece_pocketed(body)
autoload/game_manager.gd:299    game_active == true ✓
autoload/game_manager.gd:302    AudioManager.play_sound(POT, 0.7)     ← pocket sound plays

autoload/game_manager.gd:304    body == striker?  → YES
autoload/game_manager.gd:305      striker_pocketed = true              ← foul flag
autoload/game_manager.gd:306      body.linear_velocity = Vector3.ZERO ← stop movement
autoload/game_manager.gd:307      body.angular_velocity = Vector3.ZERO
autoload/game_manager.gd:308      body.freeze = true                  ← disable physics
autoload/game_manager.gd:309      body.visible = false                ← hide from view
autoload/game_manager.gd:310      body.global_position = (0, -10, 0) ← teleport off-board
autoload/game_manager.gd:311      return
                          ← striker is gone, foul will be processed in _resolve_turn
```

**Pocket handler — piece case:**

```
autoload/game_manager.gd:313    body.visible = false                   ← piece disappears
autoload/game_manager.gd:314    body.freeze = true                     ← stop its physics
autoload/game_manager.gd:315    body.global_position = (0, -10, 0)    ← move underground
autoload/game_manager.gd:316    pocketed_this_turn.append(body)        ← remember for resolution

autoload/game_manager.gd:318    piece_color = body.get_meta("color")   ← BLACK(0), WHITE(1), RED(2)

autoload/game_manager.gd:321    Scoring by color:
                          BLACK → points = 10  (SCORE_BLACK)
                          WHITE → points = 20  (SCORE_WHITE)
                          RED   → points = 50  (SCORE_QUEEN)

autoload/game_manager.gd:330    scores[current_player - 1] += points   ← add to player's score
autoload/game_manager.gd:331    score_updated.emit(current_player, scores[...])
                        └─ scenes/ui/hud.gd:66 _on_score_updated → _update_scores()
                           ← score labels refresh

autoload/game_manager.gd:332    piece_pocketed.emit(body, current_player)
                        └─ scenes/ui/hud.gd:68 _on_piece_pocketed
                           ├─ _update_piece_counts()   ← "P1 left: 8"
                           └─ _update_queen_status()   ← "Queen: Needs Cover"

autoload/game_manager.gd:334    Own piece tracking:
autoload/game_manager.gd:335      P1 pocketed BLACK? → own_piece_pocketed = true
autoload/game_manager.gd:336      P2 pocketed WHITE? → own_piece_pocketed = true
                          ← earns extra turn in _resolve_turn

autoload/game_manager.gd:340    Queen tracking:
autoload/game_manager.gd:341      piece_color == RED?
                            queen_pocketed_by = current_player
                            queen_covered = false
                          ← queen must be "covered" next shot or returns to center
```

---

### 3d. Stop Detection — Polling Every Frame

During SIMULATION, `_process()` runs `_check_simulation_complete()` every frame.

```
autoload/game_manager.gd:63   _process(delta)
autoload/game_manager.gd:64     game_active == false? → return (skip if game over)
autoload/game_manager.gd:67     match current_state:
autoload/game_manager.gd:71       State.SIMULATION → _check_simulation_complete()
```

**The stop check:**

```
autoload/game_manager.gd:156  _check_simulation_complete()
autoload/game_manager.gd:157    striker == null? → return (safety guard)

autoload/game_manager.gd:160    for piece in pieces[]:               ← all 19 pieces
autoload/game_manager.gd:161      if piece.visible:                  ← skip pocketed (invisible)
                           if piece.linear_velocity.length() > STOP_THRESHOLD:
autoload/game_manager.gd:162          return                         ← at least one still moving
                                                               check again next frame

autoload/game_manager.gd:163    if striker.linear_velocity.length() > STOP_THRESHOLD:
autoload/game_manager.gd:164      return                             ← striker still moving

autoload/game_manager.gd:166    → _resolve_turn()                    ← ALL bodies below 0.005 m/s
```

**STOP_THRESHOLD = 0.005 m/s**

```
← at 0.005 m/s, a piece moves 0.005 * 0.0167 = 0.00008 units per frame
← that's 0.08mm in original scale — imperceptible
← below this, Godot damping will bring it to zero within a few more frames
← but we don't wait — the game considers it "stopped"
```

**Pocketed pieces are skipped:**

```
← piece.visible = false after pocketing (autoload/game_manager.gd:313)
← the check on line 161 requires piece.visible
← pocketed pieces don't block simulation end
```

**Pocketed striker is also handled:**

```
← striker is hidden + frozen after pocketing (autoload/game_manager.gd:308-310)
← striker.linear_velocity is zeroed (autoload/game_manager.gd:306)
← so line 163 check passes immediately (0 < 0.005 is false → doesn't return)
← simulation can still end while striker is "in pocket"
```

**can_sleep = false on all bodies (scenes/game/board.gd:312):**

```
← Godot's sleep optimization would stop tracking velocity on slow bodies
← we disable it because _check_simulation_complete needs accurate velocity reads
← trade-off: slightly more CPU, but correct stop detection
```

---

### 3e. Turn Resolution — Decision Tree

Once all pieces stop, `_resolve_turn()` runs exactly once (because it
immediately changes state away from SIMULATION, preventing re-entry).

```
autoload/game_manager.gd:169  _resolve_turn()
autoload/game_manager.gd:170    _return_count = 0    ← reset ring placement counter
```

**Check 1: Striker Foul**

```
autoload/game_manager.gd:172    striker_pocketed?
                        │
                        ├─ YES:
                        │   :173  foul_committed.emit(current_player, "Striker pocketed!")
                        │           └─ scenes/ui/hud.gd:76  FoulLabel appears in red
                        │                          tween: 1.5s visible → 0.5s fade → hide
                        │
                        │   :174  _handle_foul()
                        │           :205  next_player = opposite of current
                        │           :206  placement_z = baseline for next player
                        │           :207  striker.global_position = (0, 0.02, placement_z)
                        │           :208  striker.linear_velocity = ZERO
                        │           :209  striker.angular_velocity = ZERO
                        │           :210  striker.freeze = true
                        │           :211  striker.visible = true    ← re-appear on board
                        │           :212  striker_pocketed = false
                        │
                        │           :215  player_color = BLACK if P1, WHITE if P2
                        │           :216  for piece in pieces[]:
                        │           :217    if piece.color == player_color AND not visible:
                        │           :219      _return_piece_to_center(piece)
                        │                       :229  angle = ring offset + jitter
                        │                       :230  dist = 0.2 + count * 0.15
                        │                       :232  piece → center + offset
                        │                       :235  piece.visible = true
                        │                       :236  piece.freeze = false
                        │           :220      break  ← only return ONE piece
                        │
                        │           :222  _switch_turn()
                        │                   :252  current_player flips 1↔2
                        │                   :253  turn_changed.emit()
                        │                   :254  _set_state(PLACE_STRIKER)
                        │
                        │   :175  return    ← done, skip all other checks
                        │
                        └─ NO: continue to check 2
```

**Check 2: Queen Cover**

```
autoload/game_manager.gd:178    queen_pocketed_by == current_player AND NOT queen_covered?
                        │
                        ├─ YES:
                        │   :179  own_piece_pocketed?
                        │          │
                        │          ├─ YES:
                        │          │   :180  queen_covered = true     ← queen is safe!
                        │          │         ← player continues (falls through to check 3+)
                        │          │
                        │          └─ NO:
                        │              :182  foul_committed.emit("Queen not covered!")
                        │              :183  _return_queen_to_center()
                        │                      :258  queen → (0, 0.02, 0)
                        │                      :260  velocity zeroed
                        │                      :262  queen.visible = true
                        │                      :263  queen.freeze = false
                        │              :184  queen_pocketed_by = -1   ← reset tracking
                        │              :185  _switch_turn()
                        │              :186  return                   ← done
                        │
                        └─ NO (or condition false): continue to check 3
```

**Check 3: Return Opponent Pieces**

```
autoload/game_manager.gd:190    _return_opponent_pieces()
                        :241  opponent_color = WHITE if P1 else BLACK
                        :242  for piece in pocketed_this_turn[]:
                        :243    piece.color == opponent_color?
                        :244      YES:
                                    :245  _return_piece_to_center(piece)
                                           ← piece back on board at center
                                    :246  points = SCORE_WHITE or SCORE_BLACK
                                    :247  scores[player] -= points
                                           ← undo the points that were added
                                    :248  score_updated.emit()
                                           ← HUD refreshes score display
```

**Check 4: Win Condition**

```
autoload/game_manager.gd:193    _check_win()
                        :268  black_remaining = 0
                        :269  white_remaining = 0
                        :270  for piece in pieces[]:
                        :271    skip invisible (pocketed)
                        :273    skip queen
                        :275    count BLACK visible
                        :277    count WHITE visible

                        :282  P1 wins if:
                                black_remaining == 0
                                AND queen_covered == true
                                AND queen_pocketed_by == 1
                              → _end_game(1)
                                :292  game_active = false
                                :293  game_over.emit(1)
                                        └─ scenes/ui/hud.gd:85  GameOverPanel visible
                                                       "Player 1 Wins!"
                                                       RestartButton + MenuButton
                              → return 1   (truthy → _resolve_turn returns)

                        :285  P2 wins if:
                                white_remaining == 0
                                AND queen_covered == true
                                AND queen_pocketed_by == 2
                              → _end_game(2), return 2

                        :288  return 0     (falsy → continue to check 5)
```

**Check 5: Extra Turn or Switch**

```
autoload/game_manager.gd:197    own_piece_pocketed?
                        │
                        ├─ YES:
                        │   :198  _set_state(State.PLACE_STRIKER)
                        │         ← SAME player gets another turn
                        │         ← camera stays on same side
                        │         ← HUD: "Place Striker (click)"
                        │
                        └─ NO:
                            :200  _switch_turn()
                                    :252  current_player = 2 if 1 else 1
                                    :253  turn_changed.emit(current_player)
                                           └─ scenes/ui/hud.gd:63 → _update_turn()
                                                           "Player 2 (White)"
                                    :254  _set_state(State.PLACE_STRIKER)
                                           └─ state_changed.emit()
                                               ├─ camera tweens to other side
                                               ├─ hud: "Place Striker (click)"
                                               └─ aim indicator hidden
```

---

## State Snapshot: Before vs After

| Property | Before Release | After Release (settled) |
|----------|---------------|------------------------|
| `current_state` | `POWER` | `PLACE_STRIKER` |
| `is_charging` | `true` | `false` |
| `power` | `0.0–5.0` | `0.0` (next turn) |
| `striker.freeze` | `true` (placement) | `true` (re-frozen for next placement) |
| `striker.visible` | `true` | `true` (or restored after foul) |
| `striker.linear_velocity` | `(0,0,0)` | `(0,0,0)` (stopped) |
| `striker.global_position` | P1:`(x, 0.02, +2.9)` | next player's baseline |
| `current_player` | `N` | `N` (extra turn) or `opposite` (switched) |
| `pocketed_this_turn` | `(previous turn)` | `[]` (cleared on fire) |
| `striker_pocketed` | `false` | `false` |
| `own_piece_pocketed` | `false` | `true` if own color pocketed |
| Power bar | visible, filling | hidden |
| Aim indicator | visible | hidden |
| Camera | POWER preset | PLACE_STRIKER preset (possibly other side) |
| Audio | `power_bar.wav` looping | silent |
| Scores | unchanged | updated if pieces pocketed |
| Piece counts | unchanged | decremented per pocket |

---

## Data Flow Diagram

```
                    Mouse UP (left button release)
                       │
                       ▼
               ┌──────────────┐
               │  striker.gd  │
               │ _handle_power│
               │   :91-101    │
               └──────┬───────┘
                      │ GameManager.release_power()
                      ▼
          ┌───────────────────────┐
          │    game_manager.gd    │
          │    release_power()    │
          │       :128-133        │
          │  ┌─────────────────┐  │
          │  │ is_charging=false│  │
          │  └────────┬────────┘  │
          │           │           │
          │           ▼           │
          │  ┌─────────────────┐  │         ┌─────────────────┐
          │  │ AudioManager    │──┼────────►│ audio_manager.gd│
          │  │ .stop_power_bar │  │         │ :83-85          │
          │  └────────┬────────┘  │         │ _power_bar_player│
          │           │           │         │    .stop()       │
          │           ▼           │         └─────────────────┘
          │  ┌─────────────────┐  │
          │  │ _shoot_striker()│  │
          │  │    :136-151     │  │
          │  │                 │  │
          │  │ freeze = false  │  │
          │  │ direction =     │  │
          │  │   (sin, 0, -cos)│  │
          │  │ impulse =       │  │
          │  │   dir*power*2.0 │  │
          │  │ apply_impulse() │──┼──────► Godot Physics Engine
          │  │                 │  │             │
          │  │ clear flags     │  │             │ (runs each physics frame)
          │  │ _set_state(SIM) │  │             │
          │  └────────┬────────┘  │             ▼
          └───────────┼───────────┘    ┌─────────────────────┐
                      │                │  Per-frame physics   │
         state_changed.emit()          │                     │
                      │                │  velocity integrate  │
          ┌───────────┼──────┐         │  collision detect    │
          │           │      │         │  collision resolve   │
          ▼           ▼      ▼         │  damping apply       │
  ┌──────────┐ ┌─────┐ ┌────────┐     └──────┬──────────────┘
  │ camera   │ │ hud │ │striker │            │
  │controller│ │ .gd │ │  .gd   │            │ body_entered signals
  │ tween to │ │"Sim"│ │ hide   │            │
  │ SIM view │ │     │ │ cone   │     ┌──────▼──────────────┐
  └──────────┘ └─────┘ └────────┘     │     board.gd        │
                                      │  _on_piece_collision │
                                      │     :363-377         │
                                      │                      │
                                      │  wall hit? ──► STRIKER_WALL or
                                      │                PIECE_WALL sound
                                      │  piece hit? ─► PIECE_COLLISION
                                      │                sound (one side only)
                                      │                      │
                                      │  _on_pocket_body_    │
                                      │    entered :152-154   │
                                      └──────┬───────────────┘
                                             │
                                             │ GameManager.on_piece_pocketed()
                                             ▼
                                      ┌──────────────────────┐
                                      │  game_manager.gd     │
                                      │  on_piece_pocketed   │
                                      │     :298-342         │
                                      │                      │
                                      │  striker? → foul flag│
                                      │    hide + freeze +   │
                                      │    teleport off-board│
                                      │                      │
                                      │  piece? → hide +     │
                                      │    freeze + score +  │
                                      │    track pocketed    │
                                      └──────┬───────────────┘
                                             │
                                             │ score_updated.emit()
                                             │ piece_pocketed.emit()
                                             ▼
                                      ┌──────────────────────┐
                                      │      hud.gd          │
                                      │  update scores       │
                                      │  update piece counts │
                                      │  update queen status │
                                      └──────────────────────┘

          ... frames pass, all velocities decay below 0.005 ...

          ┌───────────────────────────────────┐
          │  game_manager.gd  _process()      │
          │  :63-72                            │
          │  match SIMULATION →                │
          │    _check_simulation_complete()    │
          │    :156-166                        │
          │                                    │
          │  for each visible piece:           │
          │    velocity > 0.005? → return      │
          │  striker velocity > 0.005? → return│
          │  all stopped → _resolve_turn()     │
          └──────────────┬────────────────────┘
                         │
                         ▼
          ┌──────────────────────────────────┐
          │   _resolve_turn()  :169-200      │
          │                                  │
          │   1. striker foul? ─► penalty    │
          │      return one piece, switch    │
          │                                  │
          │   2. queen uncovered? ─► return  │
          │      queen to center, switch     │
          │                                  │
          │   3. opponent pieces? ─► return  │
          │      to board, undo score        │
          │                                  │
          │   4. win condition? ─► game over │
          │      show panel, stop game       │
          │                                  │
          │   5. own piece pocketed?         │
          │      YES → extra turn (same)     │
          │      NO  → switch turn (other)   │
          └──────────────┬───────────────────┘
                         │
                         ▼
                 PLACE_STRIKER
                (next turn begins)
```
