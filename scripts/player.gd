extends CharacterBody2D

signal died

@export var move_speed := 260.0
@export var arena_size := Vector2(1152.0, 648.0)
@export var attack_range_debug_radius := 0.0
@export var show_attack_range_debug := true


func _ready() -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var direction := _get_move_direction()
	velocity = direction * move_speed
	move_and_slide()
	position = position.clamp(Vector2(16.0, 16.0), arena_size - Vector2(16.0, 16.0))

	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision.get_collider() is Node and collision.get_collider().is_in_group("enemies"):
			died.emit()
			break


func _get_move_direction() -> Vector2:
	var keyboard_direction := Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	)

	return keyboard_direction.normalized()


func _draw() -> void:
	if not show_attack_range_debug or attack_range_debug_radius <= 0.0:
		return

	draw_arc(Vector2.ZERO, attack_range_debug_radius, 0.0, TAU, 64, Color(1.0, 0.95, 0.45, 0.45), 2.0)