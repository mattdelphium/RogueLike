extends CharacterBody2D

signal died

@export var move_speed := 260.0
@export var arena_size := Vector2(1152.0, 648.0)


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
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		return direction

	var fallback_direction := Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)

	return fallback_direction.normalized()