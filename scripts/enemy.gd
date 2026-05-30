extends CharacterBody2D

@export var move_speed := 140.0

var target: Node2D


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return

	velocity = global_position.direction_to(target.global_position) * move_speed
	move_and_slide()


func die() -> void:
	queue_free()