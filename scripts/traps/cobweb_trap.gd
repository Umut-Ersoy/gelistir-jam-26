extends Area3D
class_name CobwebTrap

@export var is_instakill: bool = false
@export var is_cobweb: bool = true
@export var damage: int = 0

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node) -> void:
	if body is Player and body.has_method("take_damage"):
		body.take_damage(0, 1.0)

func _on_area_entered(area: Area3D) -> void:
	if area and area.get_parent() is Player:
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(0, 1.0)
