@tool
extends SceneTree

func _init() -> void:
	print("--- Running Godot CLI: Building player.tscn Scene ---")

	# Root node: Player (CharacterBody3D)
	var player = CharacterBody3D.new()
	player.name = "Player"
	var player_script = load("res://scripts/player/player.gd")
	if player_script:
		player.set_script(player_script)

	# 1. CollisionShape3D
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 2.0
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 1.0, 0)
	player.add_child(collision_shape)

	# 2. Hurtbox (Area3D)
	var hurtbox = Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.position = Vector3(0, 1.0, 0)
	var hurtbox_col = CollisionShape3D.new()
	hurtbox_col.name = "HurtboxCollision"
	var hurtbox_capsule = CapsuleShape3D.new()
	hurtbox_capsule.radius = 0.45
	hurtbox_capsule.height = 2.0
	hurtbox_col.shape = hurtbox_capsule
	hurtbox.add_child(hurtbox_col)
	player.add_child(hurtbox)

	# 3. Camera3D
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 1.5, 0)
	player.add_child(camera)

	# 4. HandWeapon (Node3D under Camera3D)
	var hand_weapon = Node3D.new()
	hand_weapon.name = "HandWeapon"
	hand_weapon.position = Vector3(0.3, -0.25, -0.5)
	camera.add_child(hand_weapon)

	# 5. AnimatedSprite3D (Flute)
	var anim_sprite = AnimatedSprite3D.new()
	anim_sprite.name = "AnimatedSprite3D"
	anim_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hand_weapon.add_child(anim_sprite)

	# 6. AttackRayCast (RayCast3D)
	var attack_raycast = RayCast3D.new()
	attack_raycast.name = "AttackRayCast"
	attack_raycast.target_position = Vector3(0, 0, -3.0)
	attack_raycast.enabled = true
	hand_weapon.add_child(attack_raycast)

	# 7. ShapeCastLeft
	var shapecast_left = ShapeCast3D.new()
	shapecast_left.name = "ShapeCastLeft"
	shapecast_left.position = Vector3(0, 1.0, 0)
	shapecast_left.target_position = Vector3(-0.8, 0, 0)
	var sphere_left = SphereShape3D.new()
	sphere_left.radius = 0.2
	shapecast_left.shape = sphere_left
	shapecast_left.enabled = true
	player.add_child(shapecast_left)

	# 8. ShapeCastRight
	var shapecast_right = ShapeCast3D.new()
	shapecast_right.name = "ShapeCastRight"
	shapecast_right.position = Vector3(0, 1.0, 0)
	shapecast_right.target_position = Vector3(0.8, 0, 0)
	var sphere_right = SphereShape3D.new()
	sphere_right.radius = 0.2
	shapecast_right.shape = sphere_right
	shapecast_right.enabled = true
	player.add_child(shapecast_right)

	# 9. PlayerStateMachine (Node)
	var state_machine = Node.new()
	state_machine.name = "PlayerStateMachine"
	var sm_script = load("res://core/state_machine/state_machine.gd")
	if sm_script:
		state_machine.set_script(sm_script)
	player.add_child(state_machine)

	# 10. GetHitTimer (Timer)
	var get_hit_timer = Timer.new()
	get_hit_timer.name = "GetHitTimer"
	get_hit_timer.wait_time = 0.2
	get_hit_timer.one_shot = true
	player.add_child(get_hit_timer)

	# 11. AttackTimer (Timer)
	var attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	player.add_child(attack_timer)

	# Set node ownership for scene persistence
	set_owner_recursive(player, player)

	# Pack into PackedScene and save to res://scenes/player/player.tscn
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(player)
	if pack_result == OK:
		# Ensure directory exists
		DirAccess.make_dir_recursive_absolute("res://scenes/player")
		var save_result = ResourceSaver.save(packed_scene, "res://scenes/player/player.tscn")
		if save_result == OK:
			print("Successfully built and saved player.tscn scene!")
		else:
			print("Error saving player.tscn: ", save_result)
	else:
		print("Error packing player scene: ", pack_result)

	player.free()
	quit()

func set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		set_owner_recursive(child, root)
