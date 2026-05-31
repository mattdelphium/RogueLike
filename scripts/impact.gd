extends Node2D

@export var duration := 0.1

@onready var ring: Polygon2D = $Ring


func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.6, 1.6), duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	await tween.finished
	queue_free()