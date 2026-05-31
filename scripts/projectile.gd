extends Area2D

var direction := Vector2.ZERO
var move_speed := 520.0
var max_distance := 420.0
var remaining_hits := 1
var remaining_bounces := 0
var ricochet_search_radius := 260.0
var enemy_parent: Node2D
var impact_scene: PackedScene
var impact_parent: Node

var distance_traveled := 0.0
var hit_body_ids: Array[int] = []


func _ready() -> void:
	monitoring = true
	if direction != Vector2.ZERO:
		rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step := direction * move_speed * delta
	global_position += step
	distance_traveled += step.length()
	if distance_traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return

	var body_id := body.get_instance_id()
	if body_id in hit_body_ids:
		return
	hit_body_ids.append(body_id)

	if body.has_method("take_hit"):
		body.take_hit()
	elif body.has_method("die"):
		body.die()

	_spawn_impact()
	remaining_hits -= 1
	if remaining_hits <= 0:
		queue_free()
		return

	if remaining_bounces > 0:
		_attempt_ricochet()


func _spawn_impact() -> void:
	if impact_scene == null or impact_parent == null:
		return

	var impact := impact_scene.instantiate()
	impact.global_position = global_position
	impact.rotation = rotation
	impact_parent.add_child(impact)


func _attempt_ricochet() -> void:
	var next_target := _find_ricochet_target()
	if next_target == null:
		return

	remaining_bounces -= 1
	direction = global_position.direction_to(next_target.global_position).normalized()
	rotation = direction.angle()
	global_position += direction * 8.0


func _find_ricochet_target() -> Node2D:
	if enemy_parent == null:
		return null

	var nearest_enemy: Node2D = null
	var nearest_distance_squared := ricochet_search_radius * ricochet_search_radius

	for enemy in enemy_parent.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy.get_instance_id() in hit_body_ids:
			continue

		var distance_squared := global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy

	return nearest_enemy