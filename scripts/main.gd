extends Node2D

@export var enemy_scene: PackedScene
@export var runner_enemy_scene: PackedScene
@export var tank_enemy_scene: PackedScene
@export var projectile_scene: PackedScene
@export var impact_scene: PackedScene
@export var spawn_interval := 1.0
@export var min_spawn_interval := 0.35
@export var spawn_interval_decay := 0.02
@export var attack_interval := 0.4
@export var attack_range := 340.0
@export var base_projectile_count := 1
@export var spread_projectile_count := 2
@export var projectile_spread_degrees := 14.0
@export var spread_shot_unlock_time := 20.0
@export var piercing_unlock_time := 35.0
@export var piercing_projectile_hits := 2
@export var ricochet_unlock_time := 50.0
@export var ricochet_bounces := 1
@export var ricochet_search_radius := 260.0
@export var upgrade_interval := 18.0
@export var runner_spawn_start_time := 25.0
@export var runner_spawn_chance := 0.22
@export var tank_spawn_start_time := 15.0
@export var tank_spawn_chance := 0.18
@export var max_enemies := 20
@export var arena_size := Vector2(1152.0, 648.0)
@export var projectile_speed := 320.0
@export var projectile_range := 620.0
@export var show_attack_range_debug := true
@export var unlock_announcement_duration := 1.4

var is_game_over := false
var is_upgrade_selection_active := false
var survival_time := 0.0
var best_survival_time := 0.0
var next_upgrade_time := 0.0
var has_announced_spread_shot := false
var has_announced_piercing_shot := false
var has_announced_ricochet := false
var current_upgrade_choices: Array = []
var unlock_announcement_tween: Tween = null
var weapon_label_tween: Tween = null
var rng := RandomNumberGenerator.new()

@onready var player: CharacterBody2D = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var spawn_timer: Timer = $SpawnTimer
@onready var fire_timer: Timer = $FireTimer
@onready var timer_label: Label = $CanvasLayer/HUD/TimerLabel
@onready var weapon_label: Label = $CanvasLayer/HUD/WeaponLabel
@onready var unlock_label: Label = $CanvasLayer/HUD/UnlockLabel
@onready var upgrade_panel: Control = $CanvasLayer/HUD/UpgradePanel
@onready var upgrade_option_1_label: Label = $CanvasLayer/HUD/UpgradePanel/Option1Label
@onready var upgrade_option_2_label: Label = $CanvasLayer/HUD/UpgradePanel/Option2Label
@onready var game_over_label: Label = $CanvasLayer/HUD/GameOverLabel


func _ready() -> void:
	rng.randomize()
	next_upgrade_time = upgrade_interval
	spawn_timer.wait_time = spawn_interval
	fire_timer.wait_time = attack_interval
	player.arena_size = arena_size
	player.attack_range_debug_radius = attack_range
	player.show_attack_range_debug = show_attack_range_debug
	player.queue_redraw()
	player.died.connect(_on_player_died)
	game_over_label.visible = false
	unlock_label.visible = false
	unlock_label.modulate.a = 0.0
	upgrade_panel.visible = false
	_update_weapon_label()
	_update_timer_label()


func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("restart") or Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	if is_upgrade_selection_active:
		_handle_upgrade_input()
		return

	survival_time += delta
	spawn_timer.wait_time = _get_current_spawn_interval()
	if survival_time >= next_upgrade_time:
		next_upgrade_time += upgrade_interval
		_open_upgrade_selection()
		return
	if not has_announced_spread_shot and _is_spread_shot_unlocked():
		has_announced_spread_shot = true
		_update_weapon_label()
		_announce_unlock("Spread Shot Unlocked")
	if not has_announced_piercing_shot and _is_piercing_unlocked():
		has_announced_piercing_shot = true
		_update_weapon_label()
		_announce_unlock("Piercing Unlocked")
	if not has_announced_ricochet and _is_ricochet_unlocked():
		has_announced_ricochet = true
		_update_weapon_label()
		_announce_unlock("Ricochet Unlocked")
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
	if _is_ricochet_unlocked() and _is_piercing_unlocked() and _is_spread_shot_unlocked():
		weapon_label.text = "Weapon: Ricochet Spread"
		return

	if _is_ricochet_unlocked() and _is_piercing_unlocked():
		weapon_label.text = "Weapon: Ricochet Pierce"
		return

	if _is_ricochet_unlocked():
		weapon_label.text = "Weapon: Ricochet Shot"
		return

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


func _announce_unlock(message: String) -> void:
	unlock_label.text = message
	unlock_label.visible = true
	unlock_label.scale = Vector2.ONE * 0.92
	unlock_label.modulate = Color(1.0, 0.96, 0.72, 0.0)

	if unlock_announcement_tween != null:
		unlock_announcement_tween.kill()
	if weapon_label_tween != null:
		weapon_label_tween.kill()

	unlock_announcement_tween = create_tween()
	unlock_announcement_tween.set_parallel(true)
	unlock_announcement_tween.tween_property(unlock_label, "modulate:a", 1.0, 0.15)
	unlock_announcement_tween.tween_property(unlock_label, "scale", Vector2.ONE, 0.15)
	unlock_announcement_tween.chain().tween_interval(max(unlock_announcement_duration - 0.35, 0.0))
	unlock_announcement_tween.chain().tween_property(unlock_label, "modulate:a", 0.0, 0.2)
	unlock_announcement_tween.finished.connect(_on_unlock_announcement_finished, CONNECT_ONE_SHOT)

	weapon_label.scale = Vector2.ONE
	weapon_label_tween = create_tween()
	weapon_label_tween.tween_property(weapon_label, "scale", Vector2(1.08, 1.08), 0.12)
	weapon_label_tween.tween_property(weapon_label, "scale", Vector2.ONE, 0.12)


func _on_unlock_announcement_finished() -> void:
	unlock_label.visible = false


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


func _is_ricochet_unlocked() -> bool:
	return survival_time >= ricochet_unlock_time


func _select_enemy_scene() -> PackedScene:
	if enemy_scene == null:
		return null

	var roll := rng.randf()
	if runner_enemy_scene != null and survival_time >= runner_spawn_start_time and roll < runner_spawn_chance:
		return runner_enemy_scene

	if tank_enemy_scene != null and survival_time >= tank_spawn_start_time and roll < runner_spawn_chance + tank_spawn_chance:
		return tank_enemy_scene

	return enemy_scene


func _spawn_projectile(direction: Vector2) -> void:
	var projectile := projectile_scene.instantiate()
	projectile.global_position = player.global_position
	projectile.direction = direction.normalized()
	projectile.move_speed = projectile_speed
	projectile.max_distance = projectile_range
	projectile.remaining_hits = _get_projectile_hit_capacity()
	projectile.remaining_bounces = _get_projectile_bounce_capacity()
	projectile.ricochet_search_radius = ricochet_search_radius
	projectile.enemy_parent = enemies
	projectile.impact_scene = impact_scene
	projectile.impact_parent = projectiles
	projectiles.add_child(projectile)


func _get_projectile_hit_capacity() -> int:
	if _is_piercing_unlocked():
		return maxi(piercing_projectile_hits, 1)

	return 1


func _get_projectile_bounce_capacity() -> int:
	if _is_ricochet_unlocked():
		return maxi(ricochet_bounces, 0)

	return 0


func _open_upgrade_selection() -> void:
	is_upgrade_selection_active = true
	current_upgrade_choices = _build_upgrade_choices()
	if current_upgrade_choices.size() < 2:
		is_upgrade_selection_active = false
		return

	spawn_timer.stop()
	fire_timer.stop()
	player.set_physics_process(false)
	for enemy in enemies.get_children():
		enemy.set_physics_process(false)
	for projectile in projectiles.get_children():
		projectile.set_physics_process(false)

	upgrade_option_1_label.text = _format_upgrade_option(1, current_upgrade_choices[0])
	upgrade_option_2_label.text = _format_upgrade_option(2, current_upgrade_choices[1])
	upgrade_panel.visible = true


func _close_upgrade_selection() -> void:
	is_upgrade_selection_active = false
	upgrade_panel.visible = false
	current_upgrade_choices.clear()
	spawn_timer.start(spawn_timer.wait_time)
	fire_timer.wait_time = attack_interval
	fire_timer.start(fire_timer.wait_time)
	player.set_physics_process(true)
	for enemy in enemies.get_children():
		enemy.set_physics_process(true)
	for projectile in projectiles.get_children():
		projectile.set_physics_process(true)


func _handle_upgrade_input() -> void:
	if Input.is_physical_key_pressed(KEY_1) or Input.is_physical_key_pressed(KEY_KP_1):
		_apply_upgrade_choice(0)
	elif Input.is_physical_key_pressed(KEY_2) or Input.is_physical_key_pressed(KEY_KP_2):
		_apply_upgrade_choice(1)


func _apply_upgrade_choice(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= current_upgrade_choices.size():
		return

	var choice: Dictionary = current_upgrade_choices[choice_index]
	match String(choice["id"]):
		"move_speed":
			player.move_speed += 40.0
		"attack_speed":
			attack_interval = max(0.18, attack_interval - 0.05)
		"projectile_speed":
			projectile_speed += 70.0
		"projectile_range":
			projectile_range += 90.0
		"attack_range":
			attack_range += 40.0
			player.attack_range_debug_radius = attack_range
			player.queue_redraw()

	_update_weapon_label()
	_announce_unlock(String(choice["title"]))
	_close_upgrade_selection()


func _build_upgrade_choices() -> Array:
	var pool: Array = _get_upgrade_pool()
	var choices: Array = []
	while choices.size() < 2 and not pool.is_empty():
		var choice_index: int = rng.randi_range(0, pool.size() - 1)
		choices.append(pool[choice_index])
		pool.remove_at(choice_index)

	return choices


func _get_upgrade_pool() -> Array:
	var upgrades: Array = []
	upgrades.append({"id": "move_speed", "title": "Swift Boots", "description": "+40 move speed"})
	upgrades.append({"id": "attack_speed", "title": "Quick Hands", "description": "Faster attack rate"})
	upgrades.append({"id": "projectile_speed", "title": "Sharpened Rounds", "description": "+70 projectile speed"})
	upgrades.append({"id": "projectile_range", "title": "Long Barrel", "description": "+90 projectile range"})
	upgrades.append({"id": "attack_range", "title": "Targeting Lens", "description": "+40 attack range"})
	return upgrades


func _format_upgrade_option(option_number: int, choice: Dictionary) -> String:
	return "%d. %s\n%s" % [option_number, String(choice["title"]), String(choice["description"])]