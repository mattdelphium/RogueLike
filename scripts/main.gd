extends Node2D

@export var enemy_scene: PackedScene
@export var tank_enemy_scene: PackedScene
@export var projectile_scene: PackedScene
@export var impact_scene: PackedScene
@export var spawn_interval := 1.0
@export var min_spawn_interval := 0.35
@export var spawn_interval_decay := 0.02
@export var attack_interval := 0.6
@export var attack_range := 240.0
@export var base_projectile_count := 1
@export var spread_projectile_count := 2
@export var projectile_spread_degrees := 14.0
@export var spread_shot_unlock_time := 20.0
@export var piercing_unlock_time := 35.0
@export var piercing_projectile_hits := 2
@export var tank_spawn_start_time := 15.0
@export var tank_spawn_chance := 0.18
@export var max_enemies := 20
@export var arena_size := Vector2(1152.0, 648.0)
@export var projectile_speed := 320.0
@export var projectile_range := 620.0
@export var show_attack_range_debug := true

var is_game_over := false
var survival_time := 0.0
var best_survival_time := 0.0
var has_announced_spread_shot := false
var has_announced_piercing_shot := false
var rng := RandomNumberGenerator.new()

@onready var player: CharacterBody2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var spawn_timer: Timer = $SpawnTimer
@onready var fire_timer: Timer = $FireTimer
@onready var timer_label: Label = $CanvasLayer/HUD/TimerLabel
@onready var weapon_label: Label = $CanvasLayer/HUD/WeaponLabel
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
	_update_weapon_label()
	_update_timer_label()


func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("restart") or Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	survival_time += delta
	spawn_timer.wait_time = _get_current_spawn_interval()
	if not has_announced_spread_shot and _is_spread_shot_unlocked():
		has_announced_spread_shot = true
		_update_weapon_label()
	if not has_announced_piercing_shot and _is_piercing_unlocked():
		has_announced_piercing_shot = true
		_update_weapon_label()
	_update_timer_label()


func _on_spawn_timer_timeout() -> void:
	if is_game_over:
		return

	var selected_enemy_scene := _select_enemy_scene()
	if selected_enemy_scene == null or enemies.get_child_count() >= max_enemies:
		return

	var enemy := selected_enemy_scene.instantiate()
	enemy.target = player
	enemy.position = _random_spawn_position()
	enemies.add_child(enemy)


func _on_fire_timer_timeout() -> void:
	if is_game_over or projectile_scene == null:
		return

	var target_enemy: Node2D = _get_nearest_enemy()
	if target_enemy == null:
		return

	var base_direction: Vector2 = player.global_position.direction_to(target_enemy.global_position)
	var spread_count: int = _get_current_projectile_count()
	var spread_radians: float = deg_to_rad(projectile_spread_degrees)
	var start_angle: float = -spread_radians * 0.5
	var step_angle: float = 0.0

	if spread_count > 1:
		step_angle = spread_radians / float(spread_count - 1)

	for projectile_index in range(spread_count):
		var angle_offset: float = start_angle + step_angle * float(projectile_index)
		_spawn_projectile(base_direction.rotated(angle_offset))


func _on_player_died() -> void:
	if is_game_over:
		return

	is_game_over = true
	best_survival_time = max(best_survival_time, survival_time)
	spawn_timer.stop()
	fire_timer.stop()
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
	for projectile in projectiles.get_children():
		projectile.set_physics_process(false)
	player.set_physics_process(false)
	game_over_label.text = "Game Over\nTime: %.1f\nBest: %.1f\nPress R to restart" % [survival_time, best_survival_time]
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


func _update_weapon_label() -> void:
	if _is_piercing_unlocked() and _is_spread_shot_unlocked():
		weapon_label.text = "Weapon: Piercing Spread"
		return

	if _is_piercing_unlocked():
		weapon_label.text = "Weapon: Piercing Shot"
		return

	if _is_spread_shot_unlocked():
		weapon_label.text = "Weapon: Spread Shot"
		return

	weapon_label.text = "Weapon: Single Shot"


func _get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance_squared := attack_range * attack_range

	for enemy in enemies.get_children():
		var distance_squared := player.global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy

	return nearest_enemy


func _get_current_spawn_interval() -> float:
	return max(min_spawn_interval, spawn_interval - survival_time * spawn_interval_decay)


func _get_current_projectile_count() -> int:
	if _is_spread_shot_unlocked():
		return maxi(spread_projectile_count, 1)

	return maxi(base_projectile_count, 1)


func _is_spread_shot_unlocked() -> bool:
	return survival_time >= spread_shot_unlock_time


func _is_piercing_unlocked() -> bool:
	return survival_time >= piercing_unlock_time


func _select_enemy_scene() -> PackedScene:
	if enemy_scene == null:
		return null

	if tank_enemy_scene != null and survival_time >= tank_spawn_start_time and rng.randf() < tank_spawn_chance:
		return tank_enemy_scene

	return enemy_scene


func _spawn_projectile(direction: Vector2) -> void:
	var projectile := projectile_scene.instantiate()
	projectile.global_position = player.global_position
	projectile.direction = direction.normalized()
	projectile.move_speed = projectile_speed
	projectile.max_distance = projectile_range
	projectile.remaining_hits = _get_projectile_hit_capacity()
	projectile.impact_scene = impact_scene
	projectile.impact_parent = projectiles
	projectiles.add_child(projectile)


func _get_projectile_hit_capacity() -> int:
	if _is_piercing_unlocked():
		return maxi(piercing_projectile_hits, 1)

	return 1