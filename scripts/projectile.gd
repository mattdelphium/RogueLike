extends Area2D

var direction := Vector2.ZERO
var move_speed := 520.0
var max_distance := 420.0
var remaining_hits := 1
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


func _spawn_impact() -> void:
	if impact_scene == null or impact_parent == null:
		return

	var impact := impact_scene.instantiate()
	impact.global_position = global_position
	impact.rotation = rotation
	impact_parent.add_child(impact)