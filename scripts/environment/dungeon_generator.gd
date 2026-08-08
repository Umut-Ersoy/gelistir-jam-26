extends Node3D
class_name DungeonGenerator

@export_group("Corridor Dimensions")
@export var min_corridor_length: int = 5
@export var max_corridor_length: int = 25
@export var min_corridor_width: int = 3
@export var max_corridor_width: int = 5

@export_group("Staircase Settings")
@export var end_stair_chance: float = 0.5
@export var mid_stair_chance: float = 0.4
@export var min_stairs_length: int = 3
@export var max_stairs_length: int = 7

@export_group("Spawning & Despawning")
@export var spawn_distance_ahead: float = 50.0
@export var despawn_distance_behind: float = 20.0

@export_group("Traps")
@export var trap_chance: float = 0.6
@export var weight_option_a: float = 40.0 # 1-block gap on left or right
@export var weight_option_b: float = 30.0 # 1-block gap on both sides
@export var weight_option_c: float = 30.0 # Full width trap + WallRunSurface Area3D

@export_group("Wall Settings")
@export var min_wall_height: int = 3 # Minimum total wall height in tiles (must be >= 3: 1 bottom + 1 mid + 1 top)
@export var max_wall_height: int = 6 # Maximum total wall height in tiles

# Scene resources
var floor_tile_scene: PackedScene
var wall_bottom_tile_scene: PackedScene
var wall_mid_tile_scene: PackedScene
var wall_top_tile_scene: PackedScene
var ceiling_tile_scene: PackedScene
var ceiling_stairs_tile_scene: PackedScene
var stairs_tile_scene: PackedScene
var base_trap_scene: PackedScene

# Initial Direction & Generator State
var initial_angle_deg: float = 0.0
var initial_forward_dir: Vector3 = Vector3(0, 0, -1)
var last_relative_turn: int = 0 # -90, 0, or 90
var current_position: Vector3 = Vector3.ZERO
var current_y: float = 0.0
var current_forward_dir: Vector3 = Vector3(0, 0, -1)
var current_angle_deg: float = 0.0

var is_first_corridor: bool = true
var last_platform_center: Vector3 = Vector3.ZERO
var last_platform_size: int = 0
var has_platform: bool = false
var active_wall_height: int = 3 # Wall height for the current corridor segment
var last_ceiling_y: float = -1.0 # Ceiling Y level of previous row to detect height changes

# Grid coordinate tracking dictionaries for Rule 1 & Rule 2
var floor_grid: Dictionary = {} # Vector3i -> Node3D
var wall_grid: Dictionary = {}  # Vector3i -> Node3D

var active_corridors_container: Node3D
var player_ref: Node3D

func _ready() -> void:
	# Save initial orientation in _ready()
	initial_angle_deg = rotation_degrees.y
	initial_forward_dir = -transform.basis.z.normalized()
	current_position = Vector3(round(global_position.x), round(global_position.y), round(global_position.z))
	current_y = current_position.y
	current_angle_deg = initial_angle_deg
	current_forward_dir = initial_forward_dir
	last_ceiling_y = -1.0

	# Load tile and trap scenes
	if ResourceLoader.exists("res://scenes/environment/floor_tile.tscn"):
		floor_tile_scene = load("res://scenes/environment/floor_tile.tscn")
	if ResourceLoader.exists("res://scenes/environment/wall_bottom_tile.tscn"):
		wall_bottom_tile_scene = load("res://scenes/environment/wall_bottom_tile.tscn")
	elif ResourceLoader.exists("res://scenes/environment/wall_tile.tscn"):
		wall_bottom_tile_scene = load("res://scenes/environment/wall_tile.tscn")
	if ResourceLoader.exists("res://scenes/environment/wall_mid_tile.tscn"):
		wall_mid_tile_scene = load("res://scenes/environment/wall_mid_tile.tscn")
	if ResourceLoader.exists("res://scenes/environment/wall_top_tile.tscn"):
		wall_top_tile_scene = load("res://scenes/environment/wall_top_tile.tscn")
	if ResourceLoader.exists("res://scenes/environment/ceiling_tile.tscn"):
		ceiling_tile_scene = load("res://scenes/environment/ceiling_tile.tscn")
	if ResourceLoader.exists("res://scenes/environment/ceiling_stairs_tile.tscn"):
		ceiling_stairs_tile_scene = load("res://scenes/environment/ceiling_stairs_tile.tscn")
	if ResourceLoader.exists("res://scenes/environment/stairs_tile.tscn"):
		stairs_tile_scene = load("res://scenes/environment/stairs_tile.tscn")
	if ResourceLoader.exists("res://scenes/traps/base_trap.tscn"):
		base_trap_scene = load("res://scenes/traps/base_trap.tscn")

	active_corridors_container = get_node_or_null("ActiveCorridors")
	if not active_corridors_container:
		active_corridors_container = Node3D.new()
		active_corridors_container.name = "ActiveCorridors"
		add_child(active_corridors_container)

	player_ref = get_node_or_null("../Player")

	# Pre-generate initial dungeon buffer ahead so player never sees open void
	for i in range(5):
		generate_next_segment()

func _process(_delta: float) -> void:
	if not player_ref:
		player_ref = get_node_or_null("../Player")
		if not player_ref:
			return

	# Distance check to generate ahead of player with frame cap to prevent freezes
	var iterations = 0
	var max_iterations_per_frame = 5
	while iterations < max_iterations_per_frame and current_position.distance_to(player_ref.global_position) < (spawn_distance_ahead * 1.5):
		generate_next_segment()
		iterations += 1

	cleanup_passed_tiles()

func get_grid_key(pos: Vector3) -> Vector3i:
	return Vector3i(round(pos.x), round(pos.y), round(pos.z))

func spawn_floor_tile(tile_inst: Node3D, pos: Vector3, angle_deg: float) -> void:
	var snapped_pos = Vector3(round(pos.x), round(pos.y), round(pos.z))
	var key = get_grid_key(snapped_pos)
	tile_inst.position = snapped_pos
	tile_inst.rotation_degrees.y = angle_deg
	active_corridors_container.add_child(tile_inst)
	floor_grid[key] = tile_inst

	# Rule 2: Karo koyarken üstünde duvar varsa o duvarı yıksın (altındaki duvarı silmesin)
	if wall_grid.has(key):
		var existing_wall = wall_grid[key]
		if is_instance_valid(existing_wall):
			if existing_wall.position.y >= snapped_pos.y:
				existing_wall.queue_free()
				wall_grid.erase(key)

func try_spawn_wall_bottom_tile(wall_pos: Vector3, floor_y_pos: float, angle_deg: float) -> void:
	var key = get_grid_key(Vector3(wall_pos.x, floor_y_pos, wall_pos.z))

	# Rule 1: Duvar koyarken duvarın altında karo varsa o duvarı koymasın
	if floor_grid.has(key):
		var floor_node = floor_grid[key]
		if is_instance_valid(floor_node):
			return # Floor tile exists underneath, skip wall placement

	if not wall_bottom_tile_scene:
		return

	var snapped_wall_pos = Vector3(round(wall_pos.x), wall_pos.y, round(wall_pos.z))
	var wall_tile = wall_bottom_tile_scene.instantiate() as Node3D
	wall_tile.position = snapped_wall_pos
	wall_tile.rotation_degrees.y = angle_deg
	active_corridors_container.add_child(wall_tile)
	wall_grid[key] = wall_tile

# Spawns a full stacked wall column (bottom + mid layers + top) at the given position.
# active_wall_height (or wall_height_override) determines the total number of tiles:
#   height=3 → 1 bottom + 1 mid + 1 top
#   height=6 → 1 bottom + 4 mid + 1 top
# Each tile is 1m tall. The base pos (wall_pos.y) is the center of the bottom tile.
# Rule 1 is applied only to the bottom tile (the only tile that can overlap a floor tile).
# Mid and Top tiles are added as children of the bottom tile so deleting the bottom tile deletes the full column.
func try_spawn_wall_stacked(wall_pos: Vector3, floor_y_pos: float, angle_deg: float, wall_height_override: int = -1) -> void:
	# Rule 1: if there's a floor tile at this XZ, skip entire column
	var floor_key = get_grid_key(Vector3(wall_pos.x, floor_y_pos, wall_pos.z))
	if floor_grid.has(floor_key):
		var floor_node = floor_grid[floor_key]
		if is_instance_valid(floor_node):
			return

	var height = wall_height_override if wall_height_override > 0 else active_wall_height
	var snapped_x = round(wall_pos.x)
	var snapped_z = round(wall_pos.z)
	var base_y = wall_pos.y # Center of the bottom tile

	# Layer 0: Bottom tile (wall_bottom_tile_scene)
	if wall_bottom_tile_scene:
		var tile = wall_bottom_tile_scene.instantiate() as Node3D
		tile.position = Vector3(snapped_x, base_y, snapped_z)
		tile.rotation_degrees.y = angle_deg
		active_corridors_container.add_child(tile)
		wall_grid[floor_key] = tile

		# Layers 1 .. (height - 2): Mid tiles (parented to bottom tile)
		var mid_count = height - 2
		for i in range(mid_count):
			if not wall_mid_tile_scene:
				break
			var mid_tile = wall_mid_tile_scene.instantiate() as Node3D
			mid_tile.position = Vector3(0, float(i + 1), 0)
			tile.add_child(mid_tile)

		# Top layer: Top tile (parented to bottom tile)
		if wall_top_tile_scene:
			var top_tile = wall_top_tile_scene.instantiate() as Node3D
			top_tile.position = Vector3(0, float(height - 1), 0)
			tile.add_child(top_tile)


func get_next_turn_angle() -> int:
	if is_first_corridor:
		is_first_corridor = false
		last_relative_turn = 0
		return 0

	# Constraints:
	# -90 cannot be followed by +90
	# +90 cannot be followed by -90
	var choices: Array[int] = []
	if last_relative_turn == -90:
		choices = [-90, 0]
	elif last_relative_turn == 90:
		choices = [0, 90]
	else:
		choices = [-90, 0, 90]

	var selected_turn = choices[randi() % choices.size()]
	last_relative_turn = selected_turn
	return selected_turn

func generate_next_segment() -> void:
	# 1. Determine direction for new corridor
	var relative_turn = get_next_turn_angle()
	current_angle_deg = initial_angle_deg + relative_turn

	var rad = deg_to_rad(current_angle_deg)
	current_forward_dir = Vector3(-sin(rad), 0, -cos(rad)).normalized()
	
	var right_dir = Vector3(cos(rad), 0, -sin(rad)).normalized()

	if has_platform:
		current_position = last_platform_center + current_forward_dir * (float(last_platform_size) / 2.0 - 0.5)
		current_position = Vector3(round(current_position.x), round(current_position.y), round(current_position.z))
		has_platform = false

	var active_width = randi_range(min_corridor_width, max_corridor_width) | 1 # Force odd width so tile offsets always land on integers
	active_wall_height = randi_range(max(3, min_wall_height), max(3, max_wall_height)) # Minimum 3: 1 bottom + 1 mid + 1 top
	var effective_min_len = max(active_width, min_corridor_length)
	var max_len = max(effective_min_len, max_corridor_length)
	var corridor_length = randi_range(effective_min_len, max_len)
	var has_mid_stair = randf() < mid_stair_chance
	var mid_stair_index = int(float(corridor_length) / 2.0) if has_mid_stair else -1
	var mid_stair_dir = 1 if randf() > 0.5 else -1

	var start_segment_pos = current_position

	# 1b. Spawn back walls at start of segment (Rule 1 automatically skips if floor tile exists under it)
	var half_w = float(active_width) / 2.0
	for x_idx in range(active_width):
		var x_offset = (x_idx - half_w + 0.5)
		var back_wall_pos = start_segment_pos + right_dir * x_offset + Vector3(0, current_y + 0.5, 0)
		try_spawn_wall_stacked(back_wall_pos, current_y, current_angle_deg - 90.0)

	# 2. Generate corridor segment
	for i in range(corridor_length):
		current_position += current_forward_dir * 1.0
		current_position = Vector3(round(current_position.x), round(current_position.y), round(current_position.z))

		var step_y = current_y
		if has_mid_stair and i >= mid_stair_index:
			step_y += mid_stair_dir

		spawn_corridor_row(current_position, step_y, current_forward_dir, right_dir, current_angle_deg, i == mid_stair_index, active_width, mid_stair_dir)

	if has_mid_stair:
		current_y += mid_stair_dir

	# 3. Trap Spawning
	if randf() < trap_chance:
		var center_pos = start_segment_pos + current_forward_dir * (int(float(corridor_length) / 2.0) + 2.0)
		spawn_weighted_trap(center_pos, current_y, right_dir, current_angle_deg, corridor_length, active_width)

	# 4. End-of-Corridor Staircase & Square Landing Platform Check
	if randf() < end_stair_chance:
		generate_end_staircase(right_dir, active_width)
	else:
		build_landing_platform(right_dir, active_width)

func spawn_corridor_row(center_pos: Vector3, y_pos: float, fwd_dir: Vector3, right_dir: Vector3, angle_deg: float, is_stair_step: bool, active_width: int, stair_dir: int = 1) -> void:
	var half_w = float(active_width) / 2.0

	# 1. Floor or Stair tiles (Rule 2 applied inside spawn_floor_tile)
	var stair_wall_h = (active_wall_height + 1) if is_stair_step else active_wall_height

	for x_idx in range(active_width):
		var x_offset = (x_idx - half_w + 0.5)
		var tile_pos = center_pos + right_dir * x_offset + Vector3(0, y_pos, 0)
		var tile_angle = angle_deg

		var tile: Node3D
		if is_stair_step and stairs_tile_scene:
			tile = stairs_tile_scene.instantiate() as Node3D
			if stair_dir == -1:
				tile_pos.y += 1.0
				tile_angle += 180.0
		elif floor_tile_scene:
			tile = floor_tile_scene.instantiate() as Node3D
		else:
			tile = Node3D.new()

		spawn_floor_tile(tile, tile_pos, tile_angle)

		# 1b. Ceiling tiles — placed at top wall level (stair ceilings placed 1m lower to align with stairs)
		var is_using_stair_ceiling = is_stair_step and ceiling_stairs_tile_scene
		var ceiling_scene_to_use = ceiling_stairs_tile_scene if is_using_stair_ceiling else ceiling_tile_scene
		if ceiling_scene_to_use:
			var ceiling_inst = ceiling_scene_to_use.instantiate() as Node3D
			var ceiling_y_offset = -1.0 if is_using_stair_ceiling else 0.0
			ceiling_inst.position = Vector3(round(tile_pos.x), tile_pos.y + float(stair_wall_h) + ceiling_y_offset, round(tile_pos.z))
			ceiling_inst.rotation_degrees.y = tile_angle
			active_corridors_container.add_child(ceiling_inst)

	# 1c. Fill vertical gap in walls if ceiling height changed from previous row (triggered AFTER floor tiles & Rule 2)
	var curr_ceiling_y = y_pos + float(stair_wall_h)
	if last_ceiling_y > 0.0 and abs(last_ceiling_y - curr_ceiling_y) > 0.01:
		var min_c = min(last_ceiling_y, curr_ceiling_y)
		var max_c = max(last_ceiling_y, curr_ceiling_y)
		var gap_height = int(round(max_c - min_c))

		for x_idx in range(active_width):
			var x_offset = (x_idx - half_w + 0.5)
			var gap_pos = center_pos + right_dir * x_offset
			for h_idx in range(gap_height):
				var wall_y = min_c + float(h_idx) + 0.5
				var scene_to_use: PackedScene = null
				if h_idx == gap_height - 1 and wall_top_tile_scene:
					scene_to_use = wall_top_tile_scene
				elif wall_mid_tile_scene:
					scene_to_use = wall_mid_tile_scene
				elif wall_top_tile_scene:
					scene_to_use = wall_top_tile_scene

				if scene_to_use:
					var gap_wall = scene_to_use.instantiate() as Node3D
					gap_wall.position = Vector3(round(gap_pos.x), wall_y, round(gap_pos.z))
					gap_wall.rotation_degrees.y = angle_deg + 90.0
					active_corridors_container.add_child(gap_wall)

	last_ceiling_y = curr_ceiling_y

	# 2. Left and Right walls — stacked bottom+mid+top based on active_wall_height (Rule 1 applied per layer)
	var wall_y_offset: float = 0.5
	if is_stair_step and stair_dir == 1:
		wall_y_offset = -0.5

	var left_wall_pos = center_pos + right_dir * (-half_w - 0.5) + Vector3(0, y_pos + wall_y_offset, 0)
	try_spawn_wall_stacked(left_wall_pos, y_pos, angle_deg + 180.0, stair_wall_h)

	var right_wall_pos = center_pos + right_dir * (half_w + 0.5) + Vector3(0, y_pos + wall_y_offset, 0)
	try_spawn_wall_stacked(right_wall_pos, y_pos, angle_deg, stair_wall_h)

func generate_end_staircase(right_dir: Vector3, active_width: int) -> void:
	var stairs_length = randi_range(min_stairs_length, max_stairs_length)
	var stair_dir = 1 # End-of-corridor staircases always ascend upward

	# 1. Spawn staircase steps
	for step in range(stairs_length):
		current_position += current_forward_dir * 1.0
		current_position = Vector3(round(current_position.x), round(current_position.y), round(current_position.z))
		current_y += stair_dir
		spawn_corridor_row(current_position, current_y, current_forward_dir, right_dir, current_angle_deg, true, active_width, stair_dir)

	# 2. Build Square Landing Platform at end of staircase
	build_landing_platform(right_dir, active_width)

func build_landing_platform(right_dir: Vector3, active_width: int) -> void:
	# Build Square Landing Platform (size = active_width x active_width)
	var platform_start_pos = current_position
	for p_row in range(active_width):
		current_position += current_forward_dir * 1.0
		current_position = Vector3(round(current_position.x), round(current_position.y), round(current_position.z))
		spawn_corridor_row(current_position, current_y, current_forward_dir, right_dir, current_angle_deg, false, active_width)

	# Spawn Front Wall across the front edge of the landing platform (Rule 1 applied inside try_spawn_wall_stacked)
	var half_w = float(active_width) / 2.0
	for x_idx in range(active_width):
		var x_offset = (x_idx - half_w + 0.5)
		var front_wall_pos = current_position + current_forward_dir * 1.0 + right_dir * x_offset + Vector3(0, current_y + 0.5, 0)
		try_spawn_wall_stacked(front_wall_pos, current_y, current_angle_deg + 90.0)

	# Save platform center for next corridor positioning
	last_platform_center = platform_start_pos + current_forward_dir * (float(active_width) * 0.5)
	last_platform_center = Vector3(round(last_platform_center.x), round(last_platform_center.y), round(last_platform_center.z))
	last_platform_size = active_width
	has_platform = true

func spawn_weighted_trap(center_pos: Vector3, y_pos: float, right_dir: Vector3, angle_deg: float, corridor_len: float, active_width: int) -> void:
	if not base_trap_scene:
		return

	var total_weight = weight_option_a + weight_option_b + weight_option_c
	if total_weight <= 0.0:
		return

	var roll = randf_range(0.0, total_weight)
	var option_c = roll >= (weight_option_a + weight_option_b)
	var option_b = roll >= weight_option_a and not option_c

	var half_w = float(active_width) / 2.0
	var trap_len = clamp(randi_range(2, 4), 1, corridor_len)

	if option_c:
		# Option C: Full width trap + WallRunSurface Area3D on one wall extending +1m front & back
		var trap_inst = base_trap_scene.instantiate() as Node3D
		trap_inst.position = Vector3(round(center_pos.x), y_pos, round(center_pos.z))
		trap_inst.rotation_degrees.y = angle_deg
		active_corridors_container.add_child(trap_inst)

		# Create WallRunSurface (Area3D) along one wall (+1m front and back)
		var wall_side = -1.0 if randf() > 0.5 else 1.0
		var wr_surface = WallRunSurface.new()
		wr_surface.name = "WallRunSurfaceArea"
		var wr_pos = center_pos + right_dir * ((half_w + 0.4) * wall_side) + Vector3(0, y_pos + 1.2, 0)
		wr_surface.position = Vector3(round(wr_pos.x), wr_pos.y, round(wr_pos.z))
		wr_surface.rotation_degrees.y = angle_deg

		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.4, 2.4, float(trap_len) + 2.0)
		col.shape = box
		wr_surface.add_child(col)
		active_corridors_container.add_child(wr_surface)

	elif option_b and active_width >= 3:
		# Option B: 1-block gap on both sides
		var trap_inst = base_trap_scene.instantiate() as Node3D
		trap_inst.position = Vector3(round(center_pos.x), y_pos, round(center_pos.z))
		trap_inst.rotation_degrees.y = angle_deg
		active_corridors_container.add_child(trap_inst)

	else:
		# Option A: 1-block gap on left or right
		var offset_side = (half_w - 0.5) * (1.0 if randf() > 0.5 else -1.0)
		var trap_pos = center_pos + right_dir * offset_side + Vector3(0.0, y_pos + 0.2, 0.0)
		var trap_inst = base_trap_scene.instantiate() as Node3D
		trap_inst.position = Vector3(round(trap_pos.x), y_pos, round(trap_pos.z))
		trap_inst.rotation_degrees.y = angle_deg
		active_corridors_container.add_child(trap_inst)

func cleanup_passed_tiles() -> void:
	if not active_corridors_container or not player_ref:
		return

	var player_pos = player_ref.global_position

	# Clean up despawned nodes from dictionaries
	var floor_keys = floor_grid.keys()
	for k in floor_keys:
		var node = floor_grid[k]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			floor_grid.erase(k)

	var wall_keys = wall_grid.keys()
	for k in wall_keys:
		var node = wall_grid[k]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			wall_grid.erase(k)

	for child in active_corridors_container.get_children():
		if child is Node3D:
			if child.global_position.distance_to(player_pos) > despawn_distance_behind:
				var to_child = (child.global_position - player_pos).normalized()
				if to_child.dot(initial_forward_dir) < -0.2:
					child.queue_free()
