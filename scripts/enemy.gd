extends CharacterBody2D

@export var move_speed := 140.0
@export var max_health := 1
@export var hit_feedback_duration := 0.08
@export var low_health_color := Color(1.0, 0.74, 0.42, 1.0)

var target: Node2D
var is_dying := false
var current_health := 0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body
@onready var base_color: Color = body.color


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	_update_damage_visuals()


func _physics_process(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return

	velocity = global_position.direction_to(target.global_position) * move_speed
	move_and_slide()


func take_hit(damage := 1) -> void:
	if is_dying:
		return

	current_health = max(current_health - damage, 0)
	if current_health <= 0:
		die()
		return

	_update_damage_visuals()
	_show_hit_flash()


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


func _show_hit_flash() -> void:
	var tween := create_tween()
	tween.tween_property(body, "color", Color(1.0, 0.96, 0.72, 1.0), hit_feedback_duration * 0.5)
	tween.tween_property(body, "color", _get_damage_tint(), hit_feedback_duration * 0.5)


func _update_damage_visuals() -> void:
	body.color = _get_damage_tint()


func _get_damage_tint() -> Color:
	if max_health <= 1:
		return base_color

	var health_ratio := float(current_health) / float(max_health)
	return low_health_color.lerp(base_color, health_ratio)