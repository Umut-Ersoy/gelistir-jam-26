@tool
extends SceneTree

func _init() -> void:
	print("--- Running Godot CLI: Building CobwebTrap Scene ---")

	# Root node: CobwebTrap (Area3D)
	var trap = Area3D.new()
	trap.name = "CobwebTrap"
	var script = load("res://scripts/traps/cobweb_trap.gd")
	if script:
		trap.set_script(script)

	# 1. Visual MeshInstance3D (QuadMesh placeholder for spider web sheet)
	var visual = MeshInstance3D.new()
	visual.name = "Visual"
	var quad = QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	visual.mesh = quad

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.96, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	trap.add_child(visual)

	# 2. CollisionShape3D (BoxShape3D)
	var col_shape = CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.4)
	col_shape.shape = box
	trap.add_child(col_shape)

	# Set ownership for scene serialization
	set_owner_recursive(trap, trap)

	# Pack and Save to res://scenes/traps/cobweb_trap.tscn
	var packed_scene = PackedScene.new()
	var pack_res = packed_scene.pack(trap)
	if pack_res == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes/traps")
		var save_res = ResourceSaver.save(packed_scene, "res://scenes/traps/cobweb_trap.tscn")
		if save_res == OK:
			print("Successfully built and saved CobwebTrap scene at res://scenes/traps/cobweb_trap.tscn!")
		else:
			print("Error saving CobwebTrap scene: ", save_res)
	else:
		print("Error packing CobwebTrap scene: ", pack_res)

	trap.free()
	quit()

func set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		set_owner_recursive(child, root)
