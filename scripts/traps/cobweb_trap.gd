extends Area3D
class_name CobwebTrap

@export var is_instakill: bool = false
@export var is_cobweb: bool = true
@export var damage: int = 0

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var visual_mesh: MeshInstance3D = get_node_or_null("Visual")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

## Dynamically scales collision box and mesh to stretch from floor to ceiling and left wall to right wall
func setup_size(width: float, height: float) -> void:
	if collision_shape:
		var box = BoxShape3D.new()
		box.size = Vector3(width, height, 0.4)
		collision_shape.shape = box

	if visual_mesh:
		var quad = QuadMesh.new()
		quad.size = Vector2(width, height)
		visual_mesh.mesh = quad

func _on_body_entered(body: Node) -> void:
	if body is Player and body.has_method("take_damage"):
		body.take_damage(0)

func _on_area_entered(area: Area3D) -> void:
	if area and area.get_parent() is Player:
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(0)
