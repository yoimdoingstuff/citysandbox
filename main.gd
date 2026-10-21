extends Node3D

const TERRAIN_RES: int = 81
const TERRAIN_SIZE: float = 82.0
const MAX_CITIES: int = 10
const MAX_PEOPLE: int = 500
const WATER_LEVEL: float = -0.15

var terrain: MeshInstance3D
var terrain_material: StandardMaterial3D
var selection_ring: MeshInstance3D
var terrain_heights: Array = []
var city_names: Array[String] = ["Asterfall", "Mossreach", "Copper Bay", "New Avalon", "Westhaven", "Emberplain", "Stonebridge", "Northstar", "Rivermark", "Sunfield"]
var city_colors: Array[Color] = [
	Color(0.17, 0.67, 0.93), Color(0.94, 0.48, 0.18), Color(0.62, 0.42, 0.88),
	Color(0.22, 0.76, 0.48), Color(0.91, 0.32, 0.40), Color(0.91, 0.76, 0.22),
	Color(0.24, 0.55, 0.91), Color(0.86, 0.43, 0.70), Color(0.42, 0.78, 0.77), Color(0.72, 0.72, 0.75)
]
var cities: Array = []
var people: Array = []
var resources: Array = []
var armies: Array = []
var missiles: Array = []
var explosions: Array = []
var god_effects: Array = []
var fire_zones: Array = []
var falling_meteors: Array = []
var tornadoes: Array = []
var wars: Array = []
var log_entries: Array[String] = []

var selected_city: int = -1
var controlled_city: int = -1
var tool_mode: String = "select"
var pending_action: String = ""
var brush_radius: float = 4.0
var paused: bool = false
var sim_speed: float = 1.0
var game_clock: float = 0.0
var growth_timer: float = 0.0
var resource_timer: float = 0.0
var founding_timer: float = 0.0
var auto_war_timer: float = 24.0
var ui_timer: float = 0.0

var camera: Camera3D
var camera_target: Vector3 = Vector3.ZERO
var camera_yaw: float = -0.72
var camera_pitch: float = 0.56
var camera_distance: float = 94.0
var rotating_camera: bool = false
var panning_camera: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO
var last_paint_position: Vector3 = Vector3.ZERO
var last_paint_valid: bool = false
var brush_preview: MeshInstance3D
var brush_preview_mesh: TorusMesh
var brush_preview_material: StandardMaterial3D
var preview_timer: float = 0.0

var ui_root: Control
var stats_label: Label
var city_info_label: Label
var tool_label: Label
var pending_label: Label
var radius_label: Label
var log_label: Label
var pause_button: Button
var speed_button: Button
var control_button: Button
var tool_buttons: Dictionary = {}


func _ready() -> void:
	randomize()
	_build_world()
	_build_ui()
	_seed_civilizations()
	_set_tool("select")
	_log("The world is alive. Select a city to inspect it, then take control to issue orders.")
	_log("Tip: spawn humans in a cluster and they can found a new settlement on their own.")
	_refresh_ui()


func _process(delta: float) -> void:
	_update_camera_input(delta)
	preview_timer += delta
	if preview_timer >= 0.10:
		preview_timer = 0.0
		_update_brush_preview()
	var sim_delta: float = 0.0
	if not paused:
		sim_delta = delta * sim_speed
		game_clock += sim_delta
		_update_people(sim_delta)
		_update_armies(sim_delta)
		_update_missiles(sim_delta)
		_update_explosions(sim_delta)
		_update_god_effects(sim_delta)
		_update_fire_zones(sim_delta)
		_update_falling_meteors(sim_delta)
		_update_tornadoes(sim_delta)
		_update_plague(sim_delta)
		_update_simulation_timers(sim_delta)
	ui_timer += delta
	if ui_timer >= 0.35:
		ui_timer = 0.0
		_refresh_ui()


func _build_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.43, 0.66, 0.81)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.80, 0.91)
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(180.0, 180.0)
	water.mesh = water_mesh
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.08, 0.35, 0.58)
	water_material.roughness = 0.34
	water_material.metallic = 0.12
	water.material_override = water_material
	water.position.y = WATER_LEVEL
	add_child(water)

	_generate_terrain_heights()
	terrain_material = StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.92
	terrain = MeshInstance3D.new()
	terrain.name = "ProceduralIsland"
	terrain.material_override = terrain_material
	add_child(terrain)
	_rebuild_terrain()

	camera = Camera3D.new()
	camera.name = "SandboxCamera"
	camera.current = true
	camera.far = 450.0
	camera.near = 0.1
	add_child(camera)
	selection_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.outer_radius = 4.2
	ring_mesh.inner_radius = 3.92
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 48
	selection_ring.mesh = ring_mesh
	selection_ring.material_override = _material(Color(0.36, 0.92, 1.0), 0.35)
	selection_ring.visible = false
	add_child(selection_ring)

	brush_preview = MeshInstance3D.new()
	brush_preview.name = "GodPowerBrushPreview"
	brush_preview_mesh = TorusMesh.new()
	brush_preview_mesh.outer_radius = 1.0
	brush_preview_mesh.inner_radius = 0.94
	brush_preview_mesh.rings = 6
	brush_preview_mesh.ring_segments = 48
	brush_preview.mesh = brush_preview_mesh
	brush_preview_material = StandardMaterial3D.new()
	brush_preview_material.albedo_color = Color(0.28, 0.86, 1.0, 0.80)
	brush_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	brush_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brush_preview_material.emission_enabled = true
	brush_preview_material.emission = Color(0.15, 0.58, 0.88)
	brush_preview.material_override = brush_preview_material
	brush_preview.visible = false
	add_child(brush_preview)
	_update_camera()


func _generate_terrain_heights() -> void:
	terrain_heights.clear()
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 14029
	broad_noise.frequency = 0.043
	broad_noise.fractal_octaves = 3
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 8201
	detail_noise.frequency = 0.12
	for z_index in range(TERRAIN_RES):
		var row: Array = []
		for x_index in range(TERRAIN_RES):
			var x: float = (float(x_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
			var z: float = (float(z_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
			var edge: float = max(abs(x), abs(z)) / (TERRAIN_SIZE * 0.5)
			var falloff: float = clamp(1.0 - pow(edge, 2.3), 0.0, 1.0)
			var h: float = falloff * (4.5 + broad_noise.get_noise_2d(x, z) * 2.25 + detail_noise.get_noise_2d(x, z) * 0.6) - 1.35
			row.append(h)
		terrain_heights.append(row)


func _rebuild_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spacing: float = TERRAIN_SIZE / float(TERRAIN_RES - 1)
	for z_index in range(TERRAIN_RES - 1):
		for x_index in range(TERRAIN_RES - 1):
			var x0: float = -TERRAIN_SIZE * 0.5 + float(x_index) * spacing
			var x1: float = x0 + spacing
			var z0: float = -TERRAIN_SIZE * 0.5 + float(z_index) * spacing
			var z1: float = z0 + spacing
			var p00 := Vector3(x0, terrain_heights[z_index][x_index], z0)
			var p10 := Vector3(x1, terrain_heights[z_index][x_index + 1], z0)
			var p01 := Vector3(x0, terrain_heights[z_index + 1][x_index], z1)
			var p11 := Vector3(x1, terrain_heights[z_index + 1][x_index + 1], z1)
			_add_terrain_vertex(surface, p00)
			_add_terrain_vertex(surface, p01)
			_add_terrain_vertex(surface, p10)
			_add_terrain_vertex(surface, p10)
			_add_terrain_vertex(surface, p01)
			_add_terrain_vertex(surface, p11)
	surface.index()
	surface.generate_normals()
	terrain.mesh = surface.commit()


func _add_terrain_vertex(surface: SurfaceTool, p: Vector3) -> void:
	surface.set_color(_terrain_color(p.y))
	surface.add_vertex(p)


func _terrain_color(height: float) -> Color:
	if height < WATER_LEVEL + 0.5:
		return Color(0.67, 0.61, 0.42)
	if height > 4.6:
		return Color(0.49, 0.51, 0.48)
	if height > 3.2:
		return Color(0.35, 0.51, 0.31)
	return Color(0.24, 0.48, 0.23)


func _height_at(x: float, z: float) -> float:
	var gx: float = clamp((x / TERRAIN_SIZE + 0.5) * float(TERRAIN_RES - 1), 0.0, float(TERRAIN_RES - 1))
	var gz: float = clamp((z / TERRAIN_SIZE + 0.5) * float(TERRAIN_RES - 1), 0.0, float(TERRAIN_RES - 1))
	var x0: int = int(floor(gx))
	var z0: int = int(floor(gz))
	var x1: int = min(x0 + 1, TERRAIN_RES - 1)
	var z1: int = min(z0 + 1, TERRAIN_RES - 1)
	var tx: float = gx - float(x0)
	var tz: float = gz - float(z0)
	var h00: float = terrain_heights[z0][x0]
	var h10: float = terrain_heights[z0][x1]
	var h01: float = terrain_heights[z1][x0]
	var h11: float = terrain_heights[z1][x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _surface_position(x: float, z: float) -> Vector3:
	return Vector3(x, _height_at(x, z), z)


func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	var horizontal: float = camera_distance * cos(camera_pitch)
	var vertical: float = camera_distance * sin(camera_pitch)
	camera.global_position = camera_target + Vector3(cos(camera_yaw) * horizontal, vertical, sin(camera_yaw) * horizontal)
	camera.look_at(camera_target, Vector3.UP)


func _update_camera_input(delta: float) -> void:
	var forward := Vector3(-cos(camera_yaw), 0.0, -sin(camera_yaw))
	var right := Vector3(-forward.z, 0.0, forward.x)
	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement -= right
	if movement.length_squared() > 0.0:
		camera_target += movement.normalized() * delta * max(12.0, camera_distance * 0.30)
		camera_target.x = clamp(camera_target.x, -28.0, 28.0)
		camera_target.z = clamp(camera_target.z, -28.0, 28.0)
		_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			rotating_camera = mouse_event.pressed
			last_mouse_position = mouse_event.position
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			panning_camera = mouse_event.pressed
			last_mouse_position = mouse_event.position
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			camera_distance = clamp(camera_distance - 6.0, 24.0, 145.0)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			camera_distance = clamp(camera_distance + 6.0, 24.0, 145.0)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_world_click(mouse_event.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if rotating_camera:
			camera_yaw += motion.relative.x * 0.006
			camera_pitch = clamp(camera_pitch + motion.relative.y * 0.004, 0.20, 1.25)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif panning_camera:
			var drag_scale: float = camera_distance * 0.0019
			var camera_right := Vector3(sin(camera_yaw), 0.0, -cos(camera_yaw))
			var camera_back := Vector3(cos(camera_yaw), 0.0, sin(camera_yaw))
			# Pan like grabbing the world: terrain follows the mouse instead of sliding the wrong way.
			camera_target += -camera_right * motion.relative.x * drag_scale - camera_back * motion.relative.y * drag_scale
			camera_target.x = clamp(camera_target.x, -32.0, 32.0)
			camera_target.z = clamp(camera_target.z, -32.0, 32.0)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _is_paint_tool():
			var paint_position: Vector3 = _get_ground_position(motion.position)
			if abs(paint_position.x) <= TERRAIN_SIZE * 0.5 and abs(paint_position.z) <= TERRAIN_SIZE * 0.5:
				var spacing: float = max(0.85, brush_radius * 0.24)
				if not last_paint_valid or Vector2(paint_position.x - last_paint_position.x, paint_position.z - last_paint_position.z).length() >= spacing:
					last_paint_position = paint_position
					last_paint_valid = true
					_apply_brush_tool(paint_position)
					get_viewport().set_input_as_handled()


func _on_world_click(screen_position: Vector2) -> void:
	var world_position: Vector3 = _get_ground_position(screen_position)
	if abs(world_position.x) > TERRAIN_SIZE * 0.5 or abs(world_position.z) > TERRAIN_SIZE * 0.5:
		return
	last_paint_position = world_position
	last_paint_valid = true
	if pending_action != "":
		var target_id: int = _find_city_at(world_position, 5.5)
		if target_id < 0:
			_log("Choose a target city. Click close to its town centre.")
			return
		if controlled_city < 0 or controlled_city >= cities.size():
			_log("Take control of a city before issuing orders.")
			pending_action = ""
			return
		if target_id == controlled_city and pending_action != "missile":
			_log("That city cannot invade itself.")
			pending_action = ""
			return
		match pending_action:
			"missile":
				_launch_missile(controlled_city, target_id)
			"army":
				_launch_army(controlled_city, target_id, false)
			"peace":
				_make_peace(controlled_city, target_id)
		pending_action = ""
		return

	_apply_world_tool(world_position)


func _get_ground_position(screen_position: Vector2) -> Vector3:
	# Intersect the actual height field. Intersecting y=0 and then swapping in
	# the terrain height gives the wrong x/z position on every hill.
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	if abs(ray_direction.y) < 0.0001:
		return Vector3(1000.0, 0.0, 1000.0)

	var half_size: float = TERRAIN_SIZE * 0.5
	var step_size: float = 0.4
	var previous_t: float = 0.0
	var previous_difference: float = 0.0
	var was_inside: bool = false
	for step_index in range(1, 751):
		var ray_t: float = float(step_index) * step_size
		var point: Vector3 = ray_origin + ray_direction * ray_t
		if abs(point.x) > half_size or abs(point.z) > half_size:
			was_inside = false
			continue
		var difference: float = point.y - _height_at(point.x, point.z)
		if was_inside and previous_difference > 0.0 and difference <= 0.0:
			var low_t: float = previous_t
			var high_t: float = ray_t
			for refine_index in range(12):
				var middle_t: float = (low_t + high_t) * 0.5
				var middle_point: Vector3 = ray_origin + ray_direction * middle_t
				if middle_point.y > _height_at(middle_point.x, middle_point.z):
					low_t = middle_t
				else:
					high_t = middle_t
			var hit: Vector3 = ray_origin + ray_direction * ((low_t + high_t) * 0.5)
			hit.y = _height_at(hit.x, hit.z)
			return hit
		previous_t = ray_t
		previous_difference = difference
		was_inside = true
	return Vector3(1000.0, 0.0, 1000.0)


func _is_paint_tool() -> bool:
	return tool_mode in ["raise", "lower", "human", "tree", "stone", "food", "erase"]


func _apply_brush_tool(world_position: Vector3) -> void:
	match tool_mode:
		"raise":
			_sculpt_terrain(world_position, 0.72)
		"lower":
			_sculpt_terrain(world_position, -0.72)
		"human":
			if people.size() < MAX_PEOPLE:
				_spawn_human(world_position, -1)
			else:
				_log("Population cap reached for this prototype.")
		"tree":
			_spawn_resource(world_position, "tree", 8)
		"stone":
			_spawn_resource(world_position, "stone", 8)
		"food":
			_spawn_resource(world_position, "food", 8)
		"erase":
			_erase_near(world_position)


func _apply_world_tool(world_position: Vector3) -> void:
	match tool_mode:
		"select":
			var city_id: int = _find_city_at(world_position, 5.5)
			if city_id >= 0:
				selected_city = city_id
				_log("Selected %s. Take control to issue orders." % cities[city_id]["name"])
			else:
				selected_city = -1
		"raise", "lower", "human", "tree", "stone", "food", "erase":
			_apply_brush_tool(world_position)
		"lightning":
			_god_lightning(world_position)
		"fire":
			_god_fire(world_position)
		"meteor":
			_god_meteor(world_position)
		"tornado":
			_god_tornado(world_position)
		"plague":
			_god_plague(world_position)
		"heal":
			_god_heal(world_position)
		"forest":
			_god_forest(world_position)
		"quake":
			_god_earthquake(world_position)


func _find_city_at(point: Vector3, radius: float) -> int:
	var best_id: int = -1
	var best_distance: float = radius
	for i in range(cities.size()):
		var city_position: Vector3 = cities[i]["pos"]
		var distance: float = Vector2(point.x, point.z).distance_to(Vector2(city_position.x, city_position.z))
		if distance < best_distance:
			best_distance = distance
			best_id = i
	return best_id


func _sculpt_terrain(center: Vector3, amount: float) -> void:
	var spacing: float = TERRAIN_SIZE / float(TERRAIN_RES - 1)
	for z_index in range(TERRAIN_RES):
		for x_index in range(TERRAIN_RES):
			var x: float = -TERRAIN_SIZE * 0.5 + float(x_index) * spacing
			var z: float = -TERRAIN_SIZE * 0.5 + float(z_index) * spacing
			var distance: float = Vector2(x - center.x, z - center.z).length()
			if distance <= brush_radius:
				var strength: float = 1.0 - distance / brush_radius
				var h: float = terrain_heights[z_index][x_index]
				terrain_heights[z_index][x_index] = clamp(h + amount * strength, -4.5, 10.0)
	_rebuild_terrain()
	_update_placed_object_heights()
	_log("Terrain %s." % ("raised" if amount > 0.0 else "lowered"))


func _update_placed_object_heights() -> void:
	for person in people:
		var p: Vector3 = person["pos"]
		p.y = _height_at(p.x, p.z)
		person["pos"] = p
		if is_instance_valid(person["node"]):
			person["node"].position = p
	for resource in resources:
		var p: Vector3 = resource["pos"]
		p.y = _height_at(p.x, p.z)
		resource["pos"] = p
		if is_instance_valid(resource["node"]):
			resource["node"].position = p
	for city in cities:
		var p: Vector3 = city["pos"]
		p.y = _height_at(p.x, p.z)
		city["pos"] = p
		if is_instance_valid(city["node"]):
			city["node"].position = p
		for house in city["houses"]:
			if is_instance_valid(house):
				house.position.y = _height_at(p.x + house.position.x, p.z + house.position.z) - p.y
	for army in armies:
		var p: Vector3 = army["pos"]
		p.y = _height_at(p.x, p.z)
		army["pos"] = p
		if is_instance_valid(army["node"]):
			army["node"].position = p


func _seed_civilizations() -> void:
	var starts: Array[Vector2] = [Vector2(-21.0, -17.0), Vector2(20.0, -16.0), Vector2(1.0, 22.0)]
	var populations: Array[int] = [6, 5, 5]
	for i in range(starts.size()):
		var town_position: Vector3 = _surface_position(starts[i].x, starts[i].y)
		var city_id: int = _create_city(town_position, city_names[i], city_colors[i])
		for person_index in range(populations[i]):
			var angle: float = float(person_index) * 2.39996
			var radius: float = 1.4 + float(person_index % 3) * 0.7
			var human_position: Vector3 = _surface_position(town_position.x + cos(angle) * radius, town_position.z + sin(angle) * radius)
			_spawn_human(human_position, city_id)
		_seed_resources_around(town_position)
		cities[city_id]["food"] = 14.0
		cities[city_id]["wood"] = 10.0
		cities[city_id]["stone"] = 5.0
		_sync_city_buildings(city_id)
	_log("Three small city-states are competing to grow. Their future is, regrettably, in your hands.")


func _create_city(position: Vector3, city_name: String, color: Color) -> int:
	var index: int = cities.size()
	var town := Node3D.new()
	town.name = "City_%s" % city_name.replace(" ", "")
	town.position = position
	add_child(town)

	var plinth_mesh := BoxMesh.new()
	plinth_mesh.size = Vector3(3.2, 0.45, 3.2)
	var plinth := _add_mesh(town, plinth_mesh, _material(Color(0.34, 0.34, 0.31)), Vector3(0.0, 0.22, 0.0))
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.15, 1.9, 2.15)
	var body := _add_mesh(town, body_mesh, _material(color.darkened(0.25)), Vector3(0.0, 1.25, 0.0))
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 1.65
	roof_mesh.height = 1.35
	roof_mesh.radial_segments = 5
	var roof := _add_mesh(town, roof_mesh, _material(color.lightened(0.12)), Vector3(0.0, 2.85, 0.0))

	var flag_pole_mesh := CylinderMesh.new()
	flag_pole_mesh.top_radius = 0.045
	flag_pole_mesh.bottom_radius = 0.045
	flag_pole_mesh.height = 2.8
	_add_mesh(town, flag_pole_mesh, _material(Color(0.82, 0.82, 0.73)), Vector3(0.0, 4.6, 0.0))
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.9, 0.45, 0.08)
	_add_mesh(town, flag_mesh, _material(color), Vector3(0.42, 5.55, 0.0))

	var city_label := Label3D.new()
	city_label.text = "%s\nPOP 0" % city_name
	city_label.position = Vector3(0.0, 6.5, 0.0)
	city_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	city_label.font_size = 46
	city_label.pixel_size = 0.012
	city_label.outline_size = 8
	city_label.modulate = Color(1.0, 1.0, 1.0)
	town.add_child(city_label)

	cities.append({
		"name": city_name,
		"pos": position,
		"color": color,
		"node": town,
		"label": city_label,
		"body": body,
		"roof": roof,
		"houses": [],
		"owner": index,
		"food": 8.0,
		"wood": 5.0,
		"stone": 3.0
	})
	return index


func _sync_city_buildings(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var population: int = _city_population(city_id)
	var desired_houses: int = max(1, 1 + int(population / 4))
	var houses: Array = city["houses"]
	while houses.size() < desired_houses and houses.size() < 18:
		var house_index: int = houses.size()
		var angle: float = float(house_index) * 2.39996
		var ring: float = 4.0 + float(house_index / 6) * 2.5
		var offset_x: float = cos(angle) * ring
		var offset_z: float = sin(angle) * ring
		var terrain_delta: float = _height_at(city["pos"].x + offset_x, city["pos"].z + offset_z) - city["pos"].y
		var house := Node3D.new()
		house.position = Vector3(offset_x, terrain_delta, offset_z)
		city["node"].add_child(house)
		var wall_color: Color = Color(0.70, 0.64, 0.48).lerp(city["color"], 0.24)
		var walls := BoxMesh.new()
		walls.size = Vector3(1.35, 1.2, 1.35)
		_add_mesh(house, walls, _material(wall_color), Vector3(0.0, 0.65, 0.0))
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = 1.02
		roof.height = 0.88
		roof.radial_segments = 4
		_add_mesh(house, roof, _material(city["color"].darkened(0.10)), Vector3(0.0, 1.62, 0.0))
		houses.append(house)
	city["houses"] = houses


func _seed_resources_around(center: Vector3) -> void:
	for i in range(15):
		var angle: float = randf() * TAU
		var radius: float = randf_range(7.0, 14.0)
		var p: Vector3 = _surface_position(center.x + cos(angle) * radius, center.z + sin(angle) * radius)
		var roll: float = randf()
		if roll < 0.48:
			_spawn_resource(p, "tree", 8)
		elif roll < 0.73:
			_spawn_resource(p, "food", 8)
		else:
			_spawn_resource(p, "stone", 8)


func _spawn_human(position: Vector3, city_id: int) -> void:
	if people.size() >= MAX_PEOPLE:
		return
	var assigned_city: int = city_id
	if assigned_city < 0:
		var nearest_distance: float = 8.0
		for i in range(cities.size()):
			var city_pos: Vector3 = cities[i]["pos"]
			var distance: float = Vector2(position.x, position.z).distance_to(Vector2(city_pos.x, city_pos.z))
			if distance < nearest_distance:
				nearest_distance = distance
				assigned_city = i
	var garment: Color = Color(0.60, 0.64, 0.69)
	if assigned_city >= 0 and assigned_city < cities.size():
		garment = cities[assigned_city]["color"].lightened(0.08)
	else:
		garment = city_colors[randi_range(0, city_colors.size() - 1)].darkened(0.12)
	var human := Node3D.new()
	human.name = "Human"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.22
	body_mesh.height = 0.96
	_add_mesh(human, body_mesh, _material(garment), Vector3(0.0, 0.70, 0.0))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	_add_mesh(human, head_mesh, _material(Color(0.88, 0.70, 0.53)), Vector3(0.0, 1.30, 0.0))
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.225
	hair_mesh.height = 0.21
	_add_mesh(human, hair_mesh, _material(Color(0.22, 0.17, 0.13)), Vector3(0.0, 1.44, 0.01))
	var infection_marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.13
	marker_mesh.height = 0.26
	infection_marker.mesh = marker_mesh
	infection_marker.position = Vector3(0.0, 1.75, 0.0)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.52, 1.0, 0.28)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.35, 1.0, 0.15)
	marker_material.emission_energy_multiplier = 1.3
	infection_marker.material_override = marker_material
	infection_marker.visible = false
	human.add_child(infection_marker)
	add_child(human)
	var p: Vector3 = position
	p.y = _height_at(p.x, p.z)
	human.position = p
	people.append({
		"node": human,
		"pos": p,
		"city_id": assigned_city,
		"target": p,
		"walk_timer": randf_range(0.4, 2.2),
		"alive": true,
		"infected": false,
		"infection_marker": infection_marker,
		"infection_time": 0.0,
		"spread_timer": randf_range(0.5, 1.5)
	})


func _spawn_resource(position: Vector3, kind: String, amount: int = 8) -> void:
	var node := Node3D.new()
	node.name = "Resource_%s" % kind
	var p: Vector3 = position
	p.y = _height_at(p.x, p.z)
	node.position = p
	if kind == "tree":
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.16
		trunk.bottom_radius = 0.24
		trunk.height = 1.35
		_add_mesh(node, trunk, _material(Color(0.36, 0.22, 0.12)), Vector3(0.0, 0.68, 0.0))
		var leaves := SphereMesh.new()
		leaves.radius = 0.82
		leaves.height = 1.55
		_add_mesh(node, leaves, _material(Color(0.12, randf_range(0.38, 0.55), 0.19)), Vector3(0.0, 1.75, 0.0), Vector3(1.0, 1.15, 1.0))
	elif kind == "stone":
		var rock := SphereMesh.new()
		rock.radius = 0.72
		rock.height = 0.95
		_add_mesh(node, rock, _material(Color(0.46, 0.49, 0.51)), Vector3(0.0, 0.48, 0.0), Vector3(1.15, 0.85, 0.95))
		var rock2 := SphereMesh.new()
		rock2.radius = 0.42
		rock2.height = 0.7
		_add_mesh(node, rock2, _material(Color(0.58, 0.60, 0.61)), Vector3(0.55, 0.42, 0.22))
	else:
		var patch := CylinderMesh.new()
		patch.top_radius = 0.66
		patch.bottom_radius = 0.82
		patch.height = 0.28
		_add_mesh(node, patch, _material(Color(0.18, 0.48, 0.18)), Vector3(0.0, 0.14, 0.0))
		for berry_index in range(5):
			var berry := SphereMesh.new()
			berry.radius = 0.17
			berry.height = 0.26
			var angle: float = float(berry_index) * TAU / 5.0
			_add_mesh(node, berry, _material(Color(0.86, 0.20, 0.18)), Vector3(cos(angle) * 0.42, 0.38, sin(angle) * 0.42))
	add_child(node)
	resources.append({"node": node, "pos": p, "type": kind, "amount": amount, "alive": true})


func _material(color: Color, roughness: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, local_position: Vector3 = Vector3.ZERO, local_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.scale = local_scale
	parent.add_child(instance)
	return instance


func _update_people(delta: float) -> void:
	for i in range(people.size()):
		var person: Dictionary = people[i]
		var position: Vector3 = person["pos"]
		person["walk_timer"] -= delta
		if person["walk_timer"] <= 0.0 or Vector2(position.x - person["target"].x, position.z - person["target"].z).length() < 0.45:
			var destination_center: Vector3 = position
			var city_id: int = int(person["city_id"])
			if city_id >= 0 and city_id < cities.size():
				destination_center = cities[city_id]["pos"]
			var angle: float = randf() * TAU
			var radius: float = randf_range(1.5, 6.5) if city_id >= 0 else randf_range(1.0, 5.0)
			var target_x: float = clamp(destination_center.x + cos(angle) * radius, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			var target_z: float = clamp(destination_center.z + sin(angle) * radius, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			person["target"] = _surface_position(target_x, target_z)
			person["walk_timer"] = randf_range(1.2, 3.8)
		var target: Vector3 = person["target"]
		var horizontal_target := Vector3(target.x, position.y, target.z)
		position = position.move_toward(horizontal_target, delta * randf_range(0.8, 1.35))
		position.y = _height_at(position.x, position.z)
		person["pos"] = position
		if is_instance_valid(person["node"]):
			person["node"].position = position
		people[i] = person


func _update_simulation_timers(delta: float) -> void:
	growth_timer += delta
	resource_timer += delta
	founding_timer += delta
	auto_war_timer += delta
	if resource_timer >= 4.0:
		resource_timer = 0.0
		_collect_resources()
	if growth_timer >= 9.0:
		growth_timer = 0.0
		_grow_cities()
	if founding_timer >= 4.0:
		founding_timer = 0.0
		_assign_wild_people()
		_try_found_cities()
	if auto_war_timer >= 31.0:
		auto_war_timer = 0.0
		_try_start_ai_war()


func _city_population(city_id: int) -> int:
	var total: int = 0
	for person in people:
		if int(person["city_id"]) == city_id:
			total += 1
	return total


func _collect_resources() -> void:
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		for resource in resources:
			if int(resource["amount"]) <= 0:
				continue
			var resource_pos: Vector3 = resource["pos"]
			var city_pos: Vector3 = city["pos"]
			var distance: float = Vector2(resource_pos.x - city_pos.x, resource_pos.z - city_pos.z).length()
			if distance > 15.0:
				continue
			var kind: String = resource["type"]
			if kind == "food" and float(city["food"]) < 32.0:
				city["food"] = float(city["food"]) + 2.5
				resource["amount"] = int(resource["amount"]) - 1
			elif kind == "tree" and float(city["wood"]) < 28.0:
				city["wood"] = float(city["wood"]) + 1.6
				resource["amount"] = int(resource["amount"]) - 1
			elif kind == "stone" and float(city["stone"]) < 22.0:
				city["stone"] = float(city["stone"]) + 1.3
				resource["amount"] = int(resource["amount"]) - 1
			if int(resource["amount"]) <= 0:
				resource["alive"] = false
				if is_instance_valid(resource["node"]):
					resource["node"].visible = false
			cities[city_id] = city


func _grow_cities() -> void:
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var population: int = _city_population(city_id)
		if population > 0 and population < 55 and float(city["food"]) >= 1.0 and people.size() < MAX_PEOPLE:
			city["food"] = max(0.0, float(city["food"]) - 1.0)
			if float(city["wood"]) > 0.2:
				city["wood"] = max(0.0, float(city["wood"]) - 0.2)
				var angle: float = randf() * TAU
				var spawn_pos: Vector3 = _surface_position(city["pos"].x + cos(angle) * 2.2, city["pos"].z + sin(angle) * 2.2)
				_spawn_human(spawn_pos, city_id)
				_log("%s grew to %d citizens." % [city["name"], population + 1])
			_sync_city_buildings(city_id)
		city["population"] = _city_population(city_id)
		if is_instance_valid(city["label"]):
			city["label"].text = "%s\nPOP %d" % [city["name"], int(city["population"])]
		cities[city_id] = city


func _assign_wild_people() -> void:
	for i in range(people.size()):
		var person: Dictionary = people[i]
		if int(person["city_id"]) >= 0:
			continue
		var position: Vector3 = person["pos"]
		var closest: int = -1
		var closest_distance: float = 7.5
		for city_id in range(cities.size()):
			var city_position: Vector3 = cities[city_id]["pos"]
			var distance: float = Vector2(position.x - city_position.x, position.z - city_position.z).length()
			if distance < closest_distance:
				closest_distance = distance
				closest = city_id
		if closest >= 0:
			person["city_id"] = closest
			people[i] = person


func _try_found_cities() -> void:
	if cities.size() >= MAX_CITIES or people.size() < 4:
		return
	for i in range(people.size()):
		if int(people[i]["city_id"]) >= 0:
			continue
		var members: Array[int] = []
		var anchor: Vector3 = people[i]["pos"]
		for j in range(people.size()):
			if int(people[j]["city_id"]) >= 0:
				continue
			var candidate: Vector3 = people[j]["pos"]
			if Vector2(anchor.x - candidate.x, anchor.z - candidate.z).length() < 8.0:
				members.append(j)
		if members.size() >= 4:
			var center_x: float = 0.0
			var center_z: float = 0.0
			for member_id in members:
				center_x += people[member_id]["pos"].x
				center_z += people[member_id]["pos"].z
			center_x /= float(members.size())
			center_z /= float(members.size())
			var new_id: int = cities.size()
			var new_name: String = city_names[new_id % city_names.size()]
			var new_color: Color = city_colors[new_id % city_colors.size()]
			var new_city_id: int = _create_city(_surface_position(center_x, center_z), new_name, new_color)
			cities[new_city_id]["food"] = 9.0
			cities[new_city_id]["wood"] = 6.0
			cities[new_city_id]["stone"] = 3.0
			for member_id in members:
				people[member_id]["city_id"] = new_city_id
			_sync_city_buildings(new_city_id)
			_seed_resources_around(cities[new_city_id]["pos"])
			_log("A new settlement, %s, has been founded by %d humans." % [new_name, members.size()])
			return


func _try_start_ai_war() -> void:
	if cities.size() < 2:
		return
	for attempt in range(12):
		var source: int = randi_range(0, cities.size() - 1)
		var target: int = randi_range(0, cities.size() - 1)
		if source == target or _same_faction(source, target) or _are_at_war(source, target):
			continue
		if randf() < 0.58:
			_launch_army(source, target, true)
		else:
			_log("Scouts report rising tensions between %s and %s." % [cities[source]["name"], cities[target]["name"]])
		return


func _same_faction(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= cities.size() or b >= cities.size():
		return false
	return int(cities[a]["owner"]) == int(cities[b]["owner"])


func _are_at_war(a: int, b: int) -> bool:
	for war in wars:
		if (int(war["a"]) == a and int(war["b"]) == b) or (int(war["a"]) == b and int(war["b"]) == a):
			return true
	return false


func _declare_war(a: int, b: int) -> void:
	if not _are_at_war(a, b):
		wars.append({"a": a, "b": b})
		_log("WAR: %s vs %s." % [cities[a]["name"], cities[b]["name"]])


func _make_peace(a: int, b: int) -> void:
	var remaining: Array = []
	for war in wars:
		if not ((int(war["a"]) == a and int(war["b"]) == b) or (int(war["a"]) == b and int(war["b"]) == a)):
			remaining.append(war)
	wars = remaining
	_log("A ceasefire was declared between %s and %s." % [cities[a]["name"], cities[b]["name"]])


func _launch_army(source_id: int, target_id: int, automatic: bool) -> void:
	if source_id == target_id or source_id < 0 or target_id < 0 or source_id >= cities.size() or target_id >= cities.size():
		return
	if _same_faction(source_id, target_id):
		_log("Those cities already belong to the same faction.")
		return
	_declare_war(source_id, target_id)
	var population: int = _city_population(source_id)
	var strength: int = clamp(1 + int(population / 4), 1, 5)
	if automatic:
		strength = clamp(strength, 1, 3)
	else:
		_log("%s is marching on %s with %d units." % [cities[source_id]["name"], cities[target_id]["name"], strength])
	for unit_index in range(strength):
		var angle: float = float(unit_index) * TAU / float(max(1, strength))
		var source_position: Vector3 = cities[source_id]["pos"]
		var spawn_position: Vector3 = _surface_position(source_position.x + cos(angle) * 2.3, source_position.z + sin(angle) * 2.3)
		var soldier := Node3D.new()
		var uniform := BoxMesh.new()
		uniform.size = Vector3(0.42, 0.78, 0.32)
		_add_mesh(soldier, uniform, _material(cities[source_id]["color"].darkened(0.12)), Vector3(0.0, 0.60, 0.0))
		var helmet := SphereMesh.new()
		helmet.radius = 0.23
		helmet.height = 0.38
		_add_mesh(soldier, helmet, _material(Color(0.26, 0.28, 0.27)), Vector3(0.0, 1.14, 0.0))
		add_child(soldier)
		soldier.position = spawn_position
		armies.append({
			"node": soldier,
			"pos": spawn_position,
			"source": source_id,
			"target": target_id,
			"attack_timer": randf_range(0.0, 2.0),
			"alive": true
		})
	if not automatic and _city_population(target_id) >= 7 and randf() < 0.70:
		_log("%s is raising a defence force!" % cities[target_id]["name"])
		_spawn_defenders(target_id, source_id)


func _spawn_defenders(source_id: int, target_id: int) -> void:
	var count: int = clamp(1 + int(_city_population(source_id) / 8), 1, 3)
	for index in range(count):
		var p: Vector3 = cities[source_id]["pos"]
		var soldier := Node3D.new()
		var uniform := BoxMesh.new()
		uniform.size = Vector3(0.42, 0.78, 0.32)
		_add_mesh(soldier, uniform, _material(cities[source_id]["color"].darkened(0.12)), Vector3(0.0, 0.60, 0.0))
		var helmet := SphereMesh.new()
		helmet.radius = 0.23
		helmet.height = 0.38
		_add_mesh(soldier, helmet, _material(Color(0.26, 0.28, 0.27)), Vector3(0.0, 1.14, 0.0))
		add_child(soldier)
		var spawn := _surface_position(p.x + randf_range(-2.0, 2.0), p.z + randf_range(-2.0, 2.0))
		soldier.position = spawn
		armies.append({"node": soldier, "pos": spawn, "source": source_id, "target": target_id, "attack_timer": 1.0, "alive": true})
	_declare_war(source_id, target_id)


func _update_armies(delta: float) -> void:
	for i in range(armies.size() - 1, -1, -1):
		var army: Dictionary = armies[i]
		var source_id: int = int(army["source"])
		var target_id: int = int(army["target"])
		if source_id >= cities.size() or target_id >= cities.size():
			if is_instance_valid(army["node"]):
				army["node"].queue_free()
			armies.remove_at(i)
			continue
		if _same_faction(source_id, target_id):
			if is_instance_valid(army["node"]):
				army["node"].queue_free()
			armies.remove_at(i)
			continue
		var position: Vector3 = army["pos"]
		var destination: Vector3 = cities[target_id]["pos"]
		var distance: float = Vector2(position.x - destination.x, position.z - destination.z).length()
		if distance > 3.0:
			var dx: float = destination.x - position.x
			var dz: float = destination.z - position.z
			var direction := Vector3(dx, 0.0, dz).normalized()
			position.x += direction.x * delta * 2.8
			position.z += direction.z * delta * 2.8
			position.y = _height_at(position.x, position.z)
		else:
			army["attack_timer"] = float(army["attack_timer"]) + delta
			if float(army["attack_timer"]) >= 3.2:
				army["attack_timer"] = 0.0
				_damage_city(target_id, 1, "army")
				if _city_population(target_id) <= 0:
					_capture_city(target_id, source_id)
				if randf() < 0.10 and is_instance_valid(army["node"]):
					army["node"].queue_free()
					armies.remove_at(i)
					continue
		army["pos"] = position
		if is_instance_valid(army["node"]):
			army["node"].position = position
		armies[i] = army


func _launch_missile(source_id: int, target_id: int) -> void:
	if source_id < 0 or target_id < 0 or source_id >= cities.size() or target_id >= cities.size():
		return
	var start: Vector3 = cities[source_id]["pos"] + Vector3(0.0, 4.4, 0.0)
	var finish: Vector3 = cities[target_id]["pos"] + Vector3(0.0, 1.8, 0.0)
	var missile := Node3D.new()
	var shell := SphereMesh.new()
	shell.radius = 0.38
	shell.height = 0.76
	var shell_material := _material(Color(1.0, 0.28, 0.08), 0.35)
	shell_material.emission_enabled = true
	shell_material.emission = Color(1.0, 0.10, 0.015)
	shell_material.emission_energy_multiplier = 1.6
	_add_mesh(missile, shell, shell_material)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.04
	tail.bottom_radius = 0.14
	tail.height = 0.9
	_add_mesh(missile, tail, _material(Color(0.95, 0.65, 0.12)), Vector3(0.0, -0.55, 0.0))
	add_child(missile)
	missile.position = start
	missiles.append({"node": missile, "start": start, "finish": finish, "t": 0.0, "duration": 2.25, "target": target_id})
	_log("MISSILE AWAY: %s has launched at %s." % [cities[source_id]["name"], cities[target_id]["name"]])


func _update_missiles(delta: float) -> void:
	for i in range(missiles.size() - 1, -1, -1):
		var missile: Dictionary = missiles[i]
		missile["t"] = float(missile["t"]) + delta / float(missile["duration"])
		var t: float = clamp(float(missile["t"]), 0.0, 1.0)
		var point: Vector3 = missile["start"].lerp(missile["finish"], t)
		point.y += sin(t * PI) * 15.0
		if is_instance_valid(missile["node"]):
			missile["node"].position = point
			var direction: Vector3 = (missile["finish"] - missile["start"]).normalized()
			missile["node"].look_at(point + direction + Vector3.UP * 0.25, Vector3.UP)
		if t >= 1.0:
			var target_id: int = int(missile["target"])
			if is_instance_valid(missile["node"]):
				missile["node"].queue_free()
			_spawn_explosion(missile["finish"], target_id)
			missiles.remove_at(i)
		else:
			missiles[i] = missile


func _spawn_explosion(position: Vector3, target_id: int) -> void:
	var blast := MeshInstance3D.new()
	var blast_mesh := SphereMesh.new()
	blast_mesh.radius = 1.0
	blast_mesh.height = 2.0
	blast.mesh = blast_mesh
	var blast_material := StandardMaterial3D.new()
	blast_material.albedo_color = Color(1.0, 0.28, 0.035, 0.62)
	blast_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blast_material.emission_enabled = true
	blast_material.emission = Color(1.0, 0.13, 0.015)
	blast_material.emission_energy_multiplier = 1.8
	blast.material_override = blast_material
	blast.position = position
	add_child(blast)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.31, 0.08)
	light.light_energy = 4.0
	light.omni_range = 14.0
	blast.add_child(light)
	explosions.append({"node": blast, "material": blast_material, "light": light, "t": 0.0, "duration": 0.85})
	if target_id >= 0 and target_id < cities.size():
		_damage_city(target_id, max(2, int(_city_population(target_id) * 0.38)), "missile")
		_destroy_city_houses(target_id, 2)
		_log("IMPACT: %s has been hit. Buildings and citizens are lost." % cities[target_id]["name"])
	for resource in resources:
		var resource_pos: Vector3 = resource["pos"]
		if Vector2(resource_pos.x - position.x, resource_pos.z - position.z).length() < 4.5:
			resource["amount"] = 0
			resource["alive"] = false
			if is_instance_valid(resource["node"]):
				resource["node"].visible = false


func _update_explosions(delta: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var explosion: Dictionary = explosions[i]
		explosion["t"] = float(explosion["t"]) + delta
		var t: float = clamp(float(explosion["t"]) / float(explosion["duration"]), 0.0, 1.0)
		if is_instance_valid(explosion["node"]):
			explosion["node"].scale = Vector3.ONE * lerpf(0.2, 5.0, t)
		var mat: StandardMaterial3D = explosion["material"]
		var c: Color = mat.albedo_color
		c.a = 0.62 * (1.0 - t)
		mat.albedo_color = c
		if is_instance_valid(explosion["light"]):
			explosion["light"].light_energy = 4.0 * (1.0 - t)
		if t >= 1.0:
			if is_instance_valid(explosion["node"]):
				explosion["node"].queue_free()
			explosions.remove_at(i)
		else:
			explosions[i] = explosion


func _damage_city(city_id: int, amount: int, cause: String) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var removed: int = 0
	for i in range(people.size() - 1, -1, -1):
		if int(people[i]["city_id"]) == city_id and removed < amount:
			if is_instance_valid(people[i]["node"]):
				people[i]["node"].queue_free()
			people.remove_at(i)
			removed += 1
	if removed > 0 and cause == "army":
		_log("Fighting near %s: %d citizen(s) lost." % [cities[city_id]["name"], removed])
		cities[city_id]["food"] = max(0.0, float(cities[city_id]["food"]) - float(removed))
	cities[city_id]["population"] = _city_population(city_id)
	if cause == "army" and randf() < 0.15:
		_destroy_city_houses(city_id, 1)
	if is_instance_valid(cities[city_id]["label"]):
		cities[city_id]["label"].text = "%s\nPOP %d" % [cities[city_id]["name"], int(cities[city_id]["population"])]


func _destroy_city_houses(city_id: int, count: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var houses: Array = cities[city_id]["houses"]
	for i in range(min(count, houses.size())):
		var house_index: int = randi_range(0, houses.size() - 1)
		var house = houses[house_index]
		if is_instance_valid(house):
			house.queue_free()
		houses.remove_at(house_index)
	cities[city_id]["houses"] = houses


func _capture_city(city_id: int, source_id: int) -> void:
	if city_id < 0 or source_id < 0 or city_id >= cities.size() or source_id >= cities.size():
		return
	if _same_faction(city_id, source_id):
		return
	var previous_name: String = cities[city_id]["name"]
	cities[city_id]["owner"] = cities[source_id]["owner"]
	cities[city_id]["color"] = cities[source_id]["color"]
	cities[city_id]["body"].material_override = _material(cities[city_id]["color"].darkened(0.25))
	cities[city_id]["roof"].material_override = _material(cities[city_id]["color"].lightened(0.12))
	cities[city_id]["label"].modulate = Color(1.0, 1.0, 1.0)
	for house in cities[city_id]["houses"]:
		if is_instance_valid(house):
			house.modulate = cities[city_id]["color"].lightened(0.2)
	_log("CITY CAPTURED: %s now answers to %s." % [previous_name, cities[source_id]["name"]])
	for spawn_index in range(3):
		var p: Vector3 = cities[city_id]["pos"]
		_spawn_human(_surface_position(p.x + randf_range(-2.0, 2.0), p.z + randf_range(-2.0, 2.0)), city_id)
	_make_peace(city_id, source_id)


func _spawn_god_effect(position: Vector3, tint: Color, radius: float, duration: float, kind: String = "pulse") -> void:
	var effect_node := MeshInstance3D.new()
	var effect_mesh: Mesh
	var base_scale: Vector3
	if kind == "lightning":
		var beam := CylinderMesh.new()
		beam.top_radius = 0.035
		beam.bottom_radius = 0.18
		beam.height = 12.0
		beam.radial_segments = 8
		effect_mesh = beam
		base_scale = Vector3.ONE
		effect_node.position = position + Vector3(0.0, 6.0, 0.0)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		effect_mesh = sphere
		base_scale = Vector3(radius, max(0.35, radius * 0.48), radius)
		effect_node.position = position + Vector3(0.0, 0.55, 0.0)
	effect_node.mesh = effect_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint.r, tint.g, tint.b, 0.82)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.8
	effect_node.material_override = material
	effect_node.scale = base_scale
	add_child(effect_node)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 3.0
	light.omni_range = max(5.0, radius * 3.0)
	effect_node.add_child(light)
	god_effects.append({
		"node": effect_node,
		"material": material,
		"light": light,
		"age": 0.0,
		"duration": duration,
		"base_scale": base_scale,
		"base_alpha": 0.82
	})


func _update_god_effects(delta: float) -> void:
	for i in range(god_effects.size() - 1, -1, -1):
		var effect: Dictionary = god_effects[i]
		effect["age"] = float(effect["age"]) + delta
		var progress: float = clamp(float(effect["age"]) / float(effect["duration"]), 0.0, 1.0)
		var node: Node3D = effect["node"]
		if is_instance_valid(node):
			node.scale = effect["base_scale"] * (1.0 + progress * 0.35)
		var material: StandardMaterial3D = effect["material"]
		var tint: Color = material.albedo_color
		tint.a = float(effect["base_alpha"]) * (1.0 - progress)
		material.albedo_color = tint
		var light: OmniLight3D = effect["light"]
		if is_instance_valid(light):
			light.light_energy = 3.0 * (1.0 - progress)
		if progress >= 1.0:
			if is_instance_valid(node):
				node.queue_free()
			god_effects.remove_at(i)
		else:
			god_effects[i] = effect


func _power_damage(center: Vector3, radius: float, people_limit: int, resource_chance: float, house_damage: int) -> void:
	var removed: int = 0
	for i in range(people.size() - 1, -1, -1):
		var person_position: Vector3 = people[i]["pos"]
		var distance: float = Vector2(person_position.x - center.x, person_position.z - center.z).length()
		if distance <= radius and removed < people_limit:
			if is_instance_valid(people[i]["node"]):
				people[i]["node"].queue_free()
			people.remove_at(i)
			removed += 1
	for resource in resources:
		if int(resource["amount"]) <= 0:
			continue
		var resource_position: Vector3 = resource["pos"]
		var distance: float = Vector2(resource_position.x - center.x, resource_position.z - center.z).length()
		if distance <= radius:
			var chance: float = resource_chance if str(resource["type"]) == "tree" else resource_chance * 0.35
			if randf() < chance:
				resource["amount"] = 0
				resource["alive"] = false
				if is_instance_valid(resource["node"]):
					resource["node"].visible = false
	for city_id in range(cities.size()):
		var city_position: Vector3 = cities[city_id]["pos"]
		var distance: float = Vector2(city_position.x - center.x, city_position.z - center.z).length()
		if distance <= radius * 0.9:
			if house_damage > 0:
				_destroy_city_houses(city_id, house_damage)
			cities[city_id]["food"] = max(0.0, float(cities[city_id]["food"]) - float(removed) * 0.25)
	_refresh_ui()


func _god_lightning(position: Vector3) -> void:
	_spawn_god_effect(position, Color(0.30, 0.82, 1.0), 2.7, 0.45, "lightning")
	_power_damage(position, 3.0, MAX_PEOPLE, 0.30, 1)
	_log("Lightning tears into the ground. Nature has submitted a strongly worded complaint.")


func _ignite_fire(position: Vector3) -> void:
	var fire_root := Node3D.new()
	fire_root.name = "GodFire"
	fire_root.position = position
	add_child(fire_root)
	for flame_index in range(7):
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = randf_range(0.20, 0.34)
		cone.height = randf_range(0.9, 1.7)
		cone.radial_segments = 6
		flame.mesh = cone
		var flame_material := StandardMaterial3D.new()
		var fire_color: Color = Color(1.0, randf_range(0.12, 0.48), 0.035)
		flame_material.albedo_color = fire_color
		flame_material.emission_enabled = true
		flame_material.emission = fire_color
		flame_material.emission_energy_multiplier = 2.0
		flame.material_override = flame_material
		flame.position = Vector3(randf_range(-1.5, 1.5), cone.height * 0.5, randf_range(-1.5, 1.5))
		fire_root.add_child(flame)
	fire_zones.append({"node": fire_root, "pos": position, "radius": max(2.4, brush_radius * 0.75), "age": 0.0, "tick": 0.0})


func _god_fire(position: Vector3) -> void:
	_ignite_fire(position)
	_spawn_god_effect(position, Color(1.0, 0.28, 0.035), max(2.0, brush_radius * 0.6), 0.65)
	_log("A wildfire has begun. It can spread through nearby trees and threaten settlements.")


func _update_fire_zones(delta: float) -> void:
	for i in range(fire_zones.size() - 1, -1, -1):
		var fire: Dictionary = fire_zones[i]
		fire["age"] = float(fire["age"]) + delta
		fire["tick"] = float(fire["tick"]) + delta
		var node: Node3D = fire["node"]
		if is_instance_valid(node):
			node.position.y = _height_at(float(fire["pos"].x), float(fire["pos"].z))
			for flame_index in range(node.get_child_count()):
				var flame: Node3D = node.get_child(flame_index)
				var pulse: float = 0.85 + 0.18 * sin(game_clock * 8.0 + float(flame_index))
				flame.scale.y = pulse
		if float(fire["tick"]) >= 0.9:
			fire["tick"] = 0.0
			_power_damage(fire["pos"], float(fire["radius"]), 2, 0.22, 0)
			if fire_zones.size() < 12:
				for resource in resources:
					if str(resource["type"]) != "tree" or int(resource["amount"]) <= 0:
						continue
					var tree_position: Vector3 = resource["pos"]
					var spread_distance: float = Vector2(tree_position.x - float(fire["pos"].x), tree_position.z - float(fire["pos"].z)).length()
					if spread_distance <= float(fire["radius"]) + 2.2 and randf() < 0.22:
						resource["amount"] = 0
						resource["alive"] = false
						if is_instance_valid(resource["node"]):
							resource["node"].visible = false
						_ignite_fire(_surface_position(tree_position.x, tree_position.z))
						_log("The wildfire has spread to a nearby tree.")
						break
		if float(fire["age"]) >= 8.0:
			if is_instance_valid(node):
				node.queue_free()
			fire_zones.remove_at(i)
		else:
			fire_zones[i] = fire


func _god_meteor(position: Vector3) -> void:
	var meteor_node := MeshInstance3D.new()
	meteor_node.name = "FallingMeteor"
	var meteor_mesh := SphereMesh.new()
	meteor_mesh.radius = 0.82
	meteor_mesh.height = 1.64
	meteor_node.mesh = meteor_mesh
	var meteor_material := StandardMaterial3D.new()
	meteor_material.albedo_color = Color(1.0, 0.18, 0.035)
	meteor_material.emission_enabled = true
	meteor_material.emission = Color(1.0, 0.10, 0.015)
	meteor_material.emission_energy_multiplier = 3.0
	meteor_node.material_override = meteor_material
	var start_position: Vector3 = position + Vector3(0.0, 26.0, 0.0)
	meteor_node.position = start_position
	add_child(meteor_node)
	falling_meteors.append({"node": meteor_node, "start": start_position, "target": position, "age": 0.0, "duration": 0.9})
	_log("Meteor inbound. Local geology is about to become a lot more local.")


func _update_falling_meteors(delta: float) -> void:
	for i in range(falling_meteors.size() - 1, -1, -1):
		var meteor: Dictionary = falling_meteors[i]
		meteor["age"] = float(meteor["age"]) + delta
		var progress: float = clamp(float(meteor["age"]) / float(meteor["duration"]), 0.0, 1.0)
		var node: Node3D = meteor["node"]
		var start_position: Vector3 = meteor["start"]
		var target_position: Vector3 = meteor["target"]
		if is_instance_valid(node):
			node.position = start_position.lerp(target_position + Vector3(0.0, 0.8, 0.0), progress)
			node.rotate_y(delta * 5.0)
		if progress >= 1.0:
			if is_instance_valid(node):
				node.queue_free()
			_spawn_god_effect(target_position, Color(1.0, 0.28, 0.035), max(4.0, brush_radius * 1.4), 0.75)
			_power_damage(target_position, max(4.0, brush_radius * 1.25), MAX_PEOPLE, 1.0, 3)
			_sculpt_terrain(target_position, -1.1)
			falling_meteors.remove_at(i)
		else:
			falling_meteors[i] = meteor


func _god_heal(position: Vector3) -> void:
	var city_id: int = _find_city_at(position, 9.0)
	var cured: int = 0
	for i in range(people.size()):
		var person_position: Vector3 = people[i]["pos"]
		var distance: float = Vector2(person_position.x - position.x, person_position.z - position.z).length()
		if distance <= max(4.0, brush_radius) and bool(people[i].get("infected", false)):
			people[i]["infected"] = false
			people[i]["infection_time"] = 0.0
			var marker: MeshInstance3D = people[i]["infection_marker"]
			if is_instance_valid(marker):
				marker.visible = false
			cured += 1
	var spawned: int = 0
	for person_index in range(5):
		if people.size() >= MAX_PEOPLE:
			break
		var angle: float = randf() * TAU
		var radius: float = randf_range(0.8, 3.0)
		var spawn_position: Vector3 = _surface_position(
			clamp(position.x + cos(angle) * radius, -TERRAIN_SIZE * 0.48, TERRAIN_SIZE * 0.48),
			clamp(position.z + sin(angle) * radius, -TERRAIN_SIZE * 0.48, TERRAIN_SIZE * 0.48)
		)
		_spawn_human(spawn_position, city_id)
		spawned += 1
	if city_id >= 0:
		cities[city_id]["food"] = float(cities[city_id]["food"]) + 6.0
		_sync_city_buildings(city_id)
	_spawn_god_effect(position, Color(0.24, 1.0, 0.56), 4.0, 0.8)
	_log("Blessing bestowed: %d new people appear and %d infection(s) are cured." % [spawned, cured])


func _god_forest(position: Vector3) -> void:
	for tree_index in range(12):
		var angle: float = randf() * TAU
		var radius: float = randf_range(1.0, max(2.0, brush_radius * 1.8))
		var x: float = clamp(position.x + cos(angle) * radius, -TERRAIN_SIZE * 0.48, TERRAIN_SIZE * 0.48)
		var z: float = clamp(position.z + sin(angle) * radius, -TERRAIN_SIZE * 0.48, TERRAIN_SIZE * 0.48)
		_spawn_resource(_surface_position(x, z), "tree", 10)
	_spawn_god_effect(position, Color(0.22, 0.82, 0.30), max(3.0, brush_radius), 0.7)
	_log("A grove bursts into existence. Lumber shortages may now complain elsewhere.")


func _god_earthquake(position: Vector3) -> void:
	_spawn_god_effect(position, Color(0.77, 0.54, 0.28), max(4.0, brush_radius * 1.4), 0.8)
	_power_damage(position, max(4.0, brush_radius * 1.3), MAX_PEOPLE, 0.8, 3)
	_sculpt_terrain(position, -0.8)
	_log("Earthquake! The terrain shifts and nearby settlements take damage.")


func _god_plague(position: Vector3) -> void:
	var infected_count: int = 0
	var radius: float = max(3.0, brush_radius * 1.15)
	for i in range(people.size()):
		var person_position: Vector3 = people[i]["pos"]
		var distance: float = Vector2(person_position.x - position.x, person_position.z - position.z).length()
		if distance <= radius:
			if not bool(people[i]["infected"]):
				infected_count += 1
			people[i]["infected"] = true
			people[i]["infection_time"] = 0.0
			people[i]["spread_timer"] = randf_range(0.25, 1.0)
			var marker: MeshInstance3D = people[i]["infection_marker"]
			if is_instance_valid(marker):
				marker.visible = true
	_spawn_god_effect(position, Color(0.54, 0.88, 0.16), radius, 0.9)
	_log("Plague released: %d nearby human(s) infected. It will spread through crowds." % infected_count)


func _update_plague(delta: float) -> void:
	for i in range(people.size() - 1, -1, -1):
		var person: Dictionary = people[i]
		if not bool(person.get("infected", false)):
			continue
		person["infection_time"] = float(person["infection_time"]) + delta
		person["spread_timer"] = float(person["spread_timer"]) + delta
		if float(person["spread_timer"]) >= 1.25:
			person["spread_timer"] = 0.0
			var infected_position: Vector3 = person["pos"]
			for neighbour_index in range(people.size()):
				if neighbour_index == i:
					continue
				var neighbour: Dictionary = people[neighbour_index]
				if bool(neighbour.get("infected", false)):
					continue
				var neighbour_position: Vector3 = neighbour["pos"]
				var distance: float = Vector2(neighbour_position.x - infected_position.x, neighbour_position.z - infected_position.z).length()
				if distance <= 2.25 and randf() < 0.24:
					neighbour["infected"] = true
					neighbour["infection_time"] = 0.0
					neighbour["spread_timer"] = randf_range(0.3, 1.0)
					var neighbour_marker: MeshInstance3D = neighbour["infection_marker"]
					if is_instance_valid(neighbour_marker):
						neighbour_marker.visible = true
					people[neighbour_index] = neighbour
		if float(person["infection_time"]) >= 12.0:
			if is_instance_valid(person["node"]):
				person["node"].queue_free()
			people.remove_at(i)
		else:
			people[i] = person


func _god_tornado(position: Vector3) -> void:
	var tornado_node := Node3D.new()
	tornado_node.name = "GodTornado"
	tornado_node.position = position
	add_child(tornado_node)
	for ring_index in range(4):
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.outer_radius = 1.0 + float(ring_index) * 0.45
		ring_mesh.inner_radius = ring_mesh.outer_radius - 0.12
		ring_mesh.rings = 6
		ring_mesh.ring_segments = 24
		ring.mesh = ring_mesh
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = Color(0.64, 0.70, 0.76, 0.52)
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.emission_enabled = true
		ring_material.emission = Color(0.24, 0.34, 0.43)
		ring.material_override = ring_material
		ring.position = Vector3(0.0, 0.7 + float(ring_index) * 0.8, 0.0)
		ring.rotation.x = 0.12 * float(ring_index)
		tornado_node.add_child(ring)
	var target_x: float = clamp(position.x + randf_range(-20.0, 20.0), -TERRAIN_SIZE * 0.45, TERRAIN_SIZE * 0.45)
	var target_z: float = clamp(position.z + randf_range(-20.0, 20.0), -TERRAIN_SIZE * 0.45, TERRAIN_SIZE * 0.45)
	tornadoes.append({"node": tornado_node, "pos": position, "target": _surface_position(target_x, target_z), "age": 0.0, "tick": 0.0})
	_spawn_god_effect(position, Color(0.61, 0.70, 0.82), 3.5, 0.7)
	_log("Tornado spawned. It's heading somewhere with absolutely no regard for zoning laws.")


func _update_tornadoes(delta: float) -> void:
	for i in range(tornadoes.size() - 1, -1, -1):
		var tornado: Dictionary = tornadoes[i]
		tornado["age"] = float(tornado["age"]) + delta
		tornado["tick"] = float(tornado["tick"]) + delta
		var position: Vector3 = tornado["pos"]
		var target: Vector3 = tornado["target"]
		var direction := Vector3(target.x - position.x, 0.0, target.z - position.z)
		if direction.length() < 1.4:
			var target_x: float = clamp(position.x + randf_range(-18.0, 18.0), -TERRAIN_SIZE * 0.46, TERRAIN_SIZE * 0.46)
			var target_z: float = clamp(position.z + randf_range(-18.0, 18.0), -TERRAIN_SIZE * 0.46, TERRAIN_SIZE * 0.46)
			tornado["target"] = _surface_position(target_x, target_z)
		else:
			var step: Vector3 = direction.normalized() * delta * 3.8
			position.x = clamp(position.x + step.x, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			position.z = clamp(position.z + step.z, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			position.y = _height_at(position.x, position.z)
			tornado["pos"] = position
		var node: Node3D = tornado["node"]
		if is_instance_valid(node):
			node.position = position
			for ring_index in range(node.get_child_count()):
				var ring: Node3D = node.get_child(ring_index)
				ring.rotate_y(delta * (2.5 + float(ring_index) * 1.1))
		if float(tornado["tick"]) >= 0.75:
			tornado["tick"] = 0.0
			_power_damage(position, 2.8, 2, 0.25, 1)
		if float(tornado["age"]) >= 10.0:
			if is_instance_valid(node):
				node.queue_free()
			tornadoes.remove_at(i)
		else:
			tornadoes[i] = tornado


func _update_brush_preview() -> void:
	if not is_instance_valid(brush_preview):
		return
	if tool_mode == "select" and pending_action == "":
		brush_preview.visible = false
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var world_position: Vector3 = _get_ground_position(mouse_position)
	if abs(world_position.x) > TERRAIN_SIZE * 0.5 or abs(world_position.z) > TERRAIN_SIZE * 0.5:
		brush_preview.visible = false
		return
	brush_preview.visible = true
	brush_preview.position = world_position + Vector3(0.0, 0.09, 0.0)
	brush_preview.scale = Vector3(brush_radius, 1.0, brush_radius)
	var preview_colors: Dictionary = {
		"raise": Color(0.66, 0.90, 0.32, 0.80),
		"lower": Color(0.37, 0.72, 1.0, 0.80),
		"fire": Color(1.0, 0.28, 0.06, 0.80),
		"meteor": Color(1.0, 0.38, 0.10, 0.80),
		"plague": Color(0.62, 1.0, 0.22, 0.80),
		"heal": Color(0.22, 1.0, 0.58, 0.80),
		"forest": Color(0.20, 0.92, 0.36, 0.80),
		"quake": Color(0.82, 0.60, 0.29, 0.80),
		"tornado": Color(0.72, 0.80, 0.91, 0.80),
		"lightning": Color(0.30, 0.82, 1.0, 0.80)
	}
	brush_preview_material.albedo_color = preview_colors.get(tool_mode, Color(0.28, 0.86, 1.0, 0.80))


func _erase_near(position: Vector3) -> void:
	var best_person: int = -1
	var best_distance: float = 3.0
	for i in range(people.size()):
		var p: Vector3 = people[i]["pos"]
		var d: float = Vector2(p.x - position.x, p.z - position.z).length()
		if d < best_distance:
			best_distance = d
			best_person = i
	if best_person >= 0:
		if is_instance_valid(people[best_person]["node"]):
			people[best_person]["node"].queue_free()
		people.remove_at(best_person)
		_log("One human erased. The mysteries of godhood remain unsolved.")
		return
	for resource in resources:
		var p: Vector3 = resource["pos"]
		if Vector2(p.x - position.x, p.z - position.z).length() < 3.0 and int(resource["amount"]) > 0:
			resource["amount"] = 0
			resource["alive"] = false
			if is_instance_valid(resource["node"]):
				resource["node"].visible = false
			_log("Resource removed.")
			return
	_log("Nothing nearby to erase.")


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui_root)

	var left_panel := PanelContainer.new()
	left_panel.anchor_left = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 14.0
	left_panel.offset_right = 294.0
	left_panel.offset_top = 14.0
	left_panel.offset_bottom = -14.0
	left_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.96)))
	ui_root.add_child(left_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	left_panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	content.add_child(_make_label("CIVITERRA", 26, Color(0.46, 0.86, 0.98)))
	content.add_child(_make_label("GOD SANDBOX  /  3D PROTOTYPE", 10, Color(0.62, 0.72, 0.80)))
	content.add_child(_make_label("Shape the land. Raise people. Let the little kingdoms make their own terrible decisions.", 12, Color(0.82, 0.86, 0.89)))
	content.add_child(_make_separator())
	stats_label = _make_label("CITIES  3     PEOPLE  16", 13, Color(0.52, 0.86, 0.70))
	content.add_child(stats_label)
	content.add_child(_make_label("WORLD TOOLS", 12, Color(0.46, 0.86, 0.98)))
	tool_label = _make_label("Active: Select and inspect cities", 11, Color(0.77, 0.84, 0.88))
	content.add_child(tool_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	_add_tool_button(grid, "Select City", "select", Color(0.12, 0.23, 0.30))
	_add_tool_button(grid, "Raise Land", "raise", Color(0.29, 0.32, 0.20))
	_add_tool_button(grid, "Lower Land", "lower", Color(0.23, 0.29, 0.36))
	_add_tool_button(grid, "Spawn Human", "human", Color(0.15, 0.32, 0.29))
	_add_tool_button(grid, "Plant Trees", "tree", Color(0.12, 0.30, 0.20))
	_add_tool_button(grid, "Spawn Stone", "stone", Color(0.27, 0.29, 0.31))
	_add_tool_button(grid, "Spawn Food", "food", Color(0.35, 0.22, 0.21))
	_add_tool_button(grid, "Erase", "erase", Color(0.29, 0.17, 0.19))
	_add_tool_button(grid, "Lightning", "lightning", Color(0.14, 0.36, 0.57))
	_add_tool_button(grid, "Fire", "fire", Color(0.58, 0.23, 0.09))
	_add_tool_button(grid, "Meteor", "meteor", Color(0.52, 0.16, 0.12))
	_add_tool_button(grid, "Tornado", "tornado", Color(0.31, 0.35, 0.43))
	_add_tool_button(grid, "Plague", "plague", Color(0.34, 0.26, 0.40))
	_add_tool_button(grid, "Heal / Bless", "heal", Color(0.12, 0.42, 0.30))
	_add_tool_button(grid, "Create Forest", "forest", Color(0.10, 0.36, 0.19))
	_add_tool_button(grid, "Earthquake", "quake", Color(0.42, 0.30, 0.16))

	content.add_child(_make_label("TERRAIN BRUSH", 12, Color(0.46, 0.86, 0.98)))
	var brush_row := HBoxContainer.new()
	brush_row.add_theme_constant_override("separation", 6)
	content.add_child(brush_row)
	brush_row.add_child(_make_button("−", func(): _change_brush(-1.0), Color(0.13, 0.18, 0.23)))
	radius_label = _make_label("Radius 4.0", 12, Color(0.84, 0.88, 0.90))
	radius_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brush_row.add_child(radius_label)
	brush_row.add_child(_make_button("+", func(): _change_brush(1.0), Color(0.13, 0.18, 0.23)))

	content.add_child(_make_separator())
	content.add_child(_make_label("CITY COMMAND", 12, Color(0.46, 0.86, 0.98)))
	city_info_label = _make_label("Select a city to view its status.", 12, Color(0.86, 0.89, 0.91))
	city_info_label.custom_minimum_size = Vector2(0, 88)
	city_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(city_info_label)
	control_button = _make_button("CONTROL SELECTED CITY", _take_control, Color(0.12, 0.36, 0.43))
	content.add_child(control_button)
	content.add_child(_make_button("Launch Missile", func(): _prepare_action("missile"), Color(0.45, 0.19, 0.12)))
	content.add_child(_make_button("Order Invasion", func(): _prepare_action("army"), Color(0.39, 0.20, 0.16)))
	content.add_child(_make_button("Offer Ceasefire", func(): _prepare_action("peace"), Color(0.20, 0.30, 0.34)))
	pending_label = _make_label("No order pending.", 11, Color(0.98, 0.77, 0.43))
	pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(pending_label)

	content.add_child(_make_separator())
	pause_button = _make_button("Pause Simulation", _toggle_pause, Color(0.13, 0.22, 0.29))
	content.add_child(pause_button)
	speed_button = _make_button("Simulation Speed: 1×", _cycle_speed, Color(0.13, 0.22, 0.29))
	content.add_child(speed_button)
	content.add_child(_make_label("CONTROLS", 12, Color(0.46, 0.86, 0.98)))
	content.add_child(_make_label("WASD / arrows: move camera\nRight-drag: orbit\nMiddle-drag: pan\nMouse wheel: zoom\nDrag to paint terrain/resources.\nChoose a power, then click the world.", 11, Color(0.68, 0.75, 0.80)))

	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 0.0
	right_panel.offset_left = -320.0
	right_panel.offset_right = -14.0
	right_panel.offset_top = 14.0
	right_panel.offset_bottom = 276.0
	right_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.91)))
	ui_root.add_child(right_panel)
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 13)
	right_margin.add_theme_constant_override("margin_right", 13)
	right_margin.add_theme_constant_override("margin_top", 12)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	right_panel.add_child(right_margin)
	var right_content := VBoxContainer.new()
	right_content.add_theme_constant_override("separation", 7)
	right_margin.add_child(right_content)
	right_content.add_child(_make_label("WORLD CHRONICLE", 13, Color(0.46, 0.86, 0.98)))
	log_label = _make_label("Waiting for history to happen...", 11, Color(0.76, 0.83, 0.86))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_content.add_child(log_label)


func _add_tool_button(parent: GridContainer, text: String, mode: String, tint: Color) -> void:
	var button := _make_button(text, func(): _set_tool(mode), tint)
	button.custom_minimum_size = Vector2(0.0, 38.0)
	parent.add_child(button)
	tool_buttons[mode] = button


func _set_tool(mode: String) -> void:
	tool_mode = mode
	pending_action = ""
	for existing_mode in tool_buttons.keys():
		var button: Button = tool_buttons[existing_mode]
		button.modulate = Color(1.18, 1.18, 1.18) if existing_mode == mode else Color(0.82, 0.86, 0.89)
	_refresh_ui()


func _change_brush(amount: float) -> void:
	brush_radius = clamp(brush_radius + amount, 1.5, 9.0)
	if is_instance_valid(radius_label):
		radius_label.text = "Radius %.1f" % brush_radius
	_update_brush_preview()


func _take_control() -> void:
	if selected_city < 0 or selected_city >= cities.size():
		_log("Select a city on the map first.")
		return
	controlled_city = selected_city
	_log("You are now commanding %s. Pick an order, then click its target." % cities[controlled_city]["name"])
	_refresh_ui()


func _prepare_action(action: String) -> void:
	if controlled_city < 0 or controlled_city >= cities.size():
		_log("Choose a city and press CONTROL SELECTED CITY first.")
		return
	pending_action = action
	tool_mode = "select"
	for existing_mode in tool_buttons.keys():
		var button: Button = tool_buttons[existing_mode]
		button.modulate = Color(1.18, 1.18, 1.18) if existing_mode == "select" else Color(0.82, 0.86, 0.89)
	_refresh_ui()
	_log("Order ready: click a target city on the map.")


func _toggle_pause() -> void:
	paused = not paused
	if is_instance_valid(pause_button):
		pause_button.text = "Resume Simulation" if paused else "Pause Simulation"
	_log("Simulation %s." % ("paused" if paused else "resumed"))


func _cycle_speed() -> void:
	if is_equal_approx(sim_speed, 1.0):
		sim_speed = 2.0
	elif is_equal_approx(sim_speed, 2.0):
		sim_speed = 4.0
	else:
		sim_speed = 1.0
	if is_instance_valid(speed_button):
		speed_button.text = "Simulation Speed: %s×" % str(int(sim_speed))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_button(text: String, callback: Callable, tint: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 35.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.91, 0.95, 0.97))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(tint))
	button.add_theme_stylebox_override("hover", _button_style(tint.lightened(0.16)))
	button.add_theme_stylebox_override("pressed", _button_style(tint.lightened(0.25)))
	button.add_theme_stylebox_override("focus", _button_style(tint))
	button.pressed.connect(callback)
	return button


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.20, 0.35, 0.42, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.20, 0.31, 0.36))
	return separator


func _log(message: String) -> void:
	log_entries.push_front("• " + message)
	while log_entries.size() > 8:
		log_entries.pop_back()
	if is_instance_valid(log_label):
		log_label.text = _joined_logs()


func _joined_logs() -> String:
	var lines := PackedStringArray()
	for entry in log_entries:
		lines.append(entry)
	return "\n\n".join(lines)


func _refresh_ui() -> void:
	if is_instance_valid(stats_label):
		var active_wars: int = wars.size()
		stats_label.text = "CITIES  %02d     PEOPLE  %03d\nWARS  %02d     TIME  %s" % [cities.size(), people.size(), active_wars, _format_time(game_clock)]
	if is_instance_valid(radius_label):
		radius_label.text = "Radius %.1f" % brush_radius
	if is_instance_valid(selection_ring):
		if selected_city >= 0 and selected_city < cities.size():
			selection_ring.visible = true
			selection_ring.position = cities[selected_city]["pos"] + Vector3(0.0, 0.20, 0.0)
		else:
			selection_ring.visible = false
	if is_instance_valid(tool_label):
		var tool_names: Dictionary = {"select": "Select and inspect cities", "raise": "Raise terrain with the brush", "lower": "Lower terrain with the brush", "human": "Spawn humans; clusters can found settlements", "tree": "Plant a wood resource", "stone": "Place a stone deposit", "food": "Place a food resource", "erase": "Erase a nearby human or resource", "lightning": "Strike the ground with lightning", "fire": "Start a spreading fire", "meteor": "Call down a destructive meteor", "tornado": "Send a moving vortex through the world", "plague": "Infect humans and let sickness spread", "heal": "Bless an area with new people", "forest": "Create a grove of trees", "quake": "Shake and deform the land"}
		tool_label.text = "Active: %s" % str(tool_names.get(tool_mode, tool_mode))
	for city_index in range(cities.size()):
		if is_instance_valid(cities[city_index]["label"]):
			cities[city_index]["population"] = _city_population(city_index)
			cities[city_index]["label"].text = "%s\nPOP %d" % [cities[city_index]["name"], int(cities[city_index]["population"])]
	if is_instance_valid(city_info_label):
		if selected_city >= 0 and selected_city < cities.size():
			var city: Dictionary = cities[selected_city]
			var owner_id: int = int(city["owner"])
			var owner_name: String = cities[owner_id]["name"] if owner_id >= 0 and owner_id < cities.size() else city["name"]
			city_info_label.text = "SELECTED  %s\nPOPULATION  %d\nOWNER  %s\nFOOD  %d   WOOD  %d   STONE  %d" % [city["name"], _city_population(selected_city), owner_name, int(city["food"]), int(city["wood"]), int(city["stone"])]
		else:
			city_info_label.text = "Select a city to view its people, resources and owner."
	if is_instance_valid(control_button):
		if controlled_city >= 0 and controlled_city < cities.size():
			control_button.text = "COMMANDING: %s" % cities[controlled_city]["name"]
		else:
			control_button.text = "CONTROL SELECTED CITY"
	if is_instance_valid(pending_label):
		if pending_action == "missile":
			pending_label.text = "MISSILE: click the city you want to hit."
		elif pending_action == "army":
			pending_label.text = "INVASION: click the city to attack."
		elif pending_action == "peace":
			pending_label.text = "CEASEFIRE: click the other city."
		else:
			pending_label.text = "Tool: %s" % tool_mode.capitalize()
	if is_instance_valid(log_label):
		log_label.text = _joined_logs()


func _format_time(seconds: float) -> String:
	var total_seconds: int = int(seconds)
	var minutes: int = int(total_seconds / 60)
	var remainder: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remainder]
