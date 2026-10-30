extends CanvasLayer

## HUD overlay: power bar, scores, turn indicator, game state, game over screen.

@onready var power_bar: ProgressBar = $PowerBar
@onready var state_label: Label = $StatePill/StateLabel
@onready var foul_label: Label = $FoulLabel
@onready var turn_label: Label = $CenterBadge/VBox/TurnLabel
@onready var queen_label: Label = $CenterBadge/VBox/QueenLabel
@onready var score_label_p1: Label = $CardP1/VBox/HBox/ScoreP1
@onready var score_label_p2: Label = $CardP2/VBox/HBox/ScoreP2
@onready var pieces_p1: Label = $CardP1/VBox/PiecesP1
@onready var pieces_p2: Label = $CardP2/VBox/PiecesP2
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBox/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/VBox/RestartButton
@onready var menu_button: Button = $GameOverPanel/VBox/MenuButton
@onready var placement_indicator: ColorRect = $PlacementIndicator

const STATE_NAMES := {
	GameManager.State.PLACE_STRIKER: "🎯 Place Striker — Click anywhere along baseline",
	GameManager.State.AIM: "🏹 Aim — Move mouse to aim, Left-Click to lock",
	GameManager.State.POWER: "⚡ Power — Hold click to charge, Release to strike!",
	GameManager.State.SIMULATION: "⏳ Simulating shot...",
}

var _foul_tween: Tween = null


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.piece_pocketed.connect(_on_piece_pocketed)
	GameManager.foul_committed.connect(_on_foul)
	GameManager.game_over.connect(_on_game_over)

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	game_over_panel.visible = false
	foul_label.visible = false
	_update_turn()
	_update_scores()
	_update_piece_counts()
	_update_queen_status()
	_on_state_changed(GameManager.current_state)


func _process(_delta: float) -> void:
	if GameManager.current_state == GameManager.State.POWER:
		power_bar.value = GameManager.power / GameManager.MAX_POWER * 100.0
		power_bar.visible = true
	else:
		power_bar.visible = false
		power_bar.value = 0


func _on_state_changed(new_state: int) -> void:
	state_label.text = String(STATE_NAMES.get(new_state, ""))
	placement_indicator.visible = (new_state == GameManager.State.PLACE_STRIKER)
	_update_queen_status()


func _on_turn_changed(_player: int) -> void:
	_update_turn()


func _on_score_updated(_player: int, _score: int) -> void:
	_update_scores()


func _on_piece_pocketed(_piece: RigidBody3D, _player: int) -> void:
	_update_piece_counts()
	_update_queen_status()


func _on_foul(player: int, reason: String) -> void:
	foul_label.modulate = Color.WHITE
	foul_label.text = "⚠️ FOUL P%d: %s" % [player, reason]
	foul_label.visible = true
	if _foul_tween:
		_foul_tween.kill()
	_foul_tween = create_tween()
	_foul_tween.tween_interval(1.8)
	_foul_tween.tween_property(foul_label, "modulate:a", 0.0, 0.4)
	_foul_tween.tween_callback(func(): foul_label.visible = false)


func _on_game_over(winner: int) -> void:
	game_over_panel.visible = true
	game_over_label.text = "🏆 Player %d Wins!" % winner


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _update_turn() -> void:
	var p := GameManager.current_player
	if p == 1:
		turn_label.text = "⚫ PLAYER 1'S TURN (BLACK)"
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	else:
		turn_label.text = "⚪ PLAYER 2'S TURN (WHITE)"
		turn_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))


func _update_scores() -> void:
	score_label_p1.text = "%d pts" % GameManager.scores[0]
	score_label_p2.text = "%d pts" % GameManager.scores[1]


func _update_piece_counts() -> void:
	var b := 0
	var w := 0
	for piece in GameManager.pieces:
		if piece == GameManager.queen:
			continue
		if not piece.visible:
			continue
		var pc: int = piece.get_meta("color", GameManager.PieceColor.BLACK) as int
		if pc == GameManager.PieceColor.BLACK:
			b += 1
		elif pc == GameManager.PieceColor.WHITE:
			w += 1
	pieces_p1.text = "%d pieces remaining" % b
	pieces_p2.text = "%d pieces remaining" % w


func _update_queen_status() -> void:
	if GameManager.queen_covered:
		queen_label.text = "👑 Queen Covered"
		queen_label.modulate = Color(0.3, 0.95, 0.45)
	elif GameManager.queen_pocketed_by > 0:
		queen_label.text = "👑 Queen Pocketed — Needs Cover (P%d)!" % GameManager.queen_pocketed_by
		queen_label.modulate = Color(1.0, 0.65, 0.2)
	elif GameManager.queen != null and not GameManager.queen.visible:
		queen_label.text = "👑 Queen Pocketed"
		queen_label.modulate = Color(0.95, 0.4, 0.4)
	else:
		queen_label.text = "👑 Queen: On Board"
		queen_label.modulate = Color(0.92, 0.22, 0.26)
