@tool
extends SceneTree

func _init() -> void:
	print("--- Running Godot CLI: Building Environment & Trap Scenes ---")
	DirAccess.make_dir_recursive_absolute("res://scenes/environment")
	DirAccess.make_dir_recursive_absolute("res://scenes/traps")

	build_floor_tile_scene()
	build_wall_bottom_tile_scene()
	build_wall_mid_tile_scene()
	build_wall_top_tile_scene()
	build_stairs_tile_scene()
	build_base_trap_scene()

	quit()

func build_floor_tile_scene() -> void:
	var root = Node3D.new()
	root.name = "FloorTile"
	var script = load("res://scripts/environment/floor_tile.gd")
	if script: root.set_script(script)

	var static_body = StaticBody3D.new()
	static_body.name = "FloorBody"
	root.add_child(static_body)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 0.1, 1.0)
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.1, 1.0)
	col.shape = box_shape
	static_body.add_child(col)

	save_packed_scene(root, "res://scenes/environment/floor_tile.tscn")

func build_wall_bottom_tile_scene() -> void:
	var root = Node3D.new()
	root.name = "WallBottomTile"
	var script = load("res://scripts/environment/wall_bottom_tile.gd")
	if script: root.set_script(script)

	var static_body = StaticBody3D.new()
	static_body.name = "WallBody"
	root.add_child(static_body)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 2.0, 0.2)
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 2.0, 0.2)
	col.shape = box_shape
	static_body.add_child(col)

	save_packed_scene(root, "res://scenes/environment/wall_bottom_tile.tscn")

func build_wall_mid_tile_scene() -> void:
	var root = Node3D.new()
	root.name = "WallMidTile"
	var script = load("res://scripts/environment/wall_mid_tile.gd")
	if script: root.set_script(script)

	var static_body = StaticBody3D.new()
	static_body.name = "WallBody"
	root.add_child(static_body)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 0.2)
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 0.2)
	col.shape = box_shape
	static_body.add_child(col)

	save_packed_scene(root, "res://scenes/environment/wall_mid_tile.tscn")

func build_wall_top_tile_scene() -> void:
	var root = Node3D.new()
	root.name = "WallTopTile"
	var script = load("res://scripts/environment/wall_top_tile.gd")
	if script: root.set_script(script)

	var static_body = StaticBody3D.new()
	static_body.name = "WallBody"
	root.add_child(static_body)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 1.0, 0.2)
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 0.2)
	col.shape = box_shape
	static_body.add_child(col)

	save_packed_scene(root, "res://scenes/environment/wall_top_tile.tscn")

func build_stairs_tile_scene() -> void:
	var root = Node3D.new()
	root.name = "StairsTile"
	var script = load("res://scripts/environment/stairs_tile.gd")
	if script: root.set_script(script)

	var static_body = StaticBody3D.new()
	static_body.name = "StairsBody"
	root.add_child(static_body)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.0, 0.5, 1.0)
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.5, 1.0)
	col.shape = box_shape
	static_body.add_child(col)

	save_packed_scene(root, "res://scenes/environment/stairs_tile.tscn")

func build_base_trap_scene() -> void:
	var trap = Area3D.new()
	trap.name = "TrapArea"
	var script = load("res://scripts/traps/base_trap.gd")
	if script: trap.set_script(script)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.4, 1.0)
	col.shape = box_shape
	trap.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.9, 0.2, 0.9)
	mesh_inst.mesh = box_mesh
	trap.add_child(mesh_inst)

	save_packed_scene(trap, "res://scenes/traps/base_trap.tscn")

func save_packed_scene(root_node: Node, path: String) -> void:
	set_owner_recursive(root_node, root_node)
	var packed_scene = PackedScene.new()
	var pack_res = packed_scene.pack(root_node)
	if pack_res == OK:
		var save_res = ResourceSaver.save(packed_scene, path)
		if save_res == OK:
			print("Saved scene to: ", path)
		else:
			print("Error saving ", path, ": ", save_res)
	else:
		print("Error packing scene ", path, ": ", pack_res)
	root_node.free()

func set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		set_owner_recursive(child, root)
