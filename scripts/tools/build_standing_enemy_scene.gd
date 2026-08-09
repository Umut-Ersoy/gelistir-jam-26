@tool
extends SceneTree

func _init() -> void:
	print("--- Running Godot CLI: Building StandingEnemy Sample Scene ---")

	# Root node: StandingEnemy (CharacterBody3D)
	var enemy = CharacterBody3D.new()
	enemy.name = "StandingEnemy"
	var script = load("res://scripts/entities/standing_enemy.gd")
	if script:
		enemy.set_script(script)

	# 1. CollisionShape3D for Player attack raycast hits
	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 2.0
	col.shape = capsule
	col.position = Vector3(0, 1.0, 0)
	enemy.add_child(col)

	# 2. Visual Plane (MeshInstance3D - 2D Billboard / Plane placeholder)
	var visual = MeshInstance3D.new()
	visual.name = "Visual"
	var quad = QuadMesh.new()
	quad.size = Vector2(1.5, 2.0)
	visual.mesh = quad
	visual.position = Vector3(0, 1.0, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.2, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	enemy.add_child(visual)

	# 3. TriggerArea (Area3D - Player detection / Attack range)
	var trigger_area = Area3D.new()
	trigger_area.name = "TriggerArea"
	var trig_col = CollisionShape3D.new()
	trig_col.name = "TriggerCollision"
	var cylinder = CylinderShape3D.new()
	cylinder.radius = 2.5
	cylinder.height = 3.0
	trig_col.shape = cylinder
	trig_col.position = Vector3(0, 1.0, 0)
	trigger_area.add_child(trig_col)
	enemy.add_child(trigger_area)

	# 4. RayCast3D for floor/environment detection & automatic self-destruct
	var raycast = RayCast3D.new()
	raycast.name = "RayCast3D"
	raycast.position = Vector3(0, 1.0, 0)
	raycast.target_position = Vector3(0, -2.0, 0)
	raycast.enabled = true
	enemy.add_child(raycast)

	# Set ownership for scene serialization
	set_owner_recursive(enemy, enemy)

	# Pack and Save to res://scenes/entities/standing_enemies/sample_standing_enemy.tscn
	var packed_scene = PackedScene.new()
	var pack_res = packed_scene.pack(enemy)
	if pack_res == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes/entities/standing_enemies")
		var save_res = ResourceSaver.save(packed_scene, "res://scenes/entities/standing_enemies/sample_standing_enemy.tscn")
		if save_res == OK:
			print("Successfully built and saved StandingEnemy scene at res://scenes/entities/standing_enemies/sample_standing_enemy.tscn!")
		else:
			print("Error saving StandingEnemy scene: ", save_res)
	else:
		print("Error packing StandingEnemy scene: ", pack_res)

	enemy.free()
	quit()

func set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		set_owner_recursive(child, root)
