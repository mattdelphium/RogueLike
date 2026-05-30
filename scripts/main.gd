extends Node2D

@export var enemy_scene: PackedScene
@export var projectile_scene: PackedScene
@export var spawn_interval := 1.0
@export var attack_interval := 0.6
@export var attack_range := 240.0
@export var max_enemies := 12
@export var arena_size := Vector2(1152.0, 648.0)
@export var projectile_speed := 520.0
@export var projectile_range := 420.0
@export var show_attack_range_debug := true

var is_game_over := false
var survival_time := 0.0
var rng := RandomNumberGenerator.new()

@onready var player: CharacterBody2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var spawn_timer: Timer = $SpawnTimer
@onready var fire_timer: Timer = $FireTimer
@onready var timer_label: Label = $CanvasLayer/HUD/TimerLabel
@onready var game_over_label: Label = $CanvasLayer/HUD/GameOverLabel


func _ready() -> void:
	rng.randomize()
	spawn_timer.wait_time = spawn_interval
	fire_timer.wait_time = attack_interval
	player.arena_size = arena_size
	player.attack_range_debug_radius = attack_range
	player.show_attack_range_debug = show_attack_range_debug
	player.queue_redraw()
	player.died.connect(_on_player_died)
	game_over_label.visible = false
	_update_timer_label()


func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("restart") or Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	survival_time += delta
	_update_timer_label()


func _on_spawn_timer_timeout() -> void:
	if is_game_over:
		return

	if enemy_scene == null or enemies.get_child_count() >= max_enemies:
		return

	var enemy := enemy_scene.instantiate()
	enemy.target = player
	enemy.position = _random_spawn_position()
	enemies.add_child(enemy)


func _on_fire_timer_timeout() -> void:
	if is_game_over or projectile_scene == null:
		return

	var target_enemy := _get_nearest_enemy()
	if target_enemy == null:
		return

	var projectile := projectile_scene.instantiate()
	projectile.global_position = player.global_position
	projectile.direction = player.global_position.direction_to(target_enemy.global_position)
	projectile.move_speed = projectile_speed
	projectile.max_distance = projectile_range
	projectiles.add_child(projectile)


func _on_player_died() -> void:
	if is_game_over:
		return

	is_game_over = true
	spawn_timer.stop()
	fire_timer.stop()
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
	for projectile in projectiles.get_children():
		projectile.set_physics_process(false)
	player.set_physics_process(false)
	game_over_label.visible = true


func _random_spawn_position() -> Vector2:
	var margin := 48.0
	var side := rng.randi_range(0, 3)

	match side:
		0:
			return Vector2(rng.randf_range(0.0, arena_size.x), -margin)
		1:
			return Vector2(arena_size.x + margin, rng.randf_range(0.0, arena_size.y))
		2:
			return Vector2(rng.randf_range(0.0, arena_size.x), arena_size.y + margin)
		_:
			return Vector2(-margin, rng.randf_range(0.0, arena_size.y))


func _update_timer_label() -> void:
	timer_label.text = "Time: %.1f" % survival_time


func _get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance_squared := attack_range * attack_range

	for enemy in enemies.get_children():
		var distance_squared := player.global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy

	return nearest_enemy