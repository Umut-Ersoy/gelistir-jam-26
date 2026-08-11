@tool
extends SceneTree

func _init() -> void:
	print("--- Running Godot CLI: Building RootScene with Environment & Lighting ---")

	# Root node: RootScene (Node3D)
	var root_scene = Node3D.new()
	root_scene.name = "RootScene"

	# 1. Environment Node Container
	var env_container = Node3D.new()
	env_container.name = "Environment"
	root_scene.add_child(env_container)

	# 1a. WorldEnvironment
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var env = Environment.new()
	# Background settings
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.bg_color = Color(0.04, 0.04, 0.07)

	# Ambient light settings
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.18, 0.22)
	env.ambient_light_energy = 0.6

	# Fog / Render distance boundary settings
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.06, 0.10)
	env.fog_density = 0.02
	env.fog_aerial_perspective = 0.5

	# Tonemapping for Forward+ aesthetic
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0

	world_env.environment = env
	env_container.add_child(world_env)

	# 1b. DirectionalLight3D
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	dir_light.light_color = Color(0.95, 0.88, 0.78)
	dir_light.light_energy = 1.2
	dir_light.shadow_enabled = true
	dir_light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	env_container.add_child(dir_light)

	# 2. DungeonGenerator (Node3D)
	var dungeon_gen = Node3D.new()
	dungeon_gen.name = "DungeonGenerator"
	var dg_script = load("res://scripts/environment/dungeon_generator.gd")
	if dg_script:
		dungeon_gen.set_script(dg_script)
	var active_corridors = Node3D.new()
	active_corridors.name = "ActiveCorridors"
	dungeon_gen.add_child(active_corridors)
	root_scene.add_child(dungeon_gen)

	# 3. Player Instance
	var player_scene = load("res://scenes/player/player.tscn")
	if player_scene:
		var player_instance = player_scene.instantiate()
		player_instance.name = "Player"
		root_scene.add_child(player_instance)
	else:
		print("Warning: res://scenes/player/player.tscn not found!")

	# 4. ChasingHorde Instance (or build with script & placeholder plane)
	var horde_scene = load("res://scenes/entities/chasing_horde.tscn")
	if horde_scene:
		var horde_instance = horde_scene.instantiate()
		horde_instance.name = "ChasingHorde"
		horde_instance.position = Vector3(0, 0, 10.0) # Positioned behind starting player position
		root_scene.add_child(horde_instance)
	else:
		var chasing_horde = Area3D.new()
		chasing_horde.name = "ChasingHorde"
		chasing_horde.position = Vector3(0, 0, 10.0)
		var horde_script = load("res://scripts/entities/chasing_horde.gd")
		if horde_script:
			chasing_horde.set_script(horde_script)

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
		chasing_horde.add_child(visual)

		var horde_collision = CollisionShape3D.new()
		horde_collision.name = "CollisionShape3D"
		var horde_box = BoxShape3D.new()
		horde_box.size = Vector3(20.0, 10.0, 2.0)
		horde_collision.shape = horde_box
		horde_collision.position = Vector3(0, 5.0, 0)
		chasing_horde.add_child(horde_collision)

		root_scene.add_child(chasing_horde)

	# Set ownership for scene serialization
	set_owner_recursive(root_scene, root_scene)

	# Pack and Save to res://scenes/main/root_scene.tscn
	var packed_scene = PackedScene.new()
	var pack_res = packed_scene.pack(root_scene)
	if pack_res == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes/main")
		var save_res = ResourceSaver.save(packed_scene, "res://scenes/main/root_scene.tscn")
		if save_res == OK:
			print("Successfully built and saved RootScene at res://scenes/main/root_scene.tscn!")
		else:
			print("Error saving RootScene: ", save_res)
	else:
		print("Error packing RootScene: ", pack_res)

	root_scene.free()
	quit()

func set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		set_owner_recursive(child, root)
