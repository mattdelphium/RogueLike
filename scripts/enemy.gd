extends CharacterBody2D

@export var move_speed := 140.0
@export var hit_feedback_duration := 0.08

var target: Node2D
var is_dying := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return

	velocity = global_position.direction_to(target.global_position) * move_speed
	move_and_slide()


func die() -> void:
	if is_dying:
		return

	is_dying = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	collision_shape.disabled = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body, "color", Color(1.0, 0.96, 0.72, 1.0), hit_feedback_duration)
	tween.tween_property(body, "scale", Vector2(1.2, 1.2), hit_feedback_duration)
	tween.chain().tween_property(body, "scale", Vector2(0.0, 0.0), hit_feedback_duration)
	await tween.finished
	queue_free()