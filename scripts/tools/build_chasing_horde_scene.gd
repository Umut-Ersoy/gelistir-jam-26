@tool
extends SceneTree

func _init() -> void:
	print("--- Running Godot CLI: Building ChasingHorde Scene ---")

	# Root node: ChasingHorde (Area3D)
	var horde = Area3D.new()
	horde.name = "ChasingHorde"
	var script = load("res://scripts/entities/chasing_horde.gd")
	if script:
		horde.set_script(script)

	# 1. Visual Plane (MeshInstance3D)
	# QuadMesh is used as placeholder for the future AnimatedSprite2D / 2D Billboard horde
	var visual = MeshInstance3D.new()
	visual.name = "Visual"
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(20.0, 10.0)
	visual.mesh = quad_mesh
	visual.position = Vector3(0, 5.0, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.15, 0.15, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad_mesh.material = mat

	horde.add_child(visual)

	# 2. CollisionShape3D (BoxShape3D)
	var col_shape = CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	box.size = Vector3(20.0, 10.0, 2.0)
	col_shape.shape = box
	col_shape.position = Vector3(0, 5.0, 0)

	horde.add_child(col_shape)

	# Set ownership for scene serialization
	set_owner_recursive(horde, horde)

	# Pack and Save to res://scenes/entities/chasing_horde.tscn
	var packed_scene = PackedScene.new()
	var pack_res = packed_scene.pack(horde)
	if pack_res == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes/entities")
		var save_res = ResourceSaver.save(packed_scene, "res://scenes/entities/chasing_horde.tscn")
		if save_res == OK:
			print("Successfully built and saved ChasingHorde scene at res://scenes/entities/chasing_horde.tscn!")
		else:
			print("Error saving ChasingHorde scene: ", save_res)
	else:
		print("Error packing ChasingHorde scene: ", pack_res)

	horde.free()
	quit()

func set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		set_owner_recursive(child, root)
