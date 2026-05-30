extends Area2D

var direction := Vector2.ZERO
var move_speed := 520.0
var max_distance := 420.0

var distance_traveled := 0.0


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

	if body.has_method("die"):
		body.die()

	queue_free()