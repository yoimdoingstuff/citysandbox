extends Node3D

const TERRAIN_RES: int = 241
const TERRAIN_SIZE: float = 256.0
const TERRAIN_LOD_STEPS: Array[int] = [1, 2, 4, 8]
const MAX_CITIES: int = 10
const MAX_PEOPLE: int = 800
const MAX_CITY_POPULATION: int = 600
const MAX_CITY_HOUSES: int = 140
const MAX_CARS: int = 36
const ROAD_GRID_SIZE: float = 7.5
const WATER_LEVEL: float = -0.15
const STARTING_YEAR: int = 1200
const SECONDS_PER_YEAR: float = 3.0
const TERRITORY_CELL_SIZE: float = 4.0
const SAVE_PATH: String = "user://civiterra_world.json"
const SAVE_VERSION: int = 3
const MISSILE_UNLOCK_YEAR: int = 1945
const ERA_SKIP_YEARS: Array[int] = [1200, 1450, 1780, 1880, 1950, 2000, 2026]

var terrain: MeshInstance3D
var terrain_material: StandardMaterial3D
var terrain_lod_nodes: Array[MeshInstance3D] = []
var terrain_lod_dirty: Array[bool] = [true, true, true, true]
var terrain_moisture_noise: FastNoiseLite
var terrain_temperature_noise: FastNoiseLite
var selection_ring: MeshInstance3D
var camera_auto_zoom_active: bool = false
var camera_auto_zoom_follow_city: bool = false
var camera_auto_zoom_target: float = 94.0
var camera_auto_focus_target: Vector3 = Vector3.ZERO
var terrain_heights: Array = []
var city_names: Array[String] = ["Asterfall", "Mossreach", "Copper Bay", "New Avalon", "Westhaven", "Emberplain", "Stonebridge", "Northstar", "Rivermark", "Sunfield"]
var city_colors: Array[Color] = [
	Color(0.17, 0.67, 0.93), Color(0.94, 0.48, 0.18), Color(0.62, 0.42, 0.88),
	Color(0.22, 0.76, 0.48), Color(0.91, 0.32, 0.40), Color(0.91, 0.76, 0.22),
	Color(0.24, 0.55, 0.91), Color(0.86, 0.43, 0.70), Color(0.42, 0.78, 0.77), Color(0.72, 0.72, 0.75)
]
var cities: Array = []
var people: Array = []
var cars: Array = []
var resources: Array = []
var _material_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var citizen_infection_marker_mesh: SphereMesh
var citizen_infection_marker_material: StandardMaterial3D
var last_detail_signature: String = ""
var territory_refresh_pending: bool = false
var territory_refresh_timer: float = 0.0
var city_defence_timer: float = 0.0
var armies: Array = []
var missiles: Array = []
var explosions: Array = []
var god_effects: Array = []
var fire_zones: Array = []
var falling_meteors: Array = []
var tornadoes: Array = []
var wars: Array = []
var city_event_scenes: Array = []
var rubble_records: Array = []
var rubble_nodes: Array = []
var rubble_id_sequence: int = 1
var abandoned_check_timer: float = 0.0
var log_entries: Array[String] = []

var selected_city: int = -1
var controlled_city: int = -1
var tool_mode: String = "select"
var pending_action: String = ""
var brush_radius: float = 4.0
var paused: bool = false
var sim_speed: float = 1.0
var reset_speed_on_city_event: bool = false
var game_clock: float = 0.0
var last_architecture_era: int = -1
var world_seed: int = 0
var people_update_accumulator: float = 0.0
var car_update_accumulator: float = 0.0
var traffic_spawn_timer: float = 0.0
var growth_timer: float = 0.0
var city_event_timer: float = 16.0
var city_events_total: int = 0
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
var missile_button: Button
var invasion_button: Button
var ceasefire_button: Button
var era_skipper: OptionButton
var city_context_panel: PanelContainer
var tool_buttons: Dictionary = {}


func _ready() -> void:
	randomize()
	world_seed = randi() & 0x7FFFFFFF
	seed(world_seed)
	_build_world()
	_build_ui()
	_seed_civilizations()
	_scatter_world_resources()
	_set_tool("select")
	_log("Generated a multi-continent world. Seed: %d." % world_seed)
	_log("The world is alive. Select a city to inspect it, then take control to issue orders.")
	_log("Tip: spawn humans in a cluster and they can found a new settlement on their own.")
	_update_historical_era(true)
	_refresh_ui()
	if OS.get_cmdline_user_args().has("--civiterra-save-load-smoke-test"):
		call_deferred("_run_save_load_smoke_test")


func _process(delta: float) -> void:
	_update_camera_input(delta)
	_update_auto_city_camera(delta)
	preview_timer += delta
	if preview_timer >= 0.10:
		preview_timer = 0.0
		_update_brush_preview()
	var sim_delta: float = 0.0
	if not paused:
		sim_delta = delta * sim_speed
		game_clock += sim_delta

		# Throttle the full crowd update as populations grow, while preserving game-time motion.
		var people_update_interval: float = 0.0
		if camera_distance > 165.0:
			people_update_interval = 0.65
		elif camera_distance > 100.0:
			people_update_interval = 0.24
		elif people.size() > 500:
			people_update_interval = 0.12
		elif people.size() > 260:
			people_update_interval = 0.08
		elif people.size() > 120:
			people_update_interval = 0.04
		if people_update_interval <= 0.0:
			people_update_accumulator = 0.0
			_update_people(sim_delta)
		else:
			people_update_accumulator += sim_delta
			if people_update_accumulator >= people_update_interval:
				var people_delta: float = people_update_accumulator
				people_update_accumulator = fmod(people_update_accumulator, people_update_interval)
				_update_people(people_delta)

		if not cars.is_empty():
			var car_update_interval: float = 0.09 if camera_distance <= 85.0 else (0.18 if camera_distance <= 165.0 else 0.42)
			car_update_accumulator += sim_delta
			if car_update_accumulator >= car_update_interval:
				var cars_delta: float = car_update_accumulator
				car_update_accumulator = fmod(car_update_accumulator, car_update_interval)
				_update_cars(cars_delta)

		_update_armies(sim_delta)
		_update_missiles(sim_delta)
		_update_explosions(sim_delta)
		_update_god_effects(sim_delta)
		_update_fire_zones(sim_delta)
		_update_falling_meteors(sim_delta)
		_update_tornadoes(sim_delta)
		_update_plague(sim_delta)
		_update_simulation_timers(sim_delta)
		_update_city_event_markers(sim_delta)
		_update_city_event_scenes(sim_delta)
		_update_historical_era()
	ui_timer += delta
	if ui_timer >= 0.35:
		ui_timer = 0.0
		_update_world_detail_levels()
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
	water_mesh.size = Vector2(TERRAIN_SIZE * 3.0, TERRAIN_SIZE * 3.0)
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
	camera.far = TERRAIN_SIZE * 6.0
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
	broad_noise.seed = world_seed + 14029
	broad_noise.frequency = 0.028
	broad_noise.fractal_octaves = 3
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = world_seed + 8201
	detail_noise.frequency = 0.095
	var coastline_noise := FastNoiseLite.new()
	coastline_noise.seed = world_seed + 33191
	coastline_noise.frequency = 0.052
	coastline_noise.fractal_octaves = 2
	terrain_moisture_noise = FastNoiseLite.new()
	terrain_moisture_noise.seed = world_seed + 51713
	terrain_moisture_noise.frequency = 0.032
	terrain_moisture_noise.fractal_octaves = 2
	terrain_temperature_noise = FastNoiseLite.new()
	terrain_temperature_noise.seed = world_seed + 73517
	terrain_temperature_noise.frequency = 0.024
	terrain_temperature_noise.fractal_octaves = 2

	# Scaled landmasses provide room for larger cities and expanding suburbs.
	var continent_centers: Array[Vector2] = [
		Vector2(-43.0, -27.0), Vector2(56.0, -28.0), Vector2(3.0, 53.0),
		Vector2(-85.0, 32.0), Vector2(85.0, 61.0), Vector2(-82.0, -73.0)
	]
	var continent_radii: Array[Vector2] = [
		Vector2(55.5, 46.5), Vector2(42.0, 57.0), Vector2(66.0, 48.0),
		Vector2(24.0, 31.5), Vector2(21.0, 25.5), Vector2(22.5, 19.5)
	]
	for z_index in range(TERRAIN_RES):
		var row: Array = []
		for x_index in range(TERRAIN_RES):
			var x: float = (float(x_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
			var z: float = (float(z_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
			var continent_score: float = -10.0
			for continent_index in range(continent_centers.size()):
				var relative: Vector2 = Vector2(
					(x - continent_centers[continent_index].x) / continent_radii[continent_index].x,
					(z - continent_centers[continent_index].y) / continent_radii[continent_index].y
				)
				continent_score = maxf(continent_score, 1.0 - relative.length())
			var land_score: float = continent_score + coastline_noise.get_noise_2d(x, z) * 0.18
			var broad_value: float = broad_noise.get_noise_2d(x, z)
			var detail_value: float = detail_noise.get_noise_2d(x, z)
			var h: float
			if land_score > -0.025:
				var land_strength: float = clampf((land_score + 0.025) / 0.92, 0.0, 1.0)
				h = WATER_LEVEL + 0.18 + land_strength * 5.5 + broad_value * 1.25 + maxf(0.0, detail_value) * 0.35
				h = maxf(WATER_LEVEL + 0.06, h)
			else:
				h = WATER_LEVEL - 0.90 + broad_value * 0.16
			row.append(h)
		terrain_heights.append(row)


func _rebuild_terrain() -> void:
	# Terrain sculpting invalidates each LOD, but only rebuild the currently
	# visible one. Other resolutions are regenerated lazily if the player zooms
	# to them, avoiding four mesh rebuilds for every brush stroke.
	if terrain_lod_nodes.is_empty():
		terrain_lod_nodes.append(terrain)
	while terrain_lod_nodes.size() < TERRAIN_LOD_STEPS.size():
		var lod_index: int = terrain_lod_nodes.size()
		var lod_node := MeshInstance3D.new()
		lod_node.name = "TerrainLOD_%d" % int(ceil(float(TERRAIN_RES - 1) / float(TERRAIN_LOD_STEPS[lod_index])) + 1.0)
		lod_node.material_override = terrain_material
		add_child(lod_node)
		terrain_lod_nodes.append(lod_node)

	if terrain_lod_dirty.size() != TERRAIN_LOD_STEPS.size():
		terrain_lod_dirty.clear()
		for lod_index in range(TERRAIN_LOD_STEPS.size()):
			terrain_lod_dirty.append(true)
	else:
		for lod_index in range(TERRAIN_LOD_STEPS.size()):
			terrain_lod_dirty[lod_index] = true

	var active_lod: int = _terrain_lod_index_for_distance(camera_distance)
	_build_terrain_lod(active_lod)
	for lod_index in range(terrain_lod_nodes.size()):
		terrain_lod_nodes[lod_index].visible = lod_index == active_lod


func _build_terrain_lod(lod_index: int) -> void:
	if lod_index < 0 or lod_index >= terrain_lod_nodes.size():
		return
	var stride: int = TERRAIN_LOD_STEPS[lod_index]
	var spacing: float = TERRAIN_SIZE / float(TERRAIN_RES - 1)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_index in range(0, TERRAIN_RES - 1, stride):
		var z_next: int = min(z_index + stride, TERRAIN_RES - 1)
		var z0: float = -TERRAIN_SIZE * 0.5 + float(z_index) * spacing
		var z1: float = -TERRAIN_SIZE * 0.5 + float(z_next) * spacing
		for x_index in range(0, TERRAIN_RES - 1, stride):
			var x_next: int = min(x_index + stride, TERRAIN_RES - 1)
			var x0: float = -TERRAIN_SIZE * 0.5 + float(x_index) * spacing
			var x1: float = -TERRAIN_SIZE * 0.5 + float(x_next) * spacing
			var p00 := Vector3(x0, terrain_heights[z_index][x_index], z0)
			var p10 := Vector3(x1, terrain_heights[z_index][x_next], z0)
			var p01 := Vector3(x0, terrain_heights[z_next][x_index], z1)
			var p11 := Vector3(x1, terrain_heights[z_next][x_next], z1)
			# Keep the known working top-facing triangle order for every LOD.
			_add_terrain_vertex(surface, p00)
			_add_terrain_vertex(surface, p10)
			_add_terrain_vertex(surface, p01)
			_add_terrain_vertex(surface, p10)
			_add_terrain_vertex(surface, p11)
			_add_terrain_vertex(surface, p01)
	surface.index()
	surface.generate_normals(true)
	var lod_node: MeshInstance3D = terrain_lod_nodes[lod_index]
	lod_node.mesh = surface.commit()
	lod_node.material_override = terrain_material
	terrain_lod_dirty[lod_index] = false


func _terrain_lod_index_for_distance(distance: float) -> int:
	if distance <= 58.0:
		return 0
	if distance <= 100.0:
		return 1
	if distance <= 165.0:
		return 2
	return 3


func _add_terrain_vertex(surface: SurfaceTool, p: Vector3) -> void:
	surface.set_color(_terrain_color_at(p))
	surface.add_vertex(p)


func _terrain_color(height: float) -> Color:
	# Fallback palette retained for callers that only have a height value.
	if height < WATER_LEVEL - 0.25:
		return Color(0.12, 0.25, 0.31)
	if height < WATER_LEVEL + 0.5:
		return Color(0.72, 0.65, 0.44)
	if height > 4.6:
		return Color(0.49, 0.51, 0.48)
	if height > 3.2:
		return Color(0.35, 0.51, 0.31)
	return Color(0.24, 0.48, 0.23)


func _terrain_color_at(point: Vector3) -> Color:
	if point.y < WATER_LEVEL - 0.25:
		return Color(0.12, 0.25, 0.31)
	if point.y < WATER_LEVEL + 0.5:
		return Color(0.72, 0.65, 0.44)

	var moisture: float = 0.5
	var climate: float = 0.0
	if terrain_moisture_noise != null:
		moisture = (terrain_moisture_noise.get_noise_2d(point.x, point.z) + 1.0) * 0.5
	if terrain_temperature_noise != null:
		climate = terrain_temperature_noise.get_noise_2d(point.x, point.z)
	var latitude_cooling: float = abs(point.z) / TERRAIN_SIZE * 0.42
	var temperature: float = clamp(0.78 - latitude_cooling + climate * 0.24, 0.0, 1.0)

	var grass := Color(0.26, 0.53, 0.25)
	var lush_grass := Color(0.16, 0.43, 0.22)
	var dry_soil := Color(0.69, 0.58, 0.36)
	var rock := Color(0.43, 0.45, 0.43)
	var snow := Color(0.82, 0.86, 0.88)

	var color: Color = grass.lerp(lush_grass, clamp((moisture - 0.55) * 1.7, 0.0, 0.7))
	var desert_amount: float = clamp((0.38 - moisture) * 3.4, 0.0, 0.88) * clamp((temperature - 0.36) * 2.2, 0.0, 1.0)
	color = color.lerp(dry_soil, desert_amount)
	var rock_amount: float = clamp((point.y - 3.3) * 0.28, 0.0, 0.66)
	color = color.lerp(rock, rock_amount)
	var snow_amount: float = clamp((point.y - 4.9) * 0.42 + (0.39 - temperature) * 1.2, 0.0, 0.92)
	color = color.lerp(snow, snow_amount)
	return color


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


func _request_city_camera_zoom(city_id: int, force_follow: bool = false) -> void:
	if force_follow:
		camera_auto_zoom_follow_city = true
	if not camera_auto_zoom_follow_city:
		return
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var radius: float = float(city.get("zone_radius", 12.0))
	camera_auto_focus_target = city["pos"]
	camera_auto_zoom_target = maxf(camera_distance, minf(TERRAIN_SIZE * 1.65, radius * 4.25))
	camera_auto_zoom_active = true


func _update_auto_city_camera(delta: float) -> void:
	if not camera_auto_zoom_active:
		return
	var blend: float = 1.0 - exp(-delta * 2.4)
	camera_target = camera_target.lerp(camera_auto_focus_target, blend)
	camera_distance = lerpf(camera_distance, camera_auto_zoom_target, blend)
	_update_camera()
	if camera_target.distance_to(camera_auto_focus_target) < 0.25 and abs(camera_distance - camera_auto_zoom_target) < 0.35:
		camera_auto_zoom_active = false


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
		camera_auto_zoom_active = false
		camera_auto_zoom_follow_city = false
		camera_target += movement.normalized() * delta * max(12.0, camera_distance * 0.30)
		var camera_limit: float = TERRAIN_SIZE * 0.5 - 8.0
		camera_target.x = clamp(camera_target.x, -camera_limit, camera_limit)
		camera_target.z = clamp(camera_target.z, -camera_limit, camera_limit)
		_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			camera_auto_zoom_active = false
			camera_auto_zoom_follow_city = false
			rotating_camera = mouse_event.pressed
			last_mouse_position = mouse_event.position
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			camera_auto_zoom_active = false
			camera_auto_zoom_follow_city = false
			panning_camera = mouse_event.pressed
			last_mouse_position = mouse_event.position
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			camera_auto_zoom_active = false
			camera_auto_zoom_follow_city = false
			camera_distance = clamp(camera_distance - 6.0, 24.0, TERRAIN_SIZE * 1.75)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			camera_auto_zoom_active = false
			camera_auto_zoom_follow_city = false
			camera_distance = clamp(camera_distance + 6.0, 24.0, TERRAIN_SIZE * 1.75)
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
			var pan_limit: float = TERRAIN_SIZE * 0.5 - 8.0
			camera_target.x = clamp(camera_target.x, -pan_limit, pan_limit)
			camera_target.z = clamp(camera_target.z, -pan_limit, pan_limit)
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
	if pending_action == "missile":
		if _world_year() < MISSILE_UNLOCK_YEAR:
			_log("Missiles are not available before 1945. Use the era skipper to test modern warfare.")
			pending_action = ""
			_refresh_ui()
			return
		if controlled_city < 0 or controlled_city >= cities.size():
			_log("Take control of a city before launching missiles.")
			pending_action = ""
			_refresh_ui()
			return
		var nearby_city_id: int = _find_city_at(world_position, 8.0)
		_launch_missile_at(controlled_city, world_position, nearby_city_id)
		pending_action = ""
		_refresh_ui()
		return
	if pending_action != "":
		var target_id: int = _find_city_at(world_position, 5.5)
		if target_id < 0:
			_log("Choose a target city. Click close to its town centre.")
			return
		if controlled_city < 0 or controlled_city >= cities.size():
			_log("Take control of a city before issuing orders.")
			pending_action = ""
			return
		if target_id == controlled_city:
			_log("That city cannot attack itself.")
			pending_action = ""
			return
		match pending_action:
			"army":
				_launch_army(controlled_city, target_id, false)
			"peace":
				_make_peace(controlled_city, target_id)
		pending_action = ""
		_refresh_ui()
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
	var step_size: float = 0.70
	var previous_t: float = 0.0
	var previous_difference: float = 0.0
	var was_inside: bool = false
	for step_index in range(1, 1401):
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
			if city_id < 0:
				city_id = _find_city_in_territory(world_position)
			if city_id >= 0:
				selected_city = city_id
				_request_city_camera_zoom(city_id, true)
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


func _find_city_in_territory(point: Vector3) -> int:
	var cell := Vector2i(roundi(point.x / TERRITORY_CELL_SIZE), roundi(point.z / TERRITORY_CELL_SIZE))
	for city_id in range(cities.size()):
		var city_cells: Dictionary = cities[city_id].get("territory_cells", {})
		if city_cells.has(cell):
			return city_id
	return -1


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
	for car_index in range(cars.size()):
		var car: Dictionary = cars[car_index]
		var car_position: Vector3 = car["pos"]
		car_position.y = _height_at(car_position.x, car_position.z)
		car["pos"] = car_position
		var car_node: Node3D = car["node"]
		if is_instance_valid(car_node):
			car_node.position = car_position
		var waypoint: Vector3 = car["waypoint"]
		waypoint.y = _height_at(waypoint.x, waypoint.z)
		car["waypoint"] = waypoint
		cars[car_index] = car
	for city in cities:
		var p: Vector3 = city["pos"]
		p.y = _height_at(p.x, p.z)
		city["pos"] = p
		if is_instance_valid(city["node"]):
			city["node"].position = p
		for house in city["houses"]:
			if is_instance_valid(house):
				house.position.y = _height_at(p.x + house.position.x, p.z + house.position.z) - p.y
	for city_id in range(cities.size()):
		_refresh_city_territory(city_id)
		_rebuild_city_roads(city_id)
	for army in armies:
		var p: Vector3 = army["pos"]
		p.y = _height_at(p.x, p.z)
		army["pos"] = p
		if is_instance_valid(army["node"]):
			army["node"].position = p


func _scatter_world_resources() -> void:
	# Spread resource clusters over land that isn't already claimed by the
	# starter towns. Forest patches, food clearings, and stone deposits make
	# the continents feel inhabited beyond the initial city centres.
	var resources_before: int = resources.size()
	for patch_index in range(30):
		var patch_center := Vector3.ZERO
		var found_land: bool = false
		for attempt in range(24):
			var x: float = randf_range(-TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			var z: float = randf_range(-TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			if _height_at(x, z) > WATER_LEVEL + 0.65:
				patch_center = _surface_position(x, z)
				found_land = true
				break
		if not found_land:
			continue

		var patch_roll: float = randf()
		for item_index in range(randi_range(5, 9)):
			var angle: float = randf() * TAU
			var radius: float = randf_range(1.5, 8.0)
			var p: Vector3 = _surface_position(
				patch_center.x + cos(angle) * radius,
				patch_center.z + sin(angle) * radius
			)
			if _height_at(p.x, p.z) <= WATER_LEVEL + 0.25:
				continue

			var kind: String
			var resource_roll: float = randf()
			if patch_roll < 0.50:
				kind = "tree" if resource_roll < 0.84 else "food"
			elif patch_roll < 0.76:
				kind = "food" if resource_roll < 0.62 else "tree"
			else:
				kind = "stone" if resource_roll < 0.70 else "tree"
			_spawn_resource(p, kind, randi_range(5, 10))

	_log("Scattered %d extra resources in natural patches across the land." % (resources.size() - resources_before))


func _seed_civilizations() -> void:
	# Start across the major continents and a few smaller islands so the map
	# immediately feels like a world with room for competing civilizations.
	var starts: Array[Vector2] = [
		Vector2(-34.0, -24.0),
		Vector2(38.0, -27.0),
		Vector2(3.0, 51.0),
		Vector2(-85.0, 32.0),
		Vector2(85.0, 61.0)
	]
	var populations: Array[int] = [6, 5, 5, 4, 4]
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
		_refresh_city_development(city_id)
	_log("Five city-states are competing to grow across the continents and islands.")


func _create_city(position: Vector3, city_name: String, color: Color) -> int:
	var index: int = cities.size()
	var town := Node3D.new()
	town.name = "City_%s" % city_name.replace(" ", "")
	town.position = position
	add_child(town)
	var road_network := MeshInstance3D.new()
	road_network.name = "RoadNetwork"
	var road_material := _material(Color(0.24, 0.27, 0.28), 0.94)
	road_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	road_network.material_override = road_material
	town.add_child(road_network)
	var sidewalk_network := MeshInstance3D.new()
	sidewalk_network.name = "SidewalkNetwork"
	sidewalk_network.material_override = _material(Color(0.53, 0.54, 0.51), 0.98)
	town.add_child(sidewalk_network)

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
	var flag_pole := _add_mesh(town, flag_pole_mesh, _material(Color(0.82, 0.82, 0.73)), Vector3(0.0, 4.6, 0.0))
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.9, 0.45, 0.08)
	var flag := _add_mesh(town, flag_mesh, _material(color), Vector3(0.42, 5.55, 0.0))

	var city_marker_mesh := CylinderMesh.new()
	city_marker_mesh.top_radius = 0.8
	city_marker_mesh.bottom_radius = 1.05
	city_marker_mesh.height = 0.20
	city_marker_mesh.radial_segments = 8
	var far_marker := _add_mesh(town, city_marker_mesh, _material(color.lightened(0.15)), Vector3(0.0, 0.16, 0.0))
	far_marker.name = "DistantCityMarker"
	far_marker.visible = false

	var zone_fill := MeshInstance3D.new()
	zone_fill.name = "TerritoryFill_%s" % city_name.replace(" ", "")
	zone_fill.material_override = _territory_material(color, 0.13)
	add_child(zone_fill)
	var zone_border := MeshInstance3D.new()
	zone_border.name = "TerritoryBorder_%s" % city_name.replace(" ", "")
	zone_border.material_override = _territory_material(color.lightened(0.18), 0.90)
	add_child(zone_border)

	var city_label := Label3D.new()
	city_label.text = "%s\nPOP 0" % city_name
	city_label.position = Vector3(0.0, 6.5, 0.0)
	city_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	city_label.font_size = 46
	city_label.pixel_size = 0.012
	city_label.outline_size = 8
	city_label.modulate = Color(1.0, 1.0, 1.0)
	town.add_child(city_label)

	var event_marker := Label3D.new()
	event_marker.name = "CityEventMarker"
	event_marker.text = ""
	event_marker.position = Vector3(3.2, 9.0, 0.0)
	event_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	event_marker.font_size = 42
	event_marker.pixel_size = 0.012
	event_marker.outline_size = 10
	event_marker.modulate = Color(1.0, 0.76, 0.28)
	event_marker.visible = false
	town.add_child(event_marker)

	cities.append({
		"name": city_name,
		"pos": position,
		"color": color,
		"node": town,
		"roads": road_network,
		"sidewalks": sidewalk_network,
		"label": city_label,
		"event_marker": event_marker,
		"event_timer": 0.0,
		"far_marker": far_marker,
		"zone_fill": zone_fill,
		"zone_border": zone_border,
		"zone_radius": 0.0,
		"territory_cells": {},
		"next_plot_index": 0,
		"plinth": plinth,
		"body": body,
		"roof": roof,
		"flag_pole": flag_pole,
		"flag": flag,
		"stage": 0,
		"houses": [],
		"development_population": -1,
		"road_grid_min_x": -7.5,
		"road_grid_max_x": 7.5,
		"road_grid_min_z": -7.5,
		"road_grid_max_z": 7.5,
		"owner": index,
		"food": 8.0,
		"wood": 5.0,
		"stone": 3.0,
		"stability": 72.0,
		"security": 44.0,
		"wealth": 12.0,
		"defence_cooldown": 0.0,
		"abandoned": false,
		"abandoned_age": 0.0,
		"abandoned_decay_timer": 8.0,
		"ruined": false,
		"destroyed_building_debt": 0
	})
	return index


func _territory_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	return material


func _territory_cell_is_land(cell: Vector2i) -> bool:
	var x: float = float(cell.x) * TERRITORY_CELL_SIZE
	var z: float = float(cell.y) * TERRITORY_CELL_SIZE
	if absf(x) > TERRAIN_SIZE * 0.49 or absf(z) > TERRAIN_SIZE * 0.49:
		return false
	return _height_at(x, z) > WATER_LEVEL + 0.10


func _schedule_city_territory_refresh() -> void:
	territory_refresh_pending = true


func _refresh_city_territory(city_id: int) -> void:
	# Recalculate all claims so every land tile has one owner and contested
	# boundaries remain shared instead of overlapping circular influence areas.
	if cities.is_empty():
		return
	var claims: Dictionary = {}
	var old_radii: Array[float] = []
	for existing_city in cities:
		old_radii.append(float(existing_city.get("zone_radius", 0.0)))
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	for owner_id in range(cities.size()):
		var city: Dictionary = cities[owner_id]
		var cells: Dictionary = {}
		var frontier: Array[Vector2i] = []
		var centre: Vector3 = city["pos"]
		var centre_cell := Vector2i(roundi(centre.x / TERRITORY_CELL_SIZE), roundi(centre.z / TERRITORY_CELL_SIZE))
		if _territory_cell_is_land(centre_cell):
			cells[centre_cell] = 0
			frontier.append(centre_cell)
		for house in city["houses"]:
			if not is_instance_valid(house):
				continue
			var seed_cell := Vector2i(
				roundi((centre.x + house.position.x) / TERRITORY_CELL_SIZE),
				roundi((centre.z + house.position.z) / TERRITORY_CELL_SIZE)
			)
			if _territory_cell_is_land(seed_cell) and not cells.has(seed_cell):
				cells[seed_cell] = 0
				frontier.append(seed_cell)

		var margin_cells: int = clampi(1 + int(city["houses"].size() / 12), 1, 4)
		for shell in range(1, margin_cells + 1):
			var next_frontier: Array[Vector2i] = []
			for cell in frontier:
				for direction in directions:
					var next_cell: Vector2i = cell + direction
					if cells.has(next_cell) or not _territory_cell_is_land(next_cell):
						continue
					if direction.x != 0 and direction.y != 0 and ((next_cell.x * 7 + next_cell.y * 11 + owner_id + shell) % 5 == 0):
						continue
					cells[next_cell] = shell
					next_frontier.append(next_cell)
			frontier = next_frontier

		for cell_key in cells.keys():
			if not claims.has(cell_key):
				claims[cell_key] = []
			var claimers: Array = claims[cell_key]
			claimers.append(owner_id)
			claims[cell_key] = claimers

	var owners: Dictionary = {}
	for cell_key in claims.keys():
		var cell: Vector2i = cell_key
		var tile_world := Vector2(float(cell.x) * TERRITORY_CELL_SIZE, float(cell.y) * TERRITORY_CELL_SIZE)
		var best_city: int = -1
		var best_score: float = INF
		for candidate_id in claims[cell]:
			var candidate: Dictionary = cities[candidate_id]
			var centre_distance: float = tile_world.distance_to(Vector2(candidate["pos"].x, candidate["pos"].z))
			var house_distance: float = INF
			for house in candidate["houses"]:
				if not is_instance_valid(house):
					continue
				var house_x: float = candidate["pos"].x + house.position.x
				var house_z: float = candidate["pos"].z + house.position.z
				house_distance = minf(house_distance, tile_world.distance_to(Vector2(house_x, house_z)))
			var score: float = minf(centre_distance, house_distance) - float(candidate["houses"].size()) * 0.035
			if score < best_score:
				best_score = score
				best_city = candidate_id
		if best_city >= 0:
			owners[cell] = best_city

	# Build each city's final mask only after all contested cells have an owner.
	for owner_id in range(cities.size()):
		var city: Dictionary = cities[owner_id]
		var owner_cells: Dictionary = {}
		var max_distance: float = 0.0
		for cell_key in owners.keys():
			if int(owners[cell_key]) != owner_id:
				continue
			var cell: Vector2i = cell_key
			owner_cells[cell] = true
			var world_pos := Vector2(float(cell.x) * TERRITORY_CELL_SIZE, float(cell.y) * TERRITORY_CELL_SIZE)
			max_distance = maxf(max_distance, world_pos.distance_to(Vector2(city["pos"].x, city["pos"].z)))
		city["territory_cells"] = owner_cells
		city["zone_area"] = float(owner_cells.size()) * TERRITORY_CELL_SIZE * TERRITORY_CELL_SIZE
		city["zone_radius"] = max_distance
		cities[owner_id] = city
	if selected_city >= 0 and selected_city < cities.size() and float(cities[selected_city].get("zone_radius", 0.0)) > old_radii[selected_city] + 0.25:
		_request_city_camera_zoom(selected_city)
	for owner_id in range(cities.size()):
		_render_city_territory(owner_id, owners)



func _render_city_territory(city_id: int, all_owners: Dictionary) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var cells: Dictionary = city.get("territory_cells", {})
	var fill_surface := SurfaceTool.new()
	fill_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var border_surface := SurfaceTool.new()
	border_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = TERRITORY_CELL_SIZE * 0.5
	var border_offset: float = 0.17 + float(city_id) * 0.002

	for cell_key in cells.keys():
		var cell: Vector2i = cell_key
		var x: float = float(cell.x) * TERRITORY_CELL_SIZE
		var z: float = float(cell.y) * TERRITORY_CELL_SIZE
		var a := Vector3(x - half, _height_at(x - half, z - half) + 0.13, z - half)
		var b := Vector3(x + half, _height_at(x + half, z - half) + 0.13, z - half)
		var c := Vector3(x + half, _height_at(x + half, z + half) + 0.13, z + half)
		var d := Vector3(x - half, _height_at(x - half, z + half) + 0.13, z + half)
		fill_surface.add_vertex(a)
		fill_surface.add_vertex(b)
		fill_surface.add_vertex(c)
		fill_surface.add_vertex(a)
		fill_surface.add_vertex(c)
		fill_surface.add_vertex(d)

		var top_neighbour := cell + Vector2i(0, -1)
		var right_neighbour := cell + Vector2i(1, 0)
		var bottom_neighbour := cell + Vector2i(0, 1)
		var left_neighbour := cell + Vector2i(-1, 0)
		if int(all_owners.get(top_neighbour, -1)) != city_id:
			_add_territory_edge(border_surface, a, b, border_offset)
		if int(all_owners.get(right_neighbour, -1)) != city_id:
			_add_territory_edge(border_surface, b, c, border_offset)
		if int(all_owners.get(bottom_neighbour, -1)) != city_id:
			_add_territory_edge(border_surface, c, d, border_offset)
		if int(all_owners.get(left_neighbour, -1)) != city_id:
			_add_territory_edge(border_surface, d, a, border_offset)

	fill_surface.generate_normals(true)
	border_surface.generate_normals(true)
	var fill_node: MeshInstance3D = city["zone_fill"]
	var border_node: MeshInstance3D = city["zone_border"]
	fill_node.mesh = fill_surface.commit()
	border_node.mesh = border_surface.commit()


func _add_territory_edge(surface: SurfaceTool, start_point: Vector3, end_point: Vector3, y_offset: float) -> void:
	var direction := Vector2(end_point.x - start_point.x, end_point.z - start_point.z)
	var length: float = direction.length()
	if length < 0.01:
		return
	direction /= length
	var side := Vector2(-direction.y, direction.x) * 0.13
	var a := Vector3(start_point.x + side.x, start_point.y + y_offset, start_point.z + side.y)
	var b := Vector3(start_point.x - side.x, start_point.y + y_offset, start_point.z - side.y)
	var c := Vector3(end_point.x + side.x, end_point.y + y_offset, end_point.z + side.y)
	var d := Vector3(end_point.x - side.x, end_point.y + y_offset, end_point.z - side.y)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(b)
	surface.add_vertex(d)
	surface.add_vertex(c)


func _apply_building_era_appearance(city_id: int, year: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var stage: int = int(city.get("stage", 0))
	var era: int = _historical_era_index(year)
	var population: int = int(city.get("population", _city_population(city_id)))
	var wealth: float = float(city.get("wealth", 12.0))
	var pop_band: int = int(population / 15)
	var wealth_band: int = 3 if wealth >= 50.0 else (2 if wealth >= 25.0 else (1 if wealth >= 18.0 else 0))
	for house_index in range((city["houses"] as Array).size()):
		var house: Node3D = city["houses"][house_index]
		if not is_instance_valid(house):
			continue
		if int(house.get_meta("visual_era", -1)) == era and int(house.get_meta("visual_stage", -1)) == stage and int(house.get_meta("visual_pop_band", -1)) == pop_band and int(house.get_meta("visual_wealth_band", -1)) == wealth_band:
			continue
		var original_type: int = int(house.get_meta("base_building_type", house.get_meta("building_type", house_index % 5)))
		var kind: int = original_type
		# Farms give way to urban blocks after industrialisation.
		if year >= 1850 and stage >= 2 and kind == 4:
			kind = 3
		elif year < 1880 and kind >= 5:
			kind = 1 if kind == 5 else 3
		for child in house.get_children():
			child.free()

		var urban: bool = year >= 1780 and stage >= 2
		var skyscraper: bool = false
		var floors: int = 1
		var width: float = 1.7
		var depth: float = 1.55
		var height: float = 1.35
		var wall: Color = Color(0.72, 0.66, 0.55).lerp(city["color"], 0.20)
		var roof_color: Color = city["color"].darkened(0.16)
		if urban:
			width = 2.65 + float(stage) * 0.12
			depth = 2.45 + float(stage) * 0.10
			if year < 1880:
				floors = 2 + int(house_index % 2)
				wall = Color(0.53, 0.39, 0.30).lerp(city["color"], 0.12)
				roof_color = Color(0.29, 0.28, 0.27)
			elif year < 1950:
				floors = 3 + int(house_index % 2)
				wall = Color(0.54, 0.58, 0.58).lerp(city["color"], 0.10)
				roof_color = Color(0.25, 0.31, 0.34)
			else:
				floors = 3 + int(house_index % 3)
				wall = Color(0.57, 0.65, 0.68).lerp(city["color"], 0.08)
				roof_color = Color(0.22, 0.32, 0.38)
			height = float(floors) * (0.78 if year < 1950 else 0.86)
			if (kind in [1, 3, 5, 6] or house_index % 9 == 0) and year >= 1880:
				if year >= 2000 and stage >= 4 and population >= 100 and wealth >= 50.0:
					floors = clampi(17 + int((population - 100) / 55), 17, 30)
					skyscraper = true
				elif year >= 1950 and stage >= 3 and population >= 50 and wealth >= 25.0:
					floors = clampi(8 + int((population - 50) / 18), 8, 17)
					skyscraper = true
				elif stage >= 2 and population >= 30 and wealth >= 18.0:
					floors = clampi(4 + int((population - 30) / 14), 4, 9)
					skyscraper = true
			if skyscraper:
				width = 2.55 if floors < 9 else 3.15
				depth = 2.45 if floors < 9 else 3.0
				height = float(floors) * 0.90
				wall = Color(0.30, 0.43, 0.49) if year < 1950 else Color(0.31, 0.48, 0.56)
		else:
			match kind:
				1:
					height = 2.1
					width = 1.6
					depth = 1.55
				2:
					height = 1.22
					width = 1.8
					wall = wall.darkened(0.12)
				3:
					height = 1.72
					width = 1.75
					depth = 1.65
				4:
					height = 0.62
					width = 1.9
					depth = 1.85
					wall = Color(0.51, 0.42, 0.29)

		var body := BoxMesh.new()
		body.size = Vector3(width, height, depth)
		_add_mesh(house, body, _material(wall), Vector3(0.0, height * 0.5, 0.0))
		if urban:
			# A single combined window surface keeps high-rise models cheap.
			var panes := SurfaceTool.new()
			panes.begin(Mesh.PRIMITIVE_TRIANGLES)
			var pane_w: float = width * 0.16
			var pane_h: float = minf(0.42, height / float(maxi(1, floors)) * 0.46)
			for floor_index in range(maxi(1, floors)):
				var pane_y: float = (float(floor_index) + 0.52) * height / float(maxi(1, floors))
				if pane_y > height - 0.08:
					continue
				for column in range(3):
					var pane_x: float = (float(column) - 1.0) * width * 0.27
					for sign_z in [-1.0, 1.0]:
						var z_face: float = sign_z * (depth * 0.5 + 0.012)
						_add_surface_quad(panes, Vector3(pane_x-pane_w*0.5,pane_y-pane_h*0.5,z_face), Vector3(pane_x+pane_w*0.5,pane_y-pane_h*0.5,z_face), Vector3(pane_x+pane_w*0.5,pane_y+pane_h*0.5,z_face), Vector3(pane_x-pane_w*0.5,pane_y+pane_h*0.5,z_face))
					var side_pane_w: float = depth * 0.16
					var side_offset: float = (float(column) - 1.0) * depth * 0.27
					for sign_x in [-1.0, 1.0]:
						var x_face: float = sign_x * (width * 0.5 + 0.012)
						_add_surface_quad(panes, Vector3(x_face,pane_y-pane_h*0.5,side_offset-side_pane_w*0.5), Vector3(x_face,pane_y-pane_h*0.5,side_offset+side_pane_w*0.5), Vector3(x_face,pane_y+pane_h*0.5,side_offset+side_pane_w*0.5), Vector3(x_face,pane_y+pane_h*0.5,side_offset-side_pane_w*0.5))
			panes.generate_normals(true)
			var windows := MeshInstance3D.new()
			windows.mesh = panes.commit()
			windows.material_override = _material(Color(0.32, 0.62, 0.73) if year < 1950 else Color(0.48, 0.76, 0.85), 0.42)
			house.add_child(windows)
			var flat_roof := BoxMesh.new()
			flat_roof.size = Vector3(width + 0.16, 0.18, depth + 0.16)
			_add_mesh(house, flat_roof, _material(roof_color), Vector3(0.0, height + 0.09, 0.0))
			if skyscraper:
				var crown := BoxMesh.new()
				crown.size = Vector3(width * 0.48, 0.55, depth * 0.48)
				_add_mesh(house, crown, _material(Color(0.22, 0.34, 0.40)), Vector3(0.0, height + 0.42, 0.0))
		elif kind in [0, 1]:
			var roof := CylinderMesh.new()
			roof.top_radius = 0.0
			roof.bottom_radius = width * 0.62
			roof.height = 0.76
			roof.radial_segments = 4
			_add_mesh(house, roof, _material(roof_color), Vector3(0.0, height + 0.38, 0.0))
		else:
			var roof := BoxMesh.new()
			roof.size = Vector3(width + 0.14, 0.14, depth + 0.14)
			_add_mesh(house, roof, _material(roof_color), Vector3(0.0, height + 0.07, 0.0))
			if kind == 2:
				var chimney := CylinderMesh.new()
				chimney.top_radius = 0.09
				chimney.bottom_radius = 0.12
				chimney.height = 0.54
				_add_mesh(house, chimney, _material(Color(0.35, 0.28, 0.24)), Vector3(width * 0.28, height + 0.38, 0.0))
			elif kind == 4:
				for crop_index in range(3):
					var crop := BoxMesh.new()
					crop.size = Vector3(width * 0.72, 0.10, 0.13)
					_add_mesh(house, crop, _material(Color(0.28, 0.54, 0.23)), Vector3(0.0, height + 0.18, (float(crop_index) - 1.0) * 0.42))
		var door := BoxMesh.new()
		door.size = Vector3(0.22, 0.42, 0.045)
		_add_mesh(house, door, _material(Color(0.23, 0.16, 0.11)), Vector3(0.0, 0.22, depth * 0.5 + 0.03))
		house.set_meta("building_type", kind)
		house.set_meta("visual_era", era)
		house.set_meta("visual_stage", stage)
		house.set_meta("visual_pop_band", pop_band)
		house.set_meta("visual_wealth_band", wealth_band)
		house.set_meta("building_height", height * house.scale.y)
		house.set_meta("is_skyscraper", skyscraper)


func _add_surface_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)


func _city_stage_for_population(population: int) -> int:
	if population >= 75:
		return 4
	if population >= 40:
		return 3
	if population >= 24:
		return 2
	if population >= 12:
		return 1
	return 0


func _city_stage_name(stage: int) -> String:
	match stage:
		1:
			return "TOWN"
		2:
			return "CITY"
		3:
			return "METROPOLIS"
		4:
			return "MEGACITY"
		_:
			return "VILLAGE"


func _refresh_city_development(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var population: int = _city_population(city_id)
	var previous_stage: int = int(city.get("stage", 0))
	var next_stage: int = previous_stage if population <= 0 else _city_stage_for_population(population)
	city["stage"] = next_stage
	city["population"] = population
	city["development_population"] = population
	cities[city_id] = city
	var stage_changed: bool = next_stage != previous_stage
	if stage_changed:
		_apply_city_stage_appearance(city_id)
		if next_stage > previous_stage:
			_log("%s developed into a %s." % [city["name"], _city_stage_name(next_stage).to_lower()])
	var houses_changed: bool = _sync_city_buildings(city_id) if population > 0 and not bool(city.get("ruined", false)) else false
	if population > 0 and not bool(city.get("ruined", false)):
		# Cached era/population/wealth bands make this check cheap unless a building needs to change.
		_apply_building_era_appearance(city_id, _world_year())
	if houses_changed or stage_changed:
		_schedule_city_territory_refresh()
	city = cities[city_id]
	if is_instance_valid(city["label"]):
		var status: String = "RUINS" if bool(city.get("ruined", false)) else ("ABANDONED" if population <= 0 else _city_stage_name(next_stage))
		city["label"].text = "%s\n%s | POP %d" % [city["name"], status, population]
		city["label"].modulate = Color(0.66, 0.70, 0.72) if population <= 0 else Color.WHITE
	cities[city_id] = city


func _apply_city_stage_appearance(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var stage: int = int(city.get("stage", 0))
	var plinth := city["plinth"] as MeshInstance3D
	if is_instance_valid(plinth):
		var plinth_mesh := plinth.mesh as BoxMesh
		if plinth_mesh != null:
			var footprint: float = 3.2 + float(stage) * 0.85
			plinth_mesh.size = Vector3(footprint, 0.45, footprint)
	var body := city["body"] as MeshInstance3D
	var body_top: float = 2.2
	if is_instance_valid(body):
		var body_mesh := body.mesh as BoxMesh
		if body_mesh != null:
			var width: float = 2.15 + float(stage) * 0.36
			var height: float = 1.9 + float(stage) * 0.38
			body_mesh.size = Vector3(width, height, width)
			body.position = Vector3(0.0, 0.30 + height * 0.5, 0.0)
			body_top = 0.30 + height
	var roof := city["roof"] as MeshInstance3D
	var roof_top: float = body_top + 1.35
	if is_instance_valid(roof):
		var roof_mesh := roof.mesh as CylinderMesh
		if roof_mesh != null:
			roof_mesh.bottom_radius = 1.65 + float(stage) * 0.28
			roof_mesh.height = 1.35 + float(stage) * 0.16
			roof.position = Vector3(0.0, body_top + roof_mesh.height * 0.5, 0.0)
			roof_top = body_top + roof_mesh.height
	var flag_pole := city["flag_pole"] as MeshInstance3D
	if is_instance_valid(flag_pole):
		flag_pole.position = Vector3(0.0, roof_top + 1.075, 0.0)
	var flag := city["flag"] as MeshInstance3D
	if is_instance_valid(flag_pole) and is_instance_valid(flag):
		flag.position = Vector3(0.42, flag_pole.position.y + 0.95, 0.0)
	var label := city["label"] as Label3D
	if is_instance_valid(flag_pole) and is_instance_valid(label):
		label.position = Vector3(0.0, flag_pole.position.y + 1.9, 0.0)
	for house in city["houses"]:
		if is_instance_valid(house):
			house.scale = Vector3.ONE * (1.0 + float(stage) * 0.07)


func _spiral_grid_offset(index: int) -> Vector2i:
	# A deterministic square spiral gives cities a grid plan without making
	# every neighbourhood a perfect rectangular spreadsheet.
	var x: int = 0
	var z: int = 0
	var direction := Vector2i(1, 0)
	var segment_length: int = 1
	var segment_steps: int = 0
	var segments_at_length: int = 0
	for step in range(index + 1):
		x += direction.x
		z += direction.y
		segment_steps += 1
		if segment_steps >= segment_length:
			segment_steps = 0
			direction = Vector2i(-direction.y, direction.x)
			segments_at_length += 1
			if segments_at_length >= 2:
				segments_at_length = 0
				segment_length += 1
	return Vector2i(x, z)


func _sync_city_buildings(city_id: int) -> bool:
	if city_id < 0 or city_id >= cities.size() or _city_population(city_id) <= 0 or bool(cities[city_id].get("ruined", false)):
		return false
	var city: Dictionary = cities[city_id]
	var population: int = _city_population(city_id)
	var stage: int = int(city.get("stage", 0))
	var theoretical_houses: int = min(MAX_CITY_HOUSES, max(1, 1 + int(population / 3) + stage * 2))
	var destroyed_building_debt: int = maxi(0, int(city.get("destroyed_building_debt", 0)))
	var desired_houses: int = maxi(0, theoretical_houses - destroyed_building_debt)
	var houses: Array = city["houses"]
	var houses_before: int = houses.size()
	var plot_index: int = int(city.get("next_plot_index", houses.size()))
	while houses.size() < desired_houses and houses.size() < MAX_CITY_HOUSES:
		var offset_x: float = 0.0
		var offset_z: float = 0.0
		var found_building_site: bool = false
		var chosen_plot_index: int = plot_index
		# Try the next parcels in the grid spiral. Coastal sites are skipped,
		# preserving street alignment instead of bending the whole district.
		for attempt in range(64):
			var plot: Vector2i = _spiral_grid_offset(plot_index)
			# Street grid is spaced out; buildings sit inside the blocks.
			offset_x = float(plot.x) * 7.5 + 2.35 + randf_range(-0.45, 0.45)
			offset_z = float(plot.y) * 7.5 + 2.35 + randf_range(-0.45, 0.45)
			var candidate_x: float = city["pos"].x + offset_x
			var candidate_z: float = city["pos"].z + offset_z
			var inside_world: bool = abs(candidate_x) < TERRAIN_SIZE * 0.47 and abs(candidate_z) < TERRAIN_SIZE * 0.47
			var on_land: bool = inside_world and _height_at(candidate_x, candidate_z) > WATER_LEVEL + 0.22
			var overlaps_existing: bool = false
			if on_land:
				for existing_house in houses:
					if not is_instance_valid(existing_house):
						continue
					var existing_offset := Vector2(existing_house.position.x, existing_house.position.z)
					if existing_offset.distance_to(Vector2(offset_x, offset_z)) < 3.0:
						overlaps_existing = true
						break
			if on_land and not overlaps_existing:
				found_building_site = true
				chosen_plot_index = plot_index
				break
			plot_index += 1
		if not found_building_site:
			break
		plot_index = chosen_plot_index + 1
		var terrain_delta: float = _height_at(city["pos"].x + offset_x, city["pos"].z + offset_z) - city["pos"].y
		var house := Node3D.new()
		house.scale = Vector3.ONE * (1.0 + float(stage) * 0.07)
		house.position = Vector3(offset_x, terrain_delta, offset_z)
		city["node"].add_child(house)

		var building_type: int = house_index_to_building_type(houses.size(), stage)
		house.set_meta("building_type", building_type)
		house.set_meta("base_building_type", building_type)
		house.set_meta("plot_index", chosen_plot_index)
		houses.append(house)
	city["houses"] = houses
	city["next_plot_index"] = plot_index
	cities[city_id] = city
	var houses_changed: bool = houses.size() != houses_before
	if houses_changed:
		_rebuild_city_roads(city_id)
		_apply_building_era_appearance(city_id, _world_year())
	return houses_changed


func house_index_to_building_type(index: int, stage: int) -> int:
	var year: int = _world_year()
	var kind: int = index % 5
	if year >= 1850 and stage >= 2 and kind == 4:
		kind = 3
	if year >= 1880 and stage >= 2 and kind != 4 and index % 5 == 1:
		kind = 5
	if year >= 1950 and stage >= 3 and kind != 4 and index % 7 == 2:
		kind = 6
	return kind


func _add_road_segment(surface: SurfaceTool, city_position: Vector3, from_point: Vector2, to_point: Vector2, width: float = 0.48) -> void:
	var delta: Vector2 = to_point - from_point
	var distance: float = delta.length()
	if distance < 1.0:
		return
	var direction: Vector2 = delta / distance
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	var start_point: Vector2 = from_point + direction * 1.05
	var finish_point: Vector2 = to_point - direction * 1.05
	var segment_count: int = max(2, int(ceil(distance / 5.0)))
	var previous_left := Vector3.ZERO
	var previous_right := Vector3.ZERO
	for segment in range(segment_count + 1):
		var t: float = float(segment) / float(segment_count)
		var center_line: Vector2 = start_point.lerp(finish_point, t)
		var left_xz: Vector2 = center_line + side
		var right_xz: Vector2 = center_line - side
		var left := Vector3(left_xz.x, _height_at(city_position.x + left_xz.x, city_position.z + left_xz.y) - city_position.y + 0.10, left_xz.y)
		var right := Vector3(right_xz.x, _height_at(city_position.x + right_xz.x, city_position.z + right_xz.y) - city_position.y + 0.10, right_xz.y)
		if segment > 0:
			surface.add_vertex(previous_left)
			surface.add_vertex(previous_right)
			surface.add_vertex(left)
			surface.add_vertex(previous_right)
			surface.add_vertex(right)
			surface.add_vertex(left)
		previous_left = left
		previous_right = right


func _rebuild_city_roads(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var road_node: MeshInstance3D = city["roads"]
	var sidewalk_node: MeshInstance3D = city.get("sidewalks") as MeshInstance3D
	if not is_instance_valid(road_node):
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sidewalk_surface := SurfaceTool.new()
	sidewalk_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var city_position: Vector3 = city["pos"]
	var houses: Array = city["houses"]
	if houses.is_empty():
		road_node.mesh = null
		if is_instance_valid(sidewalk_node):
			sidewalk_node.mesh = null
		city["road_grid_min_x"] = -7.5
		city["road_grid_max_x"] = 7.5
		city["road_grid_min_z"] = -7.5
		city["road_grid_max_z"] = 7.5
		cities[city_id] = city
		return
	var min_x: float = 0.0
	var max_x: float = 0.0
	var min_z: float = 0.0
	var max_z: float = 0.0
	for house in houses:
		if not is_instance_valid(house):
			continue
		min_x = minf(min_x, house.position.x - 3.0)
		max_x = maxf(max_x, house.position.x + 3.0)
		min_z = minf(min_z, house.position.z - 3.0)
		max_z = maxf(max_z, house.position.z + 3.0)
	var x: float = floor(min_x / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var last_x: float = ceil(max_x / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var z: float = floor(min_z / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var last_z: float = ceil(max_z / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	city["road_grid_min_x"] = ceil(min_x / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	city["road_grid_max_x"] = floor(max_x / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	city["road_grid_min_z"] = ceil(min_z / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	city["road_grid_max_z"] = floor(max_z / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	if float(city["road_grid_min_x"]) > float(city["road_grid_max_x"]):
		city["road_grid_min_x"] = 0.0
		city["road_grid_max_x"] = 0.0
	if float(city["road_grid_min_z"]) > float(city["road_grid_max_z"]):
		city["road_grid_min_z"] = 0.0
		city["road_grid_max_z"] = 0.0
	cities[city_id] = city
	while x <= last_x:
		_add_road_segment(surface, city_position, Vector2(x, min_z), Vector2(x, max_z), 0.62)
		_add_road_segment(sidewalk_surface, city_position, Vector2(x - 1.05, min_z), Vector2(x - 1.05, max_z), 0.48)
		_add_road_segment(sidewalk_surface, city_position, Vector2(x + 1.05, min_z), Vector2(x + 1.05, max_z), 0.48)
		x += ROAD_GRID_SIZE
	while z <= last_z:
		_add_road_segment(surface, city_position, Vector2(min_x, z), Vector2(max_x, z), 0.62)
		_add_road_segment(sidewalk_surface, city_position, Vector2(min_x, z - 1.05), Vector2(max_x, z - 1.05), 0.48)
		_add_road_segment(sidewalk_surface, city_position, Vector2(min_x, z + 1.05), Vector2(max_x, z + 1.05), 0.48)
		z += ROAD_GRID_SIZE
	for i in range(0, houses.size(), 9):
		var house: Node3D = houses[i]
		if is_instance_valid(house):
			var p := Vector2(house.position.x, house.position.z)
			var q := p + Vector2(3.75, 3.75)
			if q.x <= max_x and q.y <= max_z:
				_add_road_segment(surface, city_position, p, q, 0.30)
	surface.generate_normals(true)
	road_node.mesh = surface.commit()
	if is_instance_valid(sidewalk_node):
		sidewalk_surface.generate_normals(true)
		sidewalk_node.mesh = sidewalk_surface.commit()


func _seed_resources_around(center: Vector3) -> void:
	for i in range(18):
		var resource_position := Vector3.ZERO
		var found_land: bool = false
		for attempt in range(12):
			var angle: float = randf() * TAU
			var radius: float = randf_range(6.0, 14.0)
			var candidate: Vector3 = _surface_position(center.x + cos(angle) * radius, center.z + sin(angle) * radius)
			if _height_at(candidate.x, candidate.z) > WATER_LEVEL + 0.18:
				resource_position = candidate
				found_land = true
				break
		if not found_land:
			continue
		var roll: float = randf()
		if roll < 0.48:
			_spawn_resource(resource_position, "tree", 8)
		elif roll < 0.73:
			_spawn_resource(resource_position, "food", 8)
		else:
			_spawn_resource(resource_position, "stone", 8)


func _create_roblox_character(parent: Node, garment: Color, skin: Color) -> Dictionary:
	# A chunky citizen silhouette with shared meshes/materials; omit separate
	# eyes, mouth, hands, and feet to keep late-game render cost manageable.
	var human := Node3D.new()
	human.name = "RobloxStyleCitizen"
	parent.add_child(human)
	_add_mesh(human, _cached_box_mesh(Vector3(0.48, 0.52, 0.28)), _material(garment), Vector3(0.0, 0.87, 0.0))
	_add_mesh(human, _cached_box_mesh(Vector3(0.36, 0.36, 0.36)), _material(skin), Vector3(0.0, 1.34, 0.0))
	_add_mesh(human, _cached_box_mesh(Vector3(0.39, 0.12, 0.39)), _material(Color(0.22, 0.17, 0.13)), Vector3(0.0, 1.56, 0.0))
	var left_arm := Node3D.new()
	left_arm.name = "LeftArmPivot"
	left_arm.position = Vector3(-0.31, 1.08, 0.0)
	human.add_child(left_arm)
	_add_mesh(left_arm, _cached_box_mesh(Vector3(0.16, 0.46, 0.18)), _material(garment), Vector3(0.0, -0.23, 0.0))
	var right_arm := Node3D.new()
	right_arm.name = "RightArmPivot"
	right_arm.position = Vector3(0.31, 1.08, 0.0)
	human.add_child(right_arm)
	_add_mesh(right_arm, _cached_box_mesh(Vector3(0.16, 0.46, 0.18)), _material(garment), Vector3(0.0, -0.23, 0.0))
	var left_leg := Node3D.new()
	left_leg.name = "LeftLegPivot"
	left_leg.position = Vector3(-0.13, 0.61, 0.0)
	human.add_child(left_leg)
	_add_mesh(left_leg, _cached_box_mesh(Vector3(0.19, 0.46, 0.20)), _material(Color(0.18, 0.24, 0.31)), Vector3(0.0, -0.23, 0.0))
	var right_leg := Node3D.new()
	right_leg.name = "RightLegPivot"
	right_leg.position = Vector3(0.13, 0.61, 0.0)
	human.add_child(right_leg)
	_add_mesh(right_leg, _cached_box_mesh(Vector3(0.19, 0.46, 0.20)), _material(Color(0.18, 0.24, 0.31)), Vector3(0.0, -0.23, 0.0))
	if citizen_infection_marker_mesh == null:
		citizen_infection_marker_mesh = SphereMesh.new()
		citizen_infection_marker_mesh.radius = 0.13
		citizen_infection_marker_mesh.height = 0.26
	if citizen_infection_marker_material == null:
		citizen_infection_marker_material = StandardMaterial3D.new()
		citizen_infection_marker_material.albedo_color = Color(0.52, 1.0, 0.28)
		citizen_infection_marker_material.emission_enabled = true
		citizen_infection_marker_material.emission = Color(0.35, 1.0, 0.15)
		citizen_infection_marker_material.emission_energy_multiplier = 1.3
	var infection_marker := MeshInstance3D.new()
	infection_marker.mesh = citizen_infection_marker_mesh
	infection_marker.material_override = citizen_infection_marker_material
	infection_marker.position = Vector3(0.0, 1.84, 0.0)
	infection_marker.visible = false
	human.add_child(infection_marker)
	return {
		"node": human,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"left_leg": left_leg,
		"right_leg": right_leg,
		"infection_marker": infection_marker
	}


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
	var garment: Color
	if assigned_city >= 0 and assigned_city < cities.size():
		garment = cities[assigned_city]["color"].lightened(0.08)
	else:
		garment = city_colors[randi_range(0, city_colors.size() - 1)].darkened(0.12)
	var skin_palette: Array[Color] = [
		Color(0.92, 0.74, 0.60), Color(0.71, 0.48, 0.32),
		Color(0.84, 0.62, 0.45), Color(0.96, 0.82, 0.68)
	]
	var visuals: Dictionary = _create_roblox_character(self, garment, skin_palette[randi_range(0, skin_palette.size() - 1)])
	var human: Node3D = visuals["node"]
	var p: Vector3 = position
	var home_offset: Vector2 = Vector2.ZERO
	if assigned_city >= 0 and assigned_city < cities.size():
		var city_position: Vector3 = cities[assigned_city]["pos"]
		var radius_limit: float = clampf(10.0 + float(cities[assigned_city]["houses"].size()) * 0.20 + float(cities[assigned_city].get("stage", 0)) * 2.0, 12.0, 38.0)
		for home_attempt in range(8):
			var home_angle: float = randf() * TAU
			var home_radius: float = randf_range(4.0, radius_limit)
			var candidate_offset := Vector2(cos(home_angle), sin(home_angle)) * home_radius
			if _height_at(city_position.x + candidate_offset.x, city_position.z + candidate_offset.y) > WATER_LEVEL + 0.20:
				home_offset = candidate_offset
				break
	p.y = _height_at(p.x, p.z)
	human.position = p
	people.append({
		"node": human,
		"pos": p,
		"city_id": assigned_city,
		"home_offset": home_offset,
		"target": p,
		"activity": "wandering",
		"activity_timer": 0.0,
		"indoor_house": null,
		"vehicle_node": null,
		"walk_timer": randf_range(0.4, 2.2),
		"walk_phase": randf() * TAU,
		"alive": true,
		"infected": false,
		"infection_marker": visuals["infection_marker"],
		"left_arm": visuals["left_arm"],
		"right_arm": visuals["right_arm"],
		"left_leg": visuals["left_leg"],
		"right_leg": visuals["right_leg"],
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
	# City blocks, citizens, and debris reuse a small palette instead of duplicating resources.
	var key: String = "%s|%.3f" % [color.to_html(true), roughness]
	if _material_cache.has(key):
		var cached: StandardMaterial3D = _material_cache[key] as StandardMaterial3D
		if is_instance_valid(cached):
			return cached
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_material_cache[key] = material
	return material


func _cached_box_mesh(size: Vector3) -> BoxMesh:
	var key: String = "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if _box_mesh_cache.has(key):
		var cached: BoxMesh = _box_mesh_cache[key] as BoxMesh
		if is_instance_valid(cached):
			return cached
	var mesh := BoxMesh.new()
	mesh.size = size
	_box_mesh_cache[key] = mesh
	return mesh


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, local_position: Vector3 = Vector3.ZERO, local_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.scale = local_scale
	parent.add_child(instance)
	return instance


func _update_people(delta: float) -> void:
	var animate_citizens: bool = camera_distance <= 72.0 and people.size() <= 300
	for i in range(people.size()):
		var person: Dictionary = people[i]
		if not bool(person.get("alive", true)):
			continue
		var node: Node3D = person["node"]
		var position: Vector3 = person["pos"]
		var activity: String = str(person.get("activity", "wandering"))
		var activity_timer: float = float(person.get("activity_timer", 0.0))
		if activity == "indoors":
			activity_timer -= delta
			if is_instance_valid(node):
				node.visible = false
			if activity_timer <= 0.0:
				var indoor_house: Variant = person.get("indoor_house", null)
				if indoor_house is Node3D and is_instance_valid(indoor_house):
					position = indoor_house.global_position + Vector3(0.0, 0.0, 1.65)
				position = _surface_position(position.x, position.z)
				person["pos"] = position
				person["target"] = position
				last_detail_signature = ""
				person["activity"] = "wandering"
				person["activity_timer"] = 0.0
				person["indoor_house"] = null
				person["walk_timer"] = 0.0
				if is_instance_valid(node):
					node.position = position
					node.visible = true
			else:
				person["activity_timer"] = activity_timer
			people[i] = person
			continue

		if activity == "riding" or activity == "boarding":
			var vehicle: Variant = person.get("vehicle_node", null)
			if not (vehicle is Node3D) or not is_instance_valid(vehicle):
				if activity == "riding":
					_adjust_car_occupancy(vehicle, -1)
				person["activity"] = "wandering"
				person["vehicle_node"] = null
				person["activity_timer"] = 0.0
				person["walk_timer"] = 0.0
				people[i] = person
				continue
			var vehicle_position: Vector3 = vehicle.global_position
			if activity == "boarding":
				var boarding_distance: float = Vector2(position.x - vehicle_position.x, position.z - vehicle_position.z).length()
				if boarding_distance <= 1.55:
					person["activity"] = "riding"
					last_detail_signature = ""
					person["activity_timer"] = randf_range(5.0, 15.0)
					_adjust_car_occupancy(vehicle, 1)
					if is_instance_valid(node):
						node.visible = false
				else:
					person["target"] = vehicle_position
					position = position.move_toward(Vector3(vehicle_position.x, position.y, vehicle_position.z), delta * 2.6)
					position.y = _height_at(position.x, position.z)
					person["pos"] = position
					if is_instance_valid(node):
						node.position = position
						node.visible = true
			else:
				activity_timer -= delta
				position = vehicle_position
				person["pos"] = position
				person["activity_timer"] = activity_timer
				if is_instance_valid(node):
					node.visible = false
				if activity_timer <= 0.0:
					_adjust_car_occupancy(vehicle, -1)
					position = _surface_position(vehicle_position.x + randf_range(-1.8, 1.8), vehicle_position.z + randf_range(-1.8, 1.8))
					person["pos"] = position
					person["target"] = position
					last_detail_signature = ""
					person["activity"] = "wandering"
					person["activity_timer"] = 0.0
					person["vehicle_node"] = null
					person["walk_timer"] = 0.0
					if is_instance_valid(node):
						node.position = position
						node.visible = true
			people[i] = person
			continue

		if activity == "cleanup_walk" or activity == "cleaning":
			var cleanup_id: int = int(person.get("cleanup_rubble_id", -1))
			var cleanup_node: Node3D = _get_rubble_node(cleanup_id)
			if not is_instance_valid(cleanup_node):
				_reserve_cleanup_rubble(cleanup_id, false)
				person["activity"] = "wandering"
				person["cleanup_rubble_id"] = -1
				person["activity_timer"] = 0.0
				person["walk_timer"] = 0.0
				last_detail_signature = ""
				people[i] = person
				continue
			var cleanup_position: Vector3 = cleanup_node.global_position
			var cleanup_distance: float = Vector2(position.x - cleanup_position.x, position.z - cleanup_position.z).length()
			if activity == "cleanup_walk":
				if cleanup_distance <= 1.5:
					person["activity"] = "cleaning"
					person["activity_timer"] = 0.0
					if is_instance_valid(node):
						node.rotation.y = randf() * TAU
				else:
					position = position.move_toward(Vector3(cleanup_position.x, position.y, cleanup_position.z), delta * 2.0)
					position.y = _height_at(position.x, position.z)
					person["pos"] = position
					if is_instance_valid(node):
						node.position = position
						node.visible = true
			else:
				person["activity_timer"] = float(person.get("activity_timer", 0.0)) + delta
				if float(person["activity_timer"]) >= 5.0:
					_clear_rubble_by_id(cleanup_id)
					person["activity"] = "wandering"
					person["cleanup_rubble_id"] = -1
					person["activity_timer"] = 0.0
					person["walk_timer"] = 0.0
					last_detail_signature = ""
				elif is_instance_valid(node):
					node.visible = true
			people[i] = person
			continue
		person["walk_timer"] = float(person.get("walk_timer", 1.0)) - delta
		var target: Vector3 = person["target"]
		var distance_to_target: float = Vector2(position.x - target.x, position.z - target.z).length()
		if activity == "entering":
			var target_house: Variant = person.get("indoor_house", null)
			if not (target_house is Node3D) or not is_instance_valid(target_house):
				person["activity"] = "wandering"
				person["indoor_house"] = null
				person["walk_timer"] = 0.0
			elif distance_to_target <= 0.9:
				person["activity"] = "indoors"
				last_detail_signature = ""
				person["activity_timer"] = randf_range(8.0, 28.0)
				position = target
				person["pos"] = position
				if is_instance_valid(node):
					node.visible = false
				people[i] = person
				continue

		if activity != "entering" and (person["walk_timer"] <= 0.0 or distance_to_target < 0.55):
			var city_id: int = int(person.get("city_id", -1))
			var destination_center: Vector3 = position
			var local_wander_radius: float = 6.0
			if city_id >= 0 and city_id < cities.size():
				var city: Dictionary = cities[city_id]
				var home_offset: Vector2 = person.get("home_offset", Vector2.ZERO)
				destination_center = city["pos"] + Vector3(home_offset.x, 0.0, home_offset.y)
				local_wander_radius = clampf(6.0 + float(city["houses"].size()) * 0.06, 7.0, 14.0)
			var next_target: Vector3 = _choose_citizen_street_target(city_id, destination_center, local_wander_radius)
			var selected_house: Node3D = null
			var selected_vehicle: Node3D = null
			var selected_rubble_id: int = -1
			if city_id >= 0 and city_id < cities.size() and not rubble_nodes.is_empty() and randf() < 0.24:
				selected_rubble_id = _find_nearby_cleanup_rubble(position, 22.0)
				if selected_rubble_id >= 0:
					var rubble_target: Node3D = _get_rubble_node(selected_rubble_id)
					if is_instance_valid(rubble_target):
						next_target = rubble_target.global_position
					else:
						selected_rubble_id = -1
			if selected_rubble_id >= 0:
				pass
			elif city_id >= 0 and city_id < cities.size() and randf() < 0.16:
				var candidates: Array[Node3D] = []
				for house in cities[city_id]["houses"]:
					if is_instance_valid(house) and int(house.get_meta("base_building_type", house.get_meta("building_type", 0))) in [0, 1, 2, 3]:
						candidates.append(house)
				if not candidates.is_empty():
					selected_house = candidates[randi_range(0, candidates.size() - 1)]
					next_target = _surface_position(selected_house.global_position.x, selected_house.global_position.z + 1.65)
			elif city_id >= 0 and city_id < cities.size() and _world_year() >= 1900 and randf() < 0.12:
				var best_distance: float = 24.0
				for car_data in cars:
					if int(car_data["city_id"]) != city_id or int(car_data.get("occupied", 0)) >= int(car_data.get("capacity", 2)):
						continue
					var car_node: Node3D = car_data["node"]
					if not is_instance_valid(car_node):
						continue
					var candidate_distance: float = Vector2(car_node.position.x - position.x, car_node.position.z - position.z).length()
					if candidate_distance < best_distance:
						best_distance = candidate_distance
						selected_vehicle = car_node
				if is_instance_valid(selected_vehicle):
					next_target = selected_vehicle.global_position
			person["target"] = next_target
			person["walk_timer"] = randf_range(2.0, 5.0)
			if selected_rubble_id >= 0:
				person["activity"] = "cleanup_walk"
				person["cleanup_rubble_id"] = selected_rubble_id
				person["walk_timer"] = 30.0
				_reserve_cleanup_rubble(selected_rubble_id, true)
			elif is_instance_valid(selected_house):
				person["activity"] = "entering"
				person["indoor_house"] = selected_house
			elif is_instance_valid(selected_vehicle):
				person["activity"] = "boarding"
				person["vehicle_node"] = selected_vehicle
			target = next_target
		else:
			target = person["target"]

		var horizontal_target := Vector3(target.x, position.y, target.z)
		var distance_before_move: float = Vector2(position.x - target.x, position.z - target.z).length()
		var is_walking: bool = distance_before_move > 0.45
		position = position.move_toward(horizontal_target, delta * 2.2)
		position.y = _height_at(position.x, position.z)
		person["pos"] = position
		if animate_citizens:
			var walk_phase: float = float(person.get("walk_phase", 0.0)) + delta * (7.2 if is_walking else 1.5)
			person["walk_phase"] = walk_phase
			var gait: float = sin(walk_phase) * (0.52 if is_walking else 0.035)
			var left_arm: Node3D = person["left_arm"]
			var right_arm: Node3D = person["right_arm"]
			var left_leg: Node3D = person["left_leg"]
			var right_leg: Node3D = person["right_leg"]
			if is_instance_valid(left_arm):
				left_arm.rotation.x = gait
			if is_instance_valid(right_arm):
				right_arm.rotation.x = -gait
			if is_instance_valid(left_leg):
				left_leg.rotation.x = -gait
			if is_instance_valid(right_leg):
				right_leg.rotation.x = gait
		if is_instance_valid(node):
			node.position = position
			node.visible = activity != "indoors" and activity != "riding"
			if is_walking:
				node.rotation.y = atan2(target.x - position.x, target.z - position.z)
		people[i] = person


func _choose_citizen_street_target(city_id: int, centre: Vector3, radius: float) -> Vector3:
	if city_id >= 0 and city_id < cities.size():
		var city: Dictionary = cities[city_id]
		var min_x: float = float(city.get("road_grid_min_x", -7.5))
		var max_x: float = float(city.get("road_grid_max_x", 7.5))
		var min_z: float = float(city.get("road_grid_min_z", -7.5))
		var max_z: float = float(city.get("road_grid_max_z", 7.5))
		if max_x >= min_x and max_z >= min_z:
			var local_x: float
			var local_z: float
			if randf() < 0.5:
				var x_steps: int = maxi(0, roundi((max_x - min_x) / ROAD_GRID_SIZE))
				local_x = min_x + float(randi_range(0, x_steps)) * ROAD_GRID_SIZE + randf_range(-1.1, 1.1)
				local_z = randf_range(min_z, max_z)
			else:
				var z_steps: int = maxi(0, roundi((max_z - min_z) / ROAD_GRID_SIZE))
				local_z = min_z + float(randi_range(0, z_steps)) * ROAD_GRID_SIZE + randf_range(-1.1, 1.1)
				local_x = randf_range(min_x, max_x)
			var street_x: float = clampf(float(city["pos"].x) + local_x, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			var street_z: float = clampf(float(city["pos"].z) + local_z, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
			if _height_at(street_x, street_z) > WATER_LEVEL + 0.15:
				return _surface_position(street_x, street_z)
	for attempt in range(8):
		var angle: float = randf() * TAU
		var distance: float = randf_range(2.0, radius)
		var x: float = clampf(centre.x + cos(angle) * distance, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
		var z: float = clampf(centre.z + sin(angle) * distance, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
		if _height_at(x, z) > WATER_LEVEL + 0.15:
			return _surface_position(x, z)
	return _surface_position(centre.x, centre.z)


func _adjust_car_occupancy(vehicle: Variant, amount: int) -> void:
	if not (vehicle is Node3D) or not is_instance_valid(vehicle):
		return
	for car_index in range(cars.size()):
		var car: Dictionary = cars[car_index]
		if car.get("node") == vehicle:
			car["occupied"] = clampi(int(car.get("occupied", 0)) + amount, 0, int(car.get("capacity", 2)))
			cars[car_index] = car
			return


func _spawn_car(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size() or cars.size() >= MAX_CARS:
		return
	var city: Dictionary = cities[city_id]
	var city_position: Vector3 = city["pos"]
	var min_x: float = float(city.get("road_grid_min_x", -7.5))
	var max_x: float = float(city.get("road_grid_max_x", 7.5))
	var min_z: float = float(city.get("road_grid_min_z", -7.5))
	var max_z: float = float(city.get("road_grid_max_z", 7.5))
	var x_steps: int = maxi(0, roundi((max_x - min_x) / ROAD_GRID_SIZE))
	var z_steps: int = maxi(0, roundi((max_z - min_z) / ROAD_GRID_SIZE))
	var spawn_position := Vector3.ZERO
	for attempt in range(10):
		var local_x: float = min_x + float(randi_range(0, x_steps)) * ROAD_GRID_SIZE
		var local_z: float = min_z + float(randi_range(0, z_steps)) * ROAD_GRID_SIZE
		spawn_position = _surface_position(city_position.x + local_x, city_position.z + local_z)
		var space_free: bool = true
		for existing_car in cars:
			if int(existing_car["city_id"]) != city_id:
				continue
			var existing_position: Vector3 = existing_car["pos"]
			if Vector2(existing_position.x - spawn_position.x, existing_position.z - spawn_position.z).length() < 4.0:
				space_free = false
				break
		if space_free:
			break
	var paint_colors: Array[Color] = [
		Color(0.76, 0.16, 0.13), Color(0.12, 0.31, 0.72), Color(0.80, 0.81, 0.77),
		Color(0.16, 0.18, 0.20), Color(0.88, 0.58, 0.12), Color(0.22, 0.48, 0.31)
	]
	var car := Node3D.new()
	car.name = "CityCar"
	car.position = spawn_position
	add_child(car)
	_add_mesh(car, _cached_box_mesh(Vector3(1.08, 0.28, 1.90)), _material(paint_colors[randi_range(0, paint_colors.size() - 1)]), Vector3(0.0, 0.38, 0.0))
	_add_mesh(car, _cached_box_mesh(Vector3(0.78, 0.36, 0.82)), _material(Color(0.16, 0.22, 0.26)), Vector3(0.0, 0.66, -0.04))
	_add_mesh(car, _cached_box_mesh(Vector3(0.62, 0.20, 0.035)), _material(Color(0.40, 0.70, 0.82)), Vector3(0.0, 0.70, -0.47))
	var wheel_material: StandardMaterial3D = _material(Color(0.07, 0.075, 0.08))
	var wheel_mesh: BoxMesh = _cached_box_mesh(Vector3(0.20, 0.26, 0.34))
	for wheel_x in [-0.55, 0.55]:
		for wheel_z in [-0.62, 0.62]:
			_add_mesh(car, wheel_mesh, wheel_material, Vector3(wheel_x, 0.19, wheel_z))
	var route: Dictionary = _choose_next_car_waypoint(city_id, spawn_position, Vector2i.ZERO)
	var direction: Vector2i = route["direction"]
	if direction != Vector2i.ZERO:
		car.rotation.y = atan2(-float(direction.x), -float(direction.y))
	var current_count: int = 0
	for existing_car in cars:
		if int(existing_car["city_id"]) == city_id:
			current_count += 1
	cars.append({
		"node": car, "city_id": city_id, "pos": spawn_position,
		"waypoint": route["waypoint"], "direction": direction, "speed": randf_range(3.2, 4.8),
		"occupied": 0, "capacity": 2
	})
	car.visible = camera_distance <= 135.0
	if current_count == 0:
		_log("%s now has motor traffic on its street grid." % city["name"])


func _choose_next_car_waypoint(city_id: int, position: Vector3, previous_direction: Vector2i) -> Dictionary:
	if city_id < 0 or city_id >= cities.size():
		return {"direction": Vector2i.ZERO, "waypoint": position}
	var city: Dictionary = cities[city_id]
	var city_position: Vector3 = city["pos"]
	var grid_x: float = round((position.x - city_position.x) / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var grid_z: float = round((position.z - city_position.z) / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var min_x: float = float(city.get("road_grid_min_x", -7.5))
	var max_x: float = float(city.get("road_grid_max_x", 7.5))
	var min_z: float = float(city.get("road_grid_min_z", -7.5))
	var max_z: float = float(city.get("road_grid_max_z", 7.5))
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var options: Array[Vector2i] = []
	for option in directions:
		var next_x: float = grid_x + float(option.x) * ROAD_GRID_SIZE
		var next_z: float = grid_z + float(option.y) * ROAD_GRID_SIZE
		if next_x < min_x - 0.1 or next_x > max_x + 0.1 or next_z < min_z - 0.1 or next_z > max_z + 0.1:
			continue
		options.append(option)
	if options.is_empty():
		return {"direction": Vector2i.ZERO, "waypoint": position}
	var chosen: Vector2i
	if previous_direction != Vector2i.ZERO and options.has(previous_direction) and randf() < 0.70:
		chosen = previous_direction
	else:
		var turn_options: Array[Vector2i] = []
		for option in options:
			if previous_direction == Vector2i.ZERO or option != -previous_direction:
				turn_options.append(option)
		if turn_options.is_empty():
			turn_options = options
		chosen = turn_options[randi_range(0, turn_options.size() - 1)]
	var target_x: float = grid_x + float(chosen.x) * ROAD_GRID_SIZE
	var target_z: float = grid_z + float(chosen.y) * ROAD_GRID_SIZE
	return {"direction": chosen, "waypoint": _surface_position(city_position.x + target_x, city_position.z + target_z)}


func _update_cars(delta: float) -> void:
	for i in range(cars.size() - 1, -1, -1):
		var car: Dictionary = cars[i]
		var node: Node3D = car["node"]
		if not is_instance_valid(node):
			cars.remove_at(i)
			continue
		var city_id: int = int(car["city_id"])
		if city_id < 0 or city_id >= cities.size():
			node.queue_free()
			cars.remove_at(i)
			continue
		var position: Vector3 = car["pos"]
		var waypoint: Vector3 = car["waypoint"]
		var offset := Vector2(waypoint.x - position.x, waypoint.z - position.z)
		var distance: float = offset.length()
		var step: float = float(car["speed"]) * delta
		if distance <= 0.40 or step >= distance:
			position = _surface_position(waypoint.x, waypoint.z)
			var route: Dictionary = _choose_next_car_waypoint(city_id, position, car["direction"])
			car["direction"] = route["direction"]
			car["waypoint"] = route["waypoint"]
			if Vector2(route["waypoint"].x - position.x, route["waypoint"].z - position.z).length() > 0.01:
				node.rotation.y = atan2(-(route["waypoint"].x - position.x), -(route["waypoint"].z - position.z))
		else:
			var movement: Vector2 = offset / maxf(distance, 0.001) * step
			position.x += movement.x
			position.z += movement.y
			position.y = _height_at(position.x, position.z)
			if step > 0.01:
				node.rotation.y = atan2(-offset.x, -offset.y)
		car["pos"] = position
		node.position = position
		cars[i] = car


func _update_traffic_population() -> void:
	if _world_year() < 1900 or cars.size() >= MAX_CARS:
		return
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var population: int = int(city.get("population", 0))
		if population < 24 or int(city.get("stage", 0)) < 2:
			continue
		var desired_cars: int = clampi(int(population / 28), 1, 8)
		var current_cars: int = 0
		for car in cars:
			if int(car["city_id"]) == city_id:
				current_cars += 1
		if current_cars < desired_cars:
			_spawn_car(city_id)
			return


func _update_abandoned_cities(interval: float) -> void:
	var population_counts: Array[int] = _population_counts_by_city()
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		if population_counts[city_id] > 0:
			city["abandoned"] = false
			city["abandoned_age"] = 0.0
			city["abandoned_decay_timer"] = 8.0
			cities[city_id] = city
			continue
		city["abandoned"] = true
		city["abandoned_age"] = float(city.get("abandoned_age", 0.0)) + interval
		var houses: Array = city["houses"]
		if not houses.is_empty() and not bool(city.get("ruined", false)):
			city["abandoned_decay_timer"] = float(city.get("abandoned_decay_timer", 8.0)) - interval
			if float(city["abandoned_decay_timer"]) <= 0.0:
				for attempt in range(houses.size()):
					var house: Node3D = houses[randi_range(0, houses.size() - 1)]
					if not is_instance_valid(house):
						continue
					if _collapse_specific_building(city_id, house, true, false):
						city = cities[city_id]
						city["abandoned_decay_timer"] = randf_range(7.0, 13.0)
						_rebuild_city_roads(city_id)
						_schedule_city_territory_refresh()
					break
		elif float(city.get("abandoned_age", 0.0)) >= 24.0 and not bool(city.get("ruined", false)):
			city["ruined"] = true
			for visual_key in ["plinth", "body", "roof", "flag_pole", "flag", "far_marker"]:
				var visual: MeshInstance3D = city.get(visual_key) as MeshInstance3D
				if is_instance_valid(visual):
					visual.visible = false
			var road_node: MeshInstance3D = city.get("roads") as MeshInstance3D
			var sidewalk_node: MeshInstance3D = city.get("sidewalks") as MeshInstance3D
			if is_instance_valid(road_node):
				road_node.mesh = null
			if is_instance_valid(sidewalk_node):
				sidewalk_node.mesh = null
			var fill: MeshInstance3D = city["zone_fill"]
			var border: MeshInstance3D = city["zone_border"]
			if is_instance_valid(fill):
				fill.visible = false
			if is_instance_valid(border):
				border.visible = false
			_log("%s has become a ruin. Nature is gradually reclaiming the settlement." % city["name"])
		cities[city_id] = city
		if is_instance_valid(city.get("label")):
			var label: Label3D = city["label"]
			var status: String = "RUINS" if bool(city.get("ruined", false)) else "ABANDONED"
			label.text = "%s\n%s | POP 0" % [city["name"], status]


func _update_simulation_timers(delta: float) -> void:
	abandoned_check_timer += delta
	if abandoned_check_timer >= 4.0:
		abandoned_check_timer = fmod(abandoned_check_timer, 4.0)
		_update_abandoned_cities(4.0)
	city_defence_timer += delta
	if city_defence_timer >= 1.0:
		city_defence_timer = fmod(city_defence_timer, 1.0)
		_update_city_defences()
	if territory_refresh_pending:
		territory_refresh_timer += delta
		if territory_refresh_timer >= 5.0:
			territory_refresh_timer = 0.0
			territory_refresh_pending = false
			_refresh_city_territory(0)
	traffic_spawn_timer += delta
	if traffic_spawn_timer >= 2.6:
		traffic_spawn_timer = fmod(traffic_spawn_timer, 2.6)
		_update_traffic_population()
	growth_timer += delta
	city_event_timer += delta
	resource_timer += delta
	founding_timer += delta
	auto_war_timer += delta
	if city_event_timer >= 22.0:
		city_event_timer = 0.0
		_process_city_events()
	if resource_timer >= 4.0:
		resource_timer = 0.0
		_collect_resources()
		_update_city_economies()
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


func _update_city_economies() -> void:
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		if _city_population(city_id) <= 0 or bool(city.get("ruined", false)):
			city["wealth"] = maxf(0.0, float(city.get("wealth", 0.0)) - 0.04)
			cities[city_id] = city
			continue
		var farms: int = 0
		var workshops: int = 0
		var commercial: int = 0
		var apartments: int = 0
		for house in city["houses"]:
			if not is_instance_valid(house):
				continue
			match int(house.get_meta("building_type", 0)):
				1:
					apartments += 1
				2:
					workshops += 1
				3:
					commercial += 1
				4:
					farms += 1

		# Farms provide a slow but reliable food supply. Workshops and shops add
		# wealth, while civic/commercial buildings help improve local security.
		city["food"] = minf(42.0, float(city["food"]) + float(farms) * 0.28)
		var workshop_output: float = float(workshops) * 0.16
		if workshops > 0 and float(city["wood"]) > 0.0:
			city["wood"] = maxf(0.0, float(city["wood"]) - minf(float(city["wood"]), float(workshops) * 0.035))
			city["wealth"] = minf(100.0, float(city["wealth"]) + workshop_output)
		city["wealth"] = minf(100.0, float(city["wealth"]) + float(commercial) * 0.14 + float(apartments) * 0.025)
		if commercial > 0:
			city["security"] = minf(100.0, float(city["security"]) + float(commercial) * 0.025)
		if farms > 0 and float(city["food"]) >= 7.0:
			city["stability"] = minf(100.0, float(city["stability"]) + 0.035 * float(farms))
		cities[city_id] = city
		if _city_population(city_id) > 0 and not bool(city.get("ruined", false)):
			_apply_building_era_appearance(city_id, _world_year())


func _population_counts_by_city() -> Array[int]:
	var counts: Array[int] = []
	for city_id in range(cities.size()):
		counts.append(0)
	for person in people:
		var city_id: int = int(person.get("city_id", -1))
		if city_id >= 0 and city_id < counts.size():
			counts[city_id] += 1
	return counts


func _city_population(city_id: int) -> int:
	if city_id < 0 or city_id >= cities.size():
		return 0
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
	var population_counts: Array[int] = _population_counts_by_city()
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var population: int = population_counts[city_id]
		var previous_development_population: int = int(city.get("development_population", -1))
		if population > 0 and population < MAX_CITY_POPULATION and float(city["food"]) >= 1.0 and float(city.get("stability", 72.0)) >= 28.0 and people.size() < MAX_PEOPLE:
			city["food"] = maxf(0.0, float(city["food"]) - 1.0)
			if float(city["wood"]) > 0.2:
				city["wood"] = maxf(0.0, float(city["wood"]) - 0.2)
				var angle: float = randf() * TAU
				var radius: float = randf_range(5.0, minf(24.0, 10.0 + float(city["houses"].size()) * 0.12))
				var spawn_pos: Vector3 = _surface_position(city["pos"].x + cos(angle) * radius, city["pos"].z + sin(angle) * radius)
				var people_before: int = people.size()
				_spawn_human(spawn_pos, city_id)
				if people.size() > people_before:
					population += 1
					population_counts[city_id] = population
					_log("%s grew to %d citizens." % [city["name"], population])
		city["population"] = population
		cities[city_id] = city
		if population != previous_development_population:
			_refresh_city_development(city_id)


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
	var wild_buckets: Dictionary = {}
	for person_index in range(people.size()):
		if int(people[person_index]["city_id"]) >= 0:
			continue
		var position: Vector3 = people[person_index]["pos"]
		var cell := Vector2i(floori(position.x / 8.0), floori(position.z / 8.0))
		if not wild_buckets.has(cell):
			wild_buckets[cell] = []
		var cell_members: Array = wild_buckets[cell]
		cell_members.append(person_index)
		wild_buckets[cell] = cell_members
	for cell_key in wild_buckets.keys():
		var cell: Vector2i = cell_key
		var anchor_indices: Array = wild_buckets[cell]
		for anchor_index in anchor_indices:
			var anchor: Vector3 = people[anchor_index]["pos"]
			var members: Array[int] = []
			for cell_x in range(-1, 2):
				for cell_z in range(-1, 2):
					var nearby_cell: Vector2i = cell + Vector2i(cell_x, cell_z)
					if not wild_buckets.has(nearby_cell):
						continue
					var nearby_members: Array = wild_buckets[nearby_cell]
					for candidate_index in nearby_members:
						var candidate: Vector3 = people[candidate_index]["pos"]
						var dx: float = anchor.x - candidate.x
						var dz: float = anchor.z - candidate.z
						if dx * dx + dz * dz <= 64.0:
							members.append(candidate_index)
			if members.size() < 4:
				continue
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
				var member: Dictionary = people[member_id]
				var city_position: Vector3 = cities[new_city_id]["pos"]
				member["home_offset"] = Vector2(member["pos"].x - city_position.x, member["pos"].z - city_position.z)
				people[member_id] = member
			_refresh_city_development(new_city_id)
			_schedule_city_territory_refresh()
			_seed_resources_around(cities[new_city_id]["pos"])
			_log("A new settlement, %s, has been founded by %d humans." % [new_name, members.size()])
			return


func _city_is_at_war(city_id: int) -> bool:
	for other_id in range(cities.size()):
		if other_id != city_id and _are_at_war(city_id, other_id):
			return true
	return false


func _update_city_condition_metrics(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var population: int = _city_population(city_id)
	var stability: float = float(city.get("stability", 72.0))
	var security: float = float(city.get("security", 44.0))
	var wealth: float = float(city.get("wealth", 12.0))
	if float(city["food"]) < 2.0:
		stability -= 4.5
		security -= 1.5
	elif float(city["food"]) >= 7.0:
		stability += 1.7
	if _city_is_at_war(city_id):
		stability -= 2.0
	else:
		stability += 0.6
	wealth += float(population) * 0.012
	if wealth > 8.0:
		security += 0.8
	stability = clamp(stability, 0.0, 100.0)
	security = clamp(security, 0.0, 100.0)
	wealth = clamp(wealth, 0.0, 100.0)
	city["stability"] = stability
	city["security"] = security
	city["wealth"] = wealth
	cities[city_id] = city


func _process_city_events() -> void:
	if cities.is_empty():
		return
	for city_id in range(cities.size()):
		_update_city_condition_metrics(city_id)

	# Rotate the starting point so no city is permanently favoured by its ID.
	var first_city: int = randi_range(0, cities.size() - 1)
	for attempt in range(cities.size()):
		var city_id: int = (first_city + attempt) % cities.size()
		if _try_city_event(city_id):
			return


func _try_city_event(city_id: int) -> bool:
	if city_id < 0 or city_id >= cities.size():
		return false
	var city: Dictionary = cities[city_id]
	var population: int = _city_population(city_id)
	var stability: float = float(city.get("stability", 72.0))
	var security: float = float(city.get("security", 44.0))
	var wealth: float = float(city.get("wealth", 12.0))
	var food: float = float(city["food"])
	var wood: float = float(city["wood"])
	var stage: int = int(city.get("stage", 0))

	if population >= 10 and stability < 24.0:
		var became_independent: bool = int(city["owner"]) != city_id
		if became_independent:
			city["owner"] = city_id
			_log("REBELLION: %s has declared independence after unrest overwhelmed its government." % city["name"])
		else:
			_log("REBELLION: Unrest overthrew the local administration in %s. Emergency leadership has taken over." % city["name"])
		_record_city_event(city_id, "REBELLION", Color(0.98, 0.24, 0.27))
		city["stability"] = 36.0
		city["security"] = maxf(12.0, security - 12.0)
		city["wealth"] = maxf(0.0, wealth - 5.0)
		cities[city_id] = city
		return true

	if population >= 5 and food < 1.5:
		city["stability"] = maxf(0.0, stability - 8.0)
		city["security"] = maxf(0.0, security - 2.0)
		cities[city_id] = city
		if _world_year() >= 1750:
			_log("FOOD PROTEST: Residents in %s are demonstrating over dwindling food supplies." % city["name"])
			_record_city_event(city_id, "FOOD PROTEST", Color(1.0, 0.65, 0.22))
		else:
			_log("FOOD RIOT: Residents in %s are fighting over dwindling food supplies." % city["name"])
			_record_city_event(city_id, "FOOD RIOT", Color(1.0, 0.42, 0.18))
		return true

	# Keep modern extremist attacks out of medieval and early industrial eras.
	if _world_year() >= 1970 and population >= 16 and stage >= 2 and randf() < 0.035:
		var houses: Array = city["houses"]
		if not houses.is_empty():
			var damaged_house: Node3D = houses[randi_range(0, houses.size() - 1)]
			if is_instance_valid(damaged_house):
				damaged_house.set_meta("damaged", true)
				for visual in damaged_house.get_children():
					if visual is MeshInstance3D:
						var original_material: StandardMaterial3D = (visual as MeshInstance3D).material_override as StandardMaterial3D
						if original_material != null:
							var damaged_material := original_material.duplicate() as StandardMaterial3D
							damaged_material.albedo_color = original_material.albedo_color.darkened(0.34)
							(visual as MeshInstance3D).material_override = damaged_material
		city["stability"] = maxf(0.0, stability - 7.0)
		city["security"] = maxf(0.0, security - 9.0)
		city["wealth"] = maxf(0.0, wealth - 6.0)
		cities[city_id] = city
		_log("SECURITY INCIDENT: An extremist attack damaged property in %s. Security is being reviewed." % city["name"])
		_record_city_event(city_id, "ATTACK", Color(1.0, 0.30, 0.12))
		return true

	# Organised bank robberies require an established financial centre and a modern-era city.
	if _world_year() >= 1800 and population >= 12 and stage >= 2 and wealth >= 5.0 and security < 72.0 and randf() < 0.24:
		city["wealth"] = maxf(0.0, wealth - randf_range(3.0, 6.0))
		city["security"] = maxf(0.0, security - randf_range(3.0, 7.0))
		city["stability"] = maxf(0.0, stability - 2.0)
		cities[city_id] = city
		_log("BANK ROBBERY: A bank was robbed in %s. The city lost funds and authorities increased patrols." % city["name"])
		_record_city_event(city_id, "BANK ROBBERY", Color(1.0, 0.48, 0.19))
		return true

	# Mass public protest movements become a distinct recurring event in the modernising
	# political era; earlier unrest remains represented by food riots and rebellions.
	if _world_year() >= 1848 and population >= 8 and (stability < 58.0 or randf() < 0.13):
		city["stability"] = maxf(0.0, stability - randf_range(4.0, 8.0))
		city["security"] = maxf(0.0, security - 2.0)
		cities[city_id] = city
		_log("PROTEST: A crowd gathered in %s over local conditions. The city is less stable." % city["name"])
		_record_city_event(city_id, "PROTEST", Color(0.98, 0.78, 0.30))
		return true

	if _world_year() >= 1780 and population >= 8 and (wood < 1.0 or stability < 43.0) and randf() < 0.38:
		city["wealth"] = maxf(0.0, wealth - 2.0)
		city["stability"] = maxf(0.0, stability - 4.0)
		cities[city_id] = city
		_log("WORKERS' STRIKE: Work has slowed in %s amid shortages and public frustration." % city["name"])
		_record_city_event(city_id, "STRIKE", Color(1.0, 0.61, 0.22))
		return true

	if population >= 8 and stability >= 82.0 and randf() < 0.12:
		city["wealth"] = minf(100.0, wealth + 3.0)
		city["stability"] = minf(100.0, stability + 2.0)
		cities[city_id] = city
		_log("CITY FESTIVAL: A successful public celebration boosted morale in %s." % city["name"])
		_record_city_event(city_id, "FESTIVAL", Color(0.28, 0.96, 0.70))
		return true
	return false


func _toggle_reset_speed_on_city_event() -> void:
	reset_speed_on_city_event = not reset_speed_on_city_event
	for node in ui_root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text.begins_with("Reset Speed on City Event:"):
			button.text = "Reset Speed on City Event: ON" if reset_speed_on_city_event else "Reset Speed on City Event: OFF"
	_log("Reset-to-1x on city events %s." % ("enabled" if reset_speed_on_city_event else "disabled"))


func _record_city_event(city_id: int, event_name: String, event_color: Color) -> void:
	city_events_total += 1
	if reset_speed_on_city_event:
		sim_speed = 1.0
		if is_instance_valid(speed_button):
			speed_button.text = "Simulation Speed: 1×"
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var marker: Label3D = city["event_marker"]
	if is_instance_valid(marker):
		marker.text = event_name
		marker.modulate = event_color
		marker.visible = true
	city["event_timer"] = 12.0
	cities[city_id] = city
	_spawn_city_event_visual(city_id, event_name)


func _spawn_city_event_visual(city_id: int, event_name: String) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var centre: Vector3 = city["pos"]
	if event_name in ["PROTEST", "FOOD PROTEST", "FOOD RIOT", "STRIKE", "REBELLION", "FESTIVAL"]:
		var crowd_root := Node3D.new()
		crowd_root.name = "CityEventCrowd"
		crowd_root.position = centre
		add_child(crowd_root)
		var actors: Array = []
		var crowd_count: int = 12 if event_name == "FESTIVAL" else 18
		var shirt_colors: Array[Color] = [Color(0.85, 0.25, 0.20), Color(0.92, 0.76, 0.30), Color(0.25, 0.52, 0.82), Color(0.77, 0.78, 0.76)]
		for person_index in range(crowd_count):
			var local_x: float = float(person_index % 6 - 2.5) * 1.25
			var local_z: float = 5.2 + float(person_index / 6) * 1.0
			var ground: Vector3 = _surface_position(centre.x + local_x, centre.z + local_z)
			var garment: Color = shirt_colors[person_index % shirt_colors.size()]
			if event_name == "REBELLION":
				garment = Color(0.55, 0.12, 0.15) if person_index % 2 == 0 else shirt_colors[person_index % shirt_colors.size()]
			if event_name == "FESTIVAL":
				garment = city["color"].lightened(float(person_index % 3) * 0.10)
			var visuals: Dictionary = _create_roblox_character(crowd_root, garment, Color(0.85, 0.66, 0.49))
			var character: Node3D = visuals["node"]
			character.position = Vector3(local_x, ground.y - centre.y, local_z)
			actors.append(visuals)

		# Large placards make protests legible from the usual isometric camera.
		if event_name != "FESTIVAL":
			var sign_text: String = "FOOD" if event_name == "FOOD PROTEST" or event_name == "FOOD RIOT" else ("WAGES" if event_name == "STRIKE" else ("RESIST" if event_name == "REBELLION" else "JUSTICE"))
			for sign_index in range(3):
				var sign_root := Node3D.new()
				var sign_x: float = float(sign_index - 1) * 3.1
				var sign_ground: Vector3 = _surface_position(centre.x + sign_x, centre.z + 3.7)
				sign_root.position = Vector3(sign_x, sign_ground.y - centre.y, 3.7)
				crowd_root.add_child(sign_root)
				var pole := BoxMesh.new()
				pole.size = Vector3(0.09, 1.45, 0.09)
				_add_mesh(sign_root, pole, _material(Color(0.28, 0.19, 0.12)), Vector3(0.0, 0.72, 0.0))
				var board := BoxMesh.new()
				board.size = Vector3(1.3, 0.68, 0.12)
				_add_mesh(sign_root, board, _material(Color(0.88, 0.78, 0.56)), Vector3(0.0, 1.35, 0.0))
				var lettering := Label3D.new()
				lettering.text = sign_text
				lettering.position = Vector3(0.0, 1.34, 0.075)
				lettering.font_size = 32
				lettering.pixel_size = 0.009
				lettering.outline_size = 5
				lettering.modulate = Color(0.15, 0.14, 0.12)
				sign_root.add_child(lettering)
		city_event_scenes.append({
			"node": crowd_root,
			"kind": "crowd",
			"actors": actors,
			"age": 0.0,
			"duration": 18.0
		})
		return

	if event_name == "ATTACK":
		var target_house: Node3D = null
		if not (city["houses"] as Array).is_empty():
			target_house = city["houses"][randi_range(0, city["houses"].size() - 1)]
		var target_position: Vector3 = target_house.global_position if is_instance_valid(target_house) else centre
		var blast_root := Node3D.new()
		blast_root.name = "CityExplosion"
		blast_root.position = target_position
		add_child(blast_root)
		var fireball := MeshInstance3D.new()
		var fireball_mesh := SphereMesh.new()
		fireball_mesh.radius = 1.35
		fireball_mesh.height = 2.7
		fireball.mesh = fireball_mesh
		var blast_material := StandardMaterial3D.new()
		blast_material.albedo_color = Color(1.0, 0.30, 0.055, 0.88)
		blast_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blast_material.emission_enabled = true
		blast_material.emission = Color(1.0, 0.14, 0.02)
		blast_material.emission_energy_multiplier = 2.5
		fireball.material_override = blast_material
		fireball.position = Vector3(0.0, 1.4, 0.0)
		blast_root.add_child(fireball)
		var smoke := MeshInstance3D.new()
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 1.8
		smoke_mesh.height = 3.6
		smoke.mesh = smoke_mesh
		var smoke_material := StandardMaterial3D.new()
		smoke_material.albedo_color = Color(0.19, 0.18, 0.17, 0.55)
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke.material_override = smoke_material
		smoke.position = Vector3(0.0, 2.2, 0.0)
		blast_root.add_child(smoke)
		if is_instance_valid(target_house):
			city_event_scenes.append({
				"node": blast_root,
				"kind": "attack",
				"flash": fireball,
				"smoke": smoke,
				"house": target_house,
				"city_id": city_id,
				"collapsed": false,
				"start_rotation": target_house.rotation,
				"age": 0.0,
				"duration": 3.0
			})
		else:
			city_event_scenes.append({"node": blast_root, "kind": "effect", "age": 0.0, "duration": 3.0})
		return

	if event_name == "BANK ROBBERY":
		var chase_root := Node3D.new()
		chase_root.name = "BankRobberyChase"
		chase_root.position = centre
		add_child(chase_root)
		var robber_visuals: Dictionary = _create_roblox_character(chase_root, Color(0.12, 0.14, 0.17), Color(0.66, 0.47, 0.32))
		var robber: Node3D = robber_visuals["node"]
		robber.position = Vector3(-3.0, _height_at(centre.x - 3.0, centre.z) - centre.y, 0.0)
		var sack := BoxMesh.new()
		sack.size = Vector3(0.23, 0.24, 0.23)
		_add_mesh(robber, sack, _material(Color(0.47, 0.31, 0.17)), Vector3(0.24, 0.0, 0.0))

		var car := Node3D.new()
		car.name = "PoliceChaseCar"
		chase_root.add_child(car)
		var car_body := BoxMesh.new()
		car_body.size = Vector3(2.8, 0.72, 1.35)
		_add_mesh(car, car_body, _material(Color(0.88, 0.90, 0.92)), Vector3(0.0, 0.64, 0.0))
		var car_roof := BoxMesh.new()
		car_roof.size = Vector3(1.35, 0.47, 1.08)
		_add_mesh(car, car_roof, _material(Color(0.12, 0.24, 0.36)), Vector3(-0.05, 1.20, 0.0))
		var front_window := BoxMesh.new()
		front_window.size = Vector3(0.065, 0.32, 0.80)
		_add_mesh(car, front_window, _material(Color(0.30, 0.62, 0.78)), Vector3(0.66, 1.22, 0.0))
		for wheel_x in [-0.92, 0.92]:
			for wheel_z in [-0.61, 0.61]:
				var wheel := MeshInstance3D.new()
				var wheel_mesh := CylinderMesh.new()
				wheel_mesh.top_radius = 0.27
				wheel_mesh.bottom_radius = 0.27
				wheel_mesh.height = 0.16
				wheel.mesh = wheel_mesh
				wheel.rotation.z = PI * 0.5
				wheel.position = Vector3(wheel_x, 0.30, wheel_z)
				wheel.material_override = _material(Color(0.08, 0.09, 0.10))
				car.add_child(wheel)
		var red_light := BoxMesh.new()
		red_light.size = Vector3(0.25, 0.12, 0.20)
		_add_mesh(car, red_light, _material(Color(1.0, 0.12, 0.08)), Vector3(-0.05, 1.49, -0.23))
		var blue_light := BoxMesh.new()
		blue_light.size = Vector3(0.25, 0.12, 0.20)
		_add_mesh(car, blue_light, _material(Color(0.10, 0.38, 1.0)), Vector3(-0.05, 1.49, 0.23))
		car.position = Vector3(-7.0, _height_at(centre.x - 7.0, centre.z + 1.7) - centre.y, 1.7)
		city_event_scenes.append({
			"node": chase_root,
			"kind": "robbery",
			"robber": robber,
			"car": car,
			"age": 0.0,
			"duration": 12.0
		})


func _update_city_event_scenes(delta: float) -> void:
	for scene_index in range(city_event_scenes.size() - 1, -1, -1):
		var scene: Dictionary = city_event_scenes[scene_index]
		scene["age"] = float(scene.get("age", 0.0)) + delta
		var age: float = float(scene["age"])
		var kind: String = str(scene.get("kind", "effect"))
		if kind == "crowd":
			var actors: Array = scene.get("actors", [])
			for actor_index in range(actors.size()):
				var actor: Dictionary = actors[actor_index]
				var gait: float = sin(age * 6.5 + float(actor_index) * 1.7) * 0.72
				var left_arm: Node3D = actor["left_arm"]
				var right_arm: Node3D = actor["right_arm"]
				if is_instance_valid(left_arm):
					left_arm.rotation.x = gait
				if is_instance_valid(right_arm):
					right_arm.rotation.x = -gait * 0.8
		elif kind == "attack":
			var flash: MeshInstance3D = scene["flash"]
			var smoke: MeshInstance3D = scene["smoke"]
			var flash_scale: float = 0.25 + minf(age, 0.8) * 2.0
			if is_instance_valid(flash):
				flash.scale = Vector3.ONE * flash_scale
				flash.visible = age < 1.0
			if is_instance_valid(smoke):
				smoke.scale = Vector3.ONE * (0.35 + age * 0.58)
				smoke.position.y = 1.7 + age * 0.55
				smoke.visible = age < 2.7
			var house: Node3D = scene.get("house")
			if is_instance_valid(house):
				var original_rotation: Vector3 = scene["start_rotation"]
				var fall_amount: float = clampf((age - 0.15) / 0.9, 0.0, 1.0)
				house.rotation = Vector3(original_rotation.x, original_rotation.y, original_rotation.z + fall_amount * 1.12)
				if age > 0.75:
					house.set_meta("damaged", true)
				if age >= 1.08 and not bool(scene.get("collapsed", false)):
					_collapse_specific_building(int(scene.get("city_id", -1)), house, true)
					scene["collapsed"] = true
		elif kind == "robbery":
			var robber: Node3D = scene["robber"]
			var car: Node3D = scene["car"]
			var progress: float = clampf(age / float(scene["duration"]), 0.0, 1.0)
			if is_instance_valid(robber):
				robber.position.x = -3.0 + progress * 20.0
				robber.position.z = sin(age * 2.0) * 0.75
				var phase: float = sin(age * 9.0) * 0.56
				var left_arm: Node3D = robber.get_node_or_null("LeftArmPivot")
				var right_arm: Node3D = robber.get_node_or_null("RightArmPivot")
				var left_leg: Node3D = robber.get_node_or_null("LeftLegPivot")
				var right_leg: Node3D = robber.get_node_or_null("RightLegPivot")
				if is_instance_valid(left_arm):
					left_arm.rotation.x = phase
				if is_instance_valid(right_arm):
					right_arm.rotation.x = -phase
				if is_instance_valid(left_leg):
					left_leg.rotation.x = -phase
				if is_instance_valid(right_leg):
					right_leg.rotation.x = phase
			if is_instance_valid(car):
				car.position.x = -7.0 + progress * 18.0
				car.position.z = 1.7 + cos(age * 1.4) * 0.28
				car.rotation.y = 0.0
		if age >= float(scene.get("duration", 10.0)):
			var node: Node = scene.get("node")
			if is_instance_valid(node):
				node.queue_free()
			city_event_scenes.remove_at(scene_index)
		else:
			city_event_scenes[scene_index] = scene


func _update_city_event_markers(delta: float) -> void:
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var time_left: float = float(city.get("event_timer", 0.0))
		if time_left <= 0.0:
			continue
		time_left = maxf(0.0, time_left - delta)
		city["event_timer"] = time_left
		var marker: Label3D = city["event_marker"]
		if is_instance_valid(marker) and time_left <= 0.0:
			marker.visible = false
		cities[city_id] = city


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
	if not automatic:
		_log("%s will respond if the attacking force reaches its outskirts." % cities[target_id]["name"])


func _spawn_defenders(defending_city_id: int, aggressor_city_id: int) -> void:
	if defending_city_id < 0 or aggressor_city_id < 0 or defending_city_id >= cities.size() or aggressor_city_id >= cities.size():
		return
	var count: int = clampi(1 + int(_city_population(defending_city_id) / 10), 1, 4)
	for index in range(count):
		var p: Vector3 = cities[defending_city_id]["pos"]
		var soldier := Node3D.new()
		_add_mesh(soldier, _cached_box_mesh(Vector3(0.42, 0.78, 0.32)), _material(cities[defending_city_id]["color"].darkened(0.12)), Vector3(0.0, 0.60, 0.0))
		var helmet := SphereMesh.new()
		helmet.radius = 0.23
		helmet.height = 0.38
		_add_mesh(soldier, helmet, _material(Color(0.26, 0.28, 0.27)), Vector3(0.0, 1.14, 0.0))
		add_child(soldier)
		var spawn := _surface_position(p.x + randf_range(-2.5, 2.5), p.z + randf_range(-2.5, 2.5))
		soldier.position = spawn
		armies.append({
			"node": soldier, "pos": spawn, "source": defending_city_id, "target": aggressor_city_id,
			"attack_timer": 0.0, "idle_timer": 0.0, "home_city": defending_city_id,
			"is_defender": true, "alive": true
		})
	_log("%s has mobilised %d defenders." % [cities[defending_city_id]["name"], count])


func _update_armies(delta: float) -> void:
	for i in range(armies.size() - 1, -1, -1):
		var army: Dictionary = armies[i]
		if not bool(army.get("alive", true)):
			if is_instance_valid(army.get("node")):
				army["node"].queue_free()
			armies.remove_at(i)
			continue
		var source_id: int = int(army["source"])
		var target_id: int = int(army["target"])
		if source_id >= cities.size() or target_id >= cities.size():
			if is_instance_valid(army.get("node")):
				army["node"].queue_free()
			armies.remove_at(i)
			continue
		if _same_faction(source_id, target_id):
			if is_instance_valid(army.get("node")):
				army["node"].queue_free()
			armies.remove_at(i)
			continue
		if bool(army.get("is_defender", false)):
			_update_defender_army(i, delta)
			continue
		var position: Vector3 = army["pos"]
		var destination: Vector3 = cities[target_id]["pos"]
		var distance: float = Vector2(position.x - destination.x, position.z - destination.z).length()
		if distance > 3.0:
			var direction := Vector3(destination.x - position.x, 0.0, destination.z - position.z).normalized()
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
				if randf() < 0.10:
					if is_instance_valid(army.get("node")):
						army["node"].queue_free()
					armies.remove_at(i)
					continue
		army["pos"] = position
		if is_instance_valid(army.get("node")):
			army["node"].position = position
		armies[i] = army


func _update_defender_army(defender_index: int, delta: float) -> void:
	if defender_index < 0 or defender_index >= armies.size():
		return
	var defender: Dictionary = armies[defender_index]
	var home_city: int = int(defender.get("home_city", defender.get("source", -1)))
	var enemy_city: int = int(defender.get("target", -1))
	if home_city < 0 or home_city >= cities.size() or enemy_city < 0 or enemy_city >= cities.size():
		defender["alive"] = false
		armies[defender_index] = defender
		return
	var position: Vector3 = defender["pos"]
	var threat_index: int = -1
	var threat_distance_squared: float = 34.0 * 34.0
	for index in range(armies.size()):
		if index == defender_index:
			continue
		var threat: Dictionary = armies[index]
		if not bool(threat.get("alive", true)) or bool(threat.get("is_defender", false)):
			continue
		if int(threat.get("source", -1)) != enemy_city or int(threat.get("target", -1)) != home_city:
			continue
		var threat_position: Vector3 = threat["pos"]
		var dx: float = threat_position.x - position.x
		var dz: float = threat_position.z - position.z
		var distance_squared: float = dx * dx + dz * dz
		if distance_squared < threat_distance_squared:
			threat_distance_squared = distance_squared
			threat_index = index
	if threat_index < 0:
		defender["idle_timer"] = float(defender.get("idle_timer", 0.0)) + delta
		var home_position: Vector3 = cities[home_city]["pos"]
		var home_distance: float = Vector2(position.x - home_position.x, position.z - home_position.z).length()
		if home_distance > 2.0:
			var toward_home := Vector3(home_position.x - position.x, 0.0, home_position.z - position.z).normalized()
			position.x += toward_home.x * delta * 2.5
			position.z += toward_home.z * delta * 2.5
			position.y = _height_at(position.x, position.z)
		elif float(defender["idle_timer"]) > 10.0:
			defender["alive"] = false
			if is_instance_valid(defender.get("node")):
				defender["node"].queue_free()
			armies[defender_index] = defender
			return
	else:
		defender["idle_timer"] = 0.0
		var threat_position: Vector3 = armies[threat_index]["pos"]
		var distance: float = Vector2(position.x - threat_position.x, position.z - threat_position.z).length()
		if distance > 1.3:
			var direction := Vector3(threat_position.x - position.x, 0.0, threat_position.z - position.z).normalized()
			position.x += direction.x * delta * 3.6
			position.z += direction.z * delta * 3.6
			position.y = _height_at(position.x, position.z)
			defender["attack_timer"] = 0.0
		else:
			defender["attack_timer"] = float(defender.get("attack_timer", 0.0)) + delta
			if float(defender["attack_timer"]) >= 1.25:
				defender["attack_timer"] = 0.0
				var threat: Dictionary = armies[threat_index]
				threat["alive"] = false
				if is_instance_valid(threat.get("node")):
					threat["node"].queue_free()
				armies[threat_index] = threat
				if randf() < 0.18:
					defender["alive"] = false
					if is_instance_valid(defender.get("node")):
						defender["node"].queue_free()
		defender["target"] = enemy_city
	defender["pos"] = position
	if is_instance_valid(defender.get("node")):
		defender["node"].position = position
	armies[defender_index] = defender


func _update_city_defences() -> void:
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		city["defence_cooldown"] = maxf(0.0, float(city.get("defence_cooldown", 0.0)) - 1.0)
		if float(city["defence_cooldown"]) > 0.0 or _city_population(city_id) < 8 or float(city.get("security", 44.0)) < 8.0:
			cities[city_id] = city
			continue
		var incoming_city: int = -1
		for army in armies:
			if not bool(army.get("alive", true)) or bool(army.get("is_defender", false)):
				continue
			if int(army.get("target", -1)) != city_id:
				continue
			var source_id: int = int(army.get("source", -1))
			if source_id < 0 or source_id >= cities.size() or _same_faction(source_id, city_id):
				continue
			var unit_position: Vector3 = army["pos"]
			var city_position: Vector3 = city["pos"]
			var dx: float = unit_position.x - city_position.x
			var dz: float = unit_position.z - city_position.z
			if dx * dx + dz * dz <= 38.0 * 38.0:
				incoming_city = source_id
				break
		if incoming_city >= 0:
			var defenders_present: bool = false
			for army in armies:
				if bool(army.get("is_defender", false)) and bool(army.get("alive", true)) and int(army.get("home_city", -1)) == city_id:
					defenders_present = true
					break
			if not defenders_present:
				_spawn_defenders(city_id, incoming_city)
				city["defence_cooldown"] = 18.0
		cities[city_id] = city


func _launch_missile(source_id: int, target_id: int) -> void:
	if source_id < 0 or target_id < 0 or source_id >= cities.size() or target_id >= cities.size():
		return
	_launch_missile_at(source_id, cities[target_id]["pos"], target_id)


func _launch_missile_at(source_id: int, ground_target: Vector3, target_id: int = -1) -> void:
	if source_id < 0 or source_id >= cities.size():
		return
	if _world_year() < MISSILE_UNLOCK_YEAR:
		_log("MISSILE LAUNCH BLOCKED: Ballistic missiles unlock in 1945.")
		return
	if absf(ground_target.x) > TERRAIN_SIZE * 0.5 or absf(ground_target.z) > TERRAIN_SIZE * 0.5:
		_log("Missile target is outside the playable world.")
		return
	var start: Vector3 = cities[source_id]["pos"] + Vector3(0.0, 4.4, 0.0)
	var finish: Vector3 = ground_target
	finish.y = _height_at(finish.x, finish.z) + 1.8
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
	var target_name: String = "open ground"
	if target_id >= 0 and target_id < cities.size():
		target_name = cities[target_id]["name"]
	_log("MISSILE AWAY: %s has fired at %s." % [cities[source_id]["name"], target_name])


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

	# Damage is centred on the clicked impact coordinate rather than teleporting
	# the effect to the city's town hall.
	_destroy_cars_in_radius(position, 7.0)
	var blast_radius_squared: float = 7.0 * 7.0
	var damaged_city_names: Array[String] = []
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var city_position: Vector3 = city["pos"]
		var city_dx: float = city_position.x - position.x
		var city_dz: float = city_position.z - position.z
		var city_distance_squared: float = city_dx * city_dx + city_dz * city_dz
		var houses: Array = city["houses"]
		var buildings_to_collapse: Array[Node3D] = []
		for house in houses:
			if not is_instance_valid(house):
				continue
			var house_position: Vector3 = house.global_position
			var dx: float = house_position.x - position.x
			var dz: float = house_position.z - position.z
			if dx * dx + dz * dz <= blast_radius_squared:
				buildings_to_collapse.append(house)
		var city_changed: bool = false
		for house in buildings_to_collapse:
			if _collapse_specific_building(city_id, house, true, false):
				city_changed = true
		if city_changed:
			_rebuild_city_roads(city_id)
		var population_losses: int = 0
		for person_index in range(people.size() - 1, -1, -1):
			var person: Dictionary = people[person_index]
			var person_position: Vector3 = person["pos"]
			var pdx: float = person_position.x - position.x
			var pdz: float = person_position.z - position.z
			if pdx * pdx + pdz * pdz > blast_radius_squared:
				continue
			if is_instance_valid(person.get("node")):
				person["node"].queue_free()
			people.remove_at(person_index)
			population_losses += 1
		if population_losses > 0 or city_changed:
			city["stability"] = maxf(0.0, float(city.get("stability", 72.0)) - 12.0)
			city["security"] = maxf(0.0, float(city.get("security", 44.0)) - 18.0)
			city["wealth"] = maxf(0.0, float(city.get("wealth", 12.0)) - 8.0)
			cities[city_id] = city
			_refresh_city_development(city_id)
			damaged_city_names.append(str(city["name"]))
		elif city_distance_squared <= 12.0 * 12.0 and target_id == city_id:
			city["stability"] = maxf(0.0, float(city.get("stability", 72.0)) - 6.0)
			cities[city_id] = city
			damaged_city_names.append(str(city["name"]))
	for resource in resources:
		var resource_pos: Vector3 = resource["pos"]
		var rdx: float = resource_pos.x - position.x
		var rdz: float = resource_pos.z - position.z
		if rdx * rdx + rdz * rdz <= 7.0 * 7.0:
			resource["amount"] = 0
			resource["alive"] = false
			if is_instance_valid(resource["node"]):
				resource["node"].visible = false
	if damaged_city_names.is_empty():
		_log("IMPACT: A missile detonated on open ground.")
	else:
		_log("IMPACT: Missile damage across %s." % ", ".join(damaged_city_names))


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


func _collapse_specific_building(city_id: int, house: Node3D, allow_chain: bool = true, rebuild_roads: bool = true, chain_depth: int = 0) -> bool:
	if city_id < 0 or city_id >= cities.size() or not is_instance_valid(house):
		return false
	var city: Dictionary = cities[city_id]
	var houses: Array = city["houses"]
	var house_index: int = houses.find(house)
	if house_index < 0:
		return false
	var impact_position: Vector3 = house.global_position
	var local_position: Vector3 = house.position
	var building_height: float = float(house.get_meta("building_height", 2.0 * house.scale.y))
	var tall_building: bool = building_height >= 5.0 or bool(house.get_meta("is_skyscraper", false))
	var fall_angle: float = randf() * TAU
	var fall_direction := Vector2(cos(fall_angle), sin(fall_angle))
	var fall_reach: float = clampf(building_height * 0.42, 1.8, 12.0)
	var fall_half_width: float = clampf(building_height * 0.11 + 1.3, 1.7, 4.5)
	_kill_people_in_fall_corridor(impact_position, fall_direction, fall_reach, fall_half_width, house)
	_destroy_cars_in_fall_corridor(impact_position, fall_direction, fall_reach, fall_half_width + 0.8)
	_animate_building_fall(house, tall_building, city["color"], fall_direction)
	houses.remove_at(house_index)
	city["houses"] = houses
	city["destroyed_building_debt"] = int(city.get("destroyed_building_debt", 0)) + 1
	cities[city_id] = city
	# A tall building can knock into a neighbour. Limit cascades to four structures,
	# so a metropolitan disaster cannot turn into an unbounded chain.
	if allow_chain and chain_depth < 3 and (tall_building or randf() < 0.12):
		var chain_radius: float = minf(21.0, maxf(7.8, building_height * 0.62 + 2.0))
		var target_house: Node3D = null
		var target_score: float = INF
		for other in houses:
			if not is_instance_valid(other):
				continue
			var offset := Vector2(other.position.x - local_position.x, other.position.z - local_position.z)
			var distance_squared: float = offset.length_squared()
			if distance_squared < 0.1 or distance_squared > chain_radius * chain_radius:
				continue
			if offset.normalized().dot(fall_direction) < 0.15:
				continue
			var score: float = sqrt(distance_squared) + randf_range(0.0, 1.2)
			if score < target_score:
				target_score = score
				target_house = other
		if is_instance_valid(target_house) and randf() < (0.68 if tall_building else 0.20):
			_collapse_specific_building(city_id, target_house, true, false, chain_depth + 1)
	if rebuild_roads and city_id < cities.size():
		_rebuild_city_roads(city_id)
	return true


func _kill_people_in_fall_corridor(center: Vector3, direction: Vector2, reach: float, half_width: float, collapsing_house: Node3D) -> int:
	var deaths: int = 0
	var forward: Vector2 = direction.normalized()
	for person_index in range(people.size() - 1, -1, -1):
		var person: Dictionary = people[person_index]
		if not bool(person.get("alive", true)):
			continue
		var activity: String = str(person.get("activity", "wandering"))
		if activity == "riding":
			continue
		if activity == "indoors" or activity == "entering":
			var indoor_house: Variant = person.get("indoor_house", null)
			if not (indoor_house is Node3D and is_instance_valid(indoor_house)) or indoor_house != collapsing_house:
				continue
		var position: Vector3 = person["pos"]
		var offset := Vector2(position.x - center.x, position.z - center.z)
		var along: float = offset.dot(forward)
		var lateral: float = absf(offset.x * forward.y - offset.y * forward.x)
		if along < -half_width or along > reach + half_width or lateral > half_width:
			continue
		if is_instance_valid(person.get("node")):
			person["node"].queue_free()
		people.remove_at(person_index)
		deaths += 1
	if deaths > 0:
		last_detail_signature = ""
	return deaths


func _destroy_cars_in_fall_corridor(center: Vector3, direction: Vector2, reach: float, half_width: float) -> int:
	var forward: Vector2 = direction.normalized()
	var targets: Array[Node3D] = []
	for car in cars:
		var position: Vector3 = car["pos"]
		var offset := Vector2(position.x - center.x, position.z - center.z)
		var along: float = offset.dot(forward)
		var lateral: float = absf(offset.x * forward.y - offset.y * forward.x)
		if along < -half_width or along > reach + half_width or lateral > half_width:
			continue
		var node: Node3D = car.get("node") as Node3D
		if is_instance_valid(node):
			targets.append(node)
	var destroyed: int = 0
	for node in targets:
		if _destroy_car_node(node, "falling building"):
			destroyed += 1
	return destroyed



func _destroy_car_node(car_node: Node3D, cause: String = "impact") -> bool:
	if not is_instance_valid(car_node):
		return false
	var found_index: int = -1
	var car_data: Dictionary = {}
	for car_index in range(cars.size()):
		if cars[car_index].get("node") == car_node:
			found_index = car_index
			car_data = cars[car_index]
			break
	if found_index < 0:
		return false
	var crash_position: Vector3 = car_data.get("pos", car_node.global_position)
	for person_index in range(people.size() - 1, -1, -1):
		var person: Dictionary = people[person_index]
		if person.get("vehicle_node") != car_node or str(person.get("activity", "")) != "riding":
			continue
		if is_instance_valid(person.get("node")):
			person["node"].queue_free()
		people.remove_at(person_index)
	car_node.queue_free()
	cars.remove_at(found_index)
	_spawn_persistent_rubble(crash_position, false, Color(0.35, 0.38, 0.40), true, "vehicle")
	last_detail_signature = ""
	return true


func _destroy_cars_in_radius(center: Vector3, radius: float) -> int:
	var targets: Array[Node3D] = []
	var radius_squared: float = radius * radius
	for car in cars:
		var position: Vector3 = car["pos"]
		var dx: float = position.x - center.x
		var dz: float = position.z - center.z
		if dx * dx + dz * dz <= radius_squared:
			var node: Node3D = car.get("node") as Node3D
			if is_instance_valid(node):
				targets.append(node)
	var destroyed: int = 0
	for node in targets:
		if _destroy_car_node(node, "disaster"):
			destroyed += 1
	return destroyed


func _animate_building_fall(house: Node3D, tall_building: bool, building_color: Color, fall_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(house):
		return
	if fall_direction.length_squared() < 0.01:
		var angle: float = randf() * TAU
		fall_direction = Vector2(cos(angle), sin(angle))
	fall_direction = fall_direction.normalized()
	var duration: float = 0.78 if tall_building else 0.52
	var fall_angle: float = deg_to_rad(randf_range(72.0, 88.0) if tall_building else randf_range(58.0, 78.0))
	var z_fall: float = -fall_direction.x * fall_angle
	var x_fall: float = fall_direction.y * fall_angle
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(house, "rotation:z", house.rotation.z + z_fall, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(house, "rotation:x", house.rotation.x + x_fall, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(house, "scale:y", house.scale.y * 0.93, duration)
	tween.chain().tween_callback(_finish_building_collapse.bind(house, tall_building, building_color, fall_direction))


func _finish_building_collapse(house: Node3D, tall_building: bool, building_color: Color, fall_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(house):
		return
	var building_height: float = float(house.get_meta("building_height", 2.0 * house.scale.y))
	var rubble_reach: float = clampf(building_height * 0.42, 1.8, 12.0)
	var rubble_position: Vector3 = house.global_position + Vector3(fall_direction.x * rubble_reach, 0.0, fall_direction.y * rubble_reach)
	_spawn_persistent_rubble(rubble_position, tall_building, building_color)
	house.queue_free()


func _spawn_persistent_rubble(position: Vector3, tall_building: bool, building_color: Color, record: bool = true, rubble_kind: String = "building", saved_id: int = -1) -> void:
	var resolved_id: int = saved_id
	if resolved_id < 0:
		resolved_id = rubble_id_sequence
		rubble_id_sequence += 1
	else:
		rubble_id_sequence = maxi(rubble_id_sequence, resolved_id + 1)
	var debris_position: Vector3 = position
	debris_position.y = _height_at(position.x, position.z)
	var rubble := Node3D.new()
	rubble.name = "BuildingRubble" if rubble_kind == "building" else "VehicleWreck"
	rubble.position = debris_position
	rubble.set_meta("rubble_id", resolved_id)
	rubble.set_meta("rubble_kind", rubble_kind)
	add_child(rubble)
	var debris_count: int = 8 if tall_building else (5 if rubble_kind == "vehicle" else 4)
	for debris_index in range(debris_count):
		var piece := MeshInstance3D.new()
		var piece_mesh := BoxMesh.new()
		if rubble_kind == "vehicle":
			piece_mesh.size = Vector3(randf_range(0.35, 0.95), randf_range(0.12, 0.32), randf_range(0.35, 0.85))
		else:
			piece_mesh.size = Vector3(randf_range(0.35, 1.0), randf_range(0.16, 0.55), randf_range(0.35, 1.0))
		piece.mesh = piece_mesh
		piece.material_override = _material(Color(0.20, 0.21, 0.22) if rubble_kind == "vehicle" else Color(0.34, 0.32, 0.29).lerp(building_color, 0.18))
		var landing_position := Vector3(randf_range(-2.3, 2.3), piece_mesh.size.y * 0.5, randf_range(-2.3, 2.3))
		piece.position = Vector3(randf_range(-0.5, 0.5), randf_range(0.8, 3.0 if tall_building else 1.4), randf_range(-0.5, 0.5))
		piece.rotation = Vector3(randf_range(-0.75, 0.75), randf() * TAU, randf_range(-0.75, 0.75))
		rubble.add_child(piece)
		var fall_tween := create_tween()
		fall_tween.set_parallel(true)
		fall_tween.tween_property(piece, "position", landing_position, randf_range(0.28, 0.82)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(piece, "rotation", Vector3(randf_range(-0.9, 0.9), randf() * TAU, randf_range(-0.9, 0.9)), randf_range(0.25, 0.65)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rubble_nodes.append({"id": resolved_id, "node": rubble, "position": debris_position, "kind": rubble_kind, "reserved": false})
	if record:
		rubble_records.append({"id": resolved_id, "position": _vector3_to_array(debris_position), "tall": tall_building, "kind": rubble_kind, "color": building_color.to_html(true)})


func _get_rubble_node(rubble_id: int) -> Node3D:
	for entry in rubble_nodes:
		if int(entry.get("id", -1)) == rubble_id:
			var node: Node3D = entry.get("node") as Node3D
			return node if is_instance_valid(node) else null
	return null


func _find_nearby_cleanup_rubble(position: Vector3, max_distance: float = 22.0) -> int:
	var best_id: int = -1
	var best_distance_squared: float = max_distance * max_distance
	for entry in rubble_nodes:
		if bool(entry.get("reserved", false)):
			continue
		var node: Node3D = entry.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var rubble_position: Vector3 = node.global_position
		var dx: float = rubble_position.x - position.x
		var dz: float = rubble_position.z - position.z
		var distance_squared: float = dx * dx + dz * dz
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_id = int(entry["id"])
	return best_id


func _reserve_cleanup_rubble(rubble_id: int, reserved: bool) -> void:
	for index in range(rubble_nodes.size()):
		var entry: Dictionary = rubble_nodes[index]
		if int(entry.get("id", -1)) == rubble_id:
			entry["reserved"] = reserved
			rubble_nodes[index] = entry
			return


func _clear_rubble_by_id(rubble_id: int) -> void:
	for index in range(rubble_nodes.size() - 1, -1, -1):
		var entry: Dictionary = rubble_nodes[index]
		if int(entry.get("id", -1)) != rubble_id:
			continue
		var node: Node3D = entry.get("node") as Node3D
		if is_instance_valid(node):
			node.queue_free()
		rubble_nodes.remove_at(index)
		break
	for record_index in range(rubble_records.size() - 1, -1, -1):
		if int(rubble_records[record_index].get("id", -2)) == rubble_id:
			rubble_records.remove_at(record_index)
			break
	last_detail_signature = ""


func _destroy_city_houses(city_id: int, count: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var changed: bool = false
	for i in range(count):
		if city_id >= cities.size():
			break
		var houses: Array = cities[city_id]["houses"]
		if houses.is_empty():
			break
		var house: Node3D = houses[randi_range(0, houses.size() - 1)]
		if _collapse_specific_building(city_id, house, true, false):
			changed = true
	if changed and city_id < cities.size():
		_rebuild_city_roads(city_id)


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
	_destroy_cars_in_radius(center, radius)
	var radius_squared: float = radius * radius
	for city_id in range(cities.size()):
		var city_position: Vector3 = cities[city_id]["pos"]
		var city_dx: float = city_position.x - center.x
		var city_dz: float = city_position.z - center.z
		var city_distance_squared: float = city_dx * city_dx + city_dz * city_dz
		var city_houses: Array = cities[city_id]["houses"]
		if house_damage > 0 and city_distance_squared <= (radius + 45.0) * (radius + 45.0):
			var hit_houses: Array[Node3D] = []
			for house in city_houses:
				if not is_instance_valid(house):
					continue
				var house_position: Vector3 = house.global_position
				var dx: float = house_position.x - center.x
				var dz: float = house_position.z - center.z
				if dx * dx + dz * dz <= radius_squared and randf() < 0.72:
					hit_houses.append(house)
					if hit_houses.size() >= house_damage:
						break
			var city_damaged: bool = false
			for hit_house in hit_houses:
				if _collapse_specific_building(city_id, hit_house, true, false):
					city_damaged = true
			if city_damaged:
				_rebuild_city_roads(city_id)
		if city_distance_squared <= radius * radius * 2.25:
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
			_power_damage(fire["pos"], float(fire["radius"]), 2, 0.22, 1)
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

	# Compact HUD across the top instead of a permanent controls sidebar.
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.0
	top_panel.anchor_right = 1.0
	top_panel.anchor_top = 0.0
	top_panel.anchor_bottom = 0.0
	top_panel.offset_left = 12.0
	top_panel.offset_right = -12.0
	top_panel.offset_top = 10.0
	top_panel.offset_bottom = 78.0
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.040, 0.060, 0.94)))
	ui_root.add_child(top_panel)
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_bottom", 8)
	top_panel.add_child(top_margin)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_row)
	var brand := _make_label("CIVITERRA", 20, Color(0.46, 0.86, 0.98))
	brand.custom_minimum_size = Vector2(140.0, 0.0)
	top_row.add_child(brand)
	stats_label = _make_label("YEAR 1200 · CITIES 05 · PEOPLE 24", 12, Color(0.72, 0.88, 0.81))
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(stats_label)

	var era_box := VBoxContainer.new()
	era_box.add_theme_constant_override("separation", 1)
	era_box.add_child(_make_label("DEBUG ERA", 9, Color(0.51, 0.74, 0.84)))
	era_skipper = OptionButton.new()
	era_skipper.custom_minimum_size = Vector2(162.0, 30.0)
	era_skipper.add_theme_font_size_override("font_size", 11)
	era_skipper.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.23, 0.29)))
	era_skipper.add_theme_stylebox_override("hover", _button_style(Color(0.16, 0.34, 0.42)))
	for target_year in ERA_SKIP_YEARS:
		era_skipper.add_item("%d · %s" % [target_year, _historical_era_name(target_year)])
	era_skipper.item_selected.connect(_on_era_skipper_selected)
	era_box.add_child(era_skipper)
	top_row.add_child(era_box)

	pause_button = _make_button("PAUSE", _toggle_pause, Color(0.13, 0.22, 0.29))
	pause_button.custom_minimum_size = Vector2(76.0, 38.0)
	top_row.add_child(pause_button)
	speed_button = _make_button("1×", _cycle_speed, Color(0.13, 0.22, 0.29))
	speed_button.custom_minimum_size = Vector2(54.0, 38.0)
	top_row.add_child(speed_button)
	top_row.add_child(_make_button("SAVE", _save_world, Color(0.10, 0.29, 0.34)))
	top_row.add_child(_make_button("LOAD", _load_world, Color(0.12, 0.24, 0.32)))
	top_row.add_child(_make_button("EVENT 1×: OFF", _toggle_reset_speed_on_city_event, Color(0.20, 0.28, 0.34)))

	# Small chronicle panel; it no longer dictates half the screen layout.
	var chronicle := PanelContainer.new()
	chronicle.anchor_left = 0.0
	chronicle.anchor_right = 0.0
	chronicle.anchor_top = 0.0
	chronicle.anchor_bottom = 0.0
	chronicle.offset_left = 12.0
	chronicle.offset_right = 292.0
	chronicle.offset_top = 88.0
	chronicle.offset_bottom = 198.0
	chronicle.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.040, 0.060, 0.84)))
	ui_root.add_child(chronicle)
	var chronicle_margin := MarginContainer.new()
	chronicle_margin.add_theme_constant_override("margin_left", 10)
	chronicle_margin.add_theme_constant_override("margin_right", 10)
	chronicle_margin.add_theme_constant_override("margin_top", 7)
	chronicle_margin.add_theme_constant_override("margin_bottom", 7)
	chronicle.add_child(chronicle_margin)
	var chronicle_content := VBoxContainer.new()
	chronicle_content.add_theme_constant_override("separation", 4)
	chronicle_margin.add_child(chronicle_content)
	chronicle_content.add_child(_make_label("WORLD CHRONICLE", 11, Color(0.46, 0.86, 0.98)))
	log_label = _make_label("Waiting for history to happen...", 10, Color(0.76, 0.83, 0.86))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chronicle_content.add_child(log_label)

	# City controls float only while a city is selected.
	city_context_panel = PanelContainer.new()
	city_context_panel.anchor_left = 1.0
	city_context_panel.anchor_right = 1.0
	city_context_panel.anchor_top = 0.0
	city_context_panel.anchor_bottom = 0.0
	city_context_panel.offset_left = -326.0
	city_context_panel.offset_right = -12.0
	city_context_panel.offset_top = 90.0
	city_context_panel.offset_bottom = 408.0
	city_context_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.040, 0.060, 0.94)))
	ui_root.add_child(city_context_panel)
	var city_margin := MarginContainer.new()
	city_margin.add_theme_constant_override("margin_left", 12)
	city_margin.add_theme_constant_override("margin_right", 12)
	city_margin.add_theme_constant_override("margin_top", 10)
	city_margin.add_theme_constant_override("margin_bottom", 10)
	city_context_panel.add_child(city_margin)
	var city_content := VBoxContainer.new()
	city_content.add_theme_constant_override("separation", 6)
	city_margin.add_child(city_content)
	city_content.add_child(_make_label("CITY OVERVIEW", 12, Color(0.46, 0.86, 0.98)))
	city_info_label = _make_label("Select a city to inspect its status.", 11, Color(0.86, 0.89, 0.91))
	city_info_label.custom_minimum_size = Vector2(0.0, 126.0)
	city_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_content.add_child(city_info_label)
	control_button = _make_button("TAKE CONTROL", _take_control, Color(0.12, 0.36, 0.43))
	city_content.add_child(control_button)
	missile_button = _make_button("Launch Missile", func(): _prepare_action("missile"), Color(0.45, 0.19, 0.12))
	city_content.add_child(missile_button)
	invasion_button = _make_button("Order Invasion", func(): _prepare_action("army"), Color(0.39, 0.20, 0.16))
	city_content.add_child(invasion_button)
	ceasefire_button = _make_button("Offer Ceasefire", func(): _prepare_action("peace"), Color(0.20, 0.30, 0.34))
	city_content.add_child(ceasefire_button)
	pending_label = _make_label("Select a city, or pick a world tool below.", 10, Color(0.98, 0.77, 0.43))
	pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_content.add_child(pending_label)
	city_context_panel.visible = false

	# Bottom tool dock is split into world tools and god powers.
	var dock := PanelContainer.new()
	dock.anchor_left = 0.5
	dock.anchor_right = 0.5
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = -534.0
	dock.offset_right = 534.0
	dock.offset_top = -194.0
	dock.offset_bottom = -10.0
	dock.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.040, 0.060, 0.95)))
	ui_root.add_child(dock)
	var dock_margin := MarginContainer.new()
	dock_margin.add_theme_constant_override("margin_left", 12)
	dock_margin.add_theme_constant_override("margin_right", 12)
	dock_margin.add_theme_constant_override("margin_top", 8)
	dock_margin.add_theme_constant_override("margin_bottom", 8)
	dock.add_child(dock_margin)
	var dock_content := VBoxContainer.new()
	dock_content.add_theme_constant_override("separation", 5)
	dock_margin.add_child(dock_content)
	tool_label = _make_label("WORLD TOOLS · Select and inspect cities", 10, Color(0.77, 0.84, 0.88))
	dock_content.add_child(tool_label)
	var tools_grid := GridContainer.new()
	tools_grid.columns = 8
	tools_grid.add_theme_constant_override("h_separation", 5)
	tools_grid.add_theme_constant_override("v_separation", 5)
	dock_content.add_child(tools_grid)
	_add_tool_button(tools_grid, "Select", "select", Color(0.12, 0.23, 0.30))
	_add_tool_button(tools_grid, "Raise", "raise", Color(0.29, 0.32, 0.20))
	_add_tool_button(tools_grid, "Lower", "lower", Color(0.23, 0.29, 0.36))
	_add_tool_button(tools_grid, "Citizen", "human", Color(0.15, 0.32, 0.29))
	_add_tool_button(tools_grid, "Trees", "tree", Color(0.12, 0.30, 0.20))
	_add_tool_button(tools_grid, "Stone", "stone", Color(0.27, 0.29, 0.31))
	_add_tool_button(tools_grid, "Food", "food", Color(0.35, 0.22, 0.21))
	_add_tool_button(tools_grid, "Erase", "erase", Color(0.29, 0.17, 0.19))
	var powers_grid := GridContainer.new()
	powers_grid.columns = 8
	powers_grid.add_theme_constant_override("h_separation", 5)
	powers_grid.add_theme_constant_override("v_separation", 5)
	dock_content.add_child(powers_grid)
	_add_tool_button(powers_grid, "Lightning", "lightning", Color(0.14, 0.36, 0.57))
	_add_tool_button(powers_grid, "Fire", "fire", Color(0.58, 0.23, 0.09))
	_add_tool_button(powers_grid, "Meteor", "meteor", Color(0.52, 0.16, 0.12))
	_add_tool_button(powers_grid, "Tornado", "tornado", Color(0.31, 0.35, 0.43))
	_add_tool_button(powers_grid, "Plague", "plague", Color(0.34, 0.26, 0.40))
	_add_tool_button(powers_grid, "Heal", "heal", Color(0.12, 0.42, 0.30))
	_add_tool_button(powers_grid, "Forest", "forest", Color(0.10, 0.36, 0.19))
	_add_tool_button(powers_grid, "Quake", "quake", Color(0.42, 0.30, 0.16))
	var brush_row := HBoxContainer.new()
	brush_row.add_theme_constant_override("separation", 7)
	dock_content.add_child(brush_row)
	brush_row.add_child(_make_button("−", func(): _change_brush(-1.0), Color(0.13, 0.18, 0.23)))
	radius_label = _make_label("Radius 4.0", 10, Color(0.84, 0.88, 0.90))
	radius_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radius_label.custom_minimum_size = Vector2(80.0, 0.0)
	brush_row.add_child(radius_label)
	brush_row.add_child(_make_button("+", func(): _change_brush(1.0), Color(0.13, 0.18, 0.23)))
	brush_row.add_child(_make_label("Click a tool, then click or drag on the world · RMB orbit · MMB pan · Wheel zoom", 10, Color(0.61, 0.70, 0.76)))
	_refresh_ui()


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
		_log("Choose a city and press TAKE CONTROL first.")
		return
	if action == "missile" and _world_year() < MISSILE_UNLOCK_YEAR:
		_log("Missiles unlock in 1945. Use DEBUG ERA to jump forward.")
		_refresh_ui()
		return
	pending_action = action
	tool_mode = "select"
	for existing_mode in tool_buttons.keys():
		var button: Button = tool_buttons[existing_mode]
		button.modulate = Color(1.18, 1.18, 1.18) if existing_mode == "select" else Color(0.82, 0.86, 0.89)
	_refresh_ui()
	_log("Order ready: %s." % ("click any ground point for the missile" if action == "missile" else "click a target city on the map"))


func _toggle_pause() -> void:
	paused = not paused
	if is_instance_valid(pause_button):
		pause_button.text = "Resume Simulation" if paused else "Pause Simulation"
	_log("Simulation %s." % ("paused" if paused else "resumed"))


func _cycle_speed() -> void:
	# Cycle through increasingly fast simulation rates while keeping the
	# current one-button control simple: 1x -> 2x -> 4x -> 8x -> 16x -> 1x.
	if is_equal_approx(sim_speed, 1.0):
		sim_speed = 2.0
	elif is_equal_approx(sim_speed, 2.0):
		sim_speed = 4.0
	elif is_equal_approx(sim_speed, 4.0):
		sim_speed = 8.0
	elif is_equal_approx(sim_speed, 8.0):
		sim_speed = 16.0
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
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.53, 0.59, 0.63))
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
	# Keep the buttons in one dark design system while retaining each tool's
	# colour as a subdued accent rather than a row of unrelated bright blocks.
	var base_color := Color(0.045, 0.065, 0.082)
	style.bg_color = base_color.lerp(color, 0.40)
	var border_color: Color = base_color.lerp(color.lightened(0.20), 0.66)
	border_color.a = 0.88
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.22, 0.48, 0.58, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
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
	var population_counts: Array[int] = _population_counts_by_city()
	var year: int = _world_year()
	if is_instance_valid(stats_label):
		stats_label.text = "YEAR %d  ·  %s     CITIES %02d  ·  PEOPLE %03d  ·  CARS %02d  ·  WARS %02d  ·  EVENTS %03d" % [year, _historical_era_name(year), cities.size(), people.size(), cars.size(), wars.size(), city_events_total]
	if is_instance_valid(era_skipper):
		var matching_era_index: int = 0
		for era_index in range(ERA_SKIP_YEARS.size()):
			if ERA_SKIP_YEARS[era_index] <= year:
				matching_era_index = era_index
		if era_skipper.selected != matching_era_index:
			era_skipper.select(matching_era_index)
	if is_instance_valid(pause_button):
		pause_button.text = "RESUME" if paused else "PAUSE"
	if is_instance_valid(speed_button):
		speed_button.text = "%d×" % int(sim_speed)
	for node in ui_root.find_children("*", "Button", true, false):
		var setting_button: Button = node as Button
		if setting_button.text.begins_with("Reset Speed on City Event:") or setting_button.text.begins_with("EVENT 1×:"):
			setting_button.text = "EVENT 1×: ON" if reset_speed_on_city_event else "EVENT 1×: OFF"
	if is_instance_valid(selection_ring):
		if selected_city >= 0 and selected_city < cities.size():
			selection_ring.visible = true
			selection_ring.position = cities[selected_city]["pos"] + Vector3(0.0, 0.20, 0.0)
		else:
			selection_ring.visible = false
	if is_instance_valid(tool_label):
		var tool_names: Dictionary = {"select": "WORLD TOOLS · Select city", "raise": "WORLD TOOLS · Raise terrain", "lower": "WORLD TOOLS · Lower terrain", "human": "WORLD TOOLS · Spawn citizens", "tree": "WORLD TOOLS · Plant trees", "stone": "WORLD TOOLS · Place stone", "food": "WORLD TOOLS · Place food", "erase": "WORLD TOOLS · Erase object", "lightning": "GOD POWERS · Lightning", "fire": "GOD POWERS · Fire", "meteor": "GOD POWERS · Meteor", "tornado": "GOD POWERS · Tornado", "plague": "GOD POWERS · Plague", "heal": "GOD POWERS · Bless", "forest": "GOD POWERS · Forest", "quake": "GOD POWERS · Earthquake"}
		tool_label.text = str(tool_names.get(tool_mode, "WORLD TOOLS · Select city"))
	for city_index in range(cities.size()):
		var population_now: int = population_counts[city_index]
		cities[city_index]["population"] = population_now
		var stage: int = int(cities[city_index].get("stage", 0))
		if is_instance_valid(cities[city_index]["label"]):
			var label_status: String = "RUINS" if bool(cities[city_index].get("ruined", false)) else ("ABANDONED" if population_now <= 0 else _city_stage_name(stage))
			var label_text: String = "%s\n%s | POP %d" % [cities[city_index]["name"], label_status, population_now]
			if cities[city_index]["label"].text != label_text:
				cities[city_index]["label"].text = label_text
			cities[city_index]["label"].modulate = Color(0.66, 0.70, 0.72) if population_now <= 0 else Color.WHITE
	if is_instance_valid(city_context_panel):
		city_context_panel.visible = selected_city >= 0 and selected_city < cities.size()
	if is_instance_valid(city_info_label):
		if selected_city >= 0 and selected_city < cities.size():
			var city: Dictionary = cities[selected_city]
			var owner_id: int = int(city["owner"])
			var owner_name: String = cities[owner_id]["name"] if owner_id >= 0 and owner_id < cities.size() else city["name"]
			city_info_label.text = "%s\n%s · POP %d\nTERRITORY %d land tiles\nSTABILITY %.0f%% · SECURITY %.0f%%\nWEALTH %d · OWNER %s\nFOOD %d · WOOD %d · STONE %d" % [city["name"], _city_stage_name(int(city.get("stage", 0))), _city_population(selected_city), (city.get("territory_cells", {}) as Dictionary).size(), float(city.get("stability", 72.0)), float(city.get("security", 44.0)), int(city.get("wealth", 12.0)), owner_name, int(city["food"]), int(city["wood"]), int(city["stone"])]
		else:
			city_info_label.text = "Select a city to inspect it."
	if is_instance_valid(control_button):
		control_button.text = "COMMANDING: %s" % cities[controlled_city]["name"] if controlled_city >= 0 and controlled_city < cities.size() else "TAKE CONTROL"
	if is_instance_valid(missile_button):
		missile_button.disabled = year < MISSILE_UNLOCK_YEAR or controlled_city < 0 or controlled_city >= cities.size()
		missile_button.tooltip_text = "Missiles unlock in 1945." if year < MISSILE_UNLOCK_YEAR else "Choose this, then click any point on the world."
	if is_instance_valid(invasion_button):
		invasion_button.disabled = controlled_city < 0 or controlled_city >= cities.size()
	if is_instance_valid(ceasefire_button):
		ceasefire_button.disabled = controlled_city < 0 or controlled_city >= cities.size()
	if is_instance_valid(pending_label):
		match pending_action:
			"missile":
				pending_label.text = "MISSILE: click any ground point on the map."
			"army":
				pending_label.text = "INVASION: click the target city."
			"peace":
				pending_label.text = "CEASEFIRE: click the other city."
			_:
				pending_label.text = "Select a city, or pick a world tool below."
	if is_instance_valid(log_label):
		log_label.text = _joined_logs()


func _update_world_detail_levels() -> void:
	var active_lod: int = _terrain_lod_index_for_distance(camera_distance)
	if active_lod < terrain_lod_dirty.size() and terrain_lod_dirty[active_lod]:
		_build_terrain_lod(active_lod)
	for lod_index in range(terrain_lod_nodes.size()):
		terrain_lod_nodes[lod_index].visible = lod_index == active_lod
	var show_city_models: bool = camera_distance <= 165.0
	var show_neighbourhoods: bool = camera_distance <= 135.0
	var show_resources: bool = camera_distance <= 110.0
	var show_people: bool = camera_distance <= 85.0
	var show_city_labels: bool = camera_distance >= 48.0
	var show_far_markers: bool = not show_city_models
	var focus_cell_x: int = floori(camera_target.x / 10.0)
	var focus_cell_z: int = floori(camera_target.z / 10.0)
	var building_count: int = 0
	for city in cities:
		building_count += city["houses"].size()
	var detail_signature: String = "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		active_lod, int(show_city_models), int(show_neighbourhoods), int(show_resources),
		int(show_people), int(show_city_labels), int(show_far_markers), cities.size(),
		building_count, people.size(), resources.size(), cars.size() + rubble_records.size(),
		focus_cell_x, focus_cell_z
	]
	if detail_signature == last_detail_signature:
		return
	last_detail_signature = detail_signature
	for city in cities:
		var ruined: bool = bool(city.get("ruined", false))
		for visual_key in ["plinth", "body", "roof", "flag_pole", "flag"]:
			var city_visual: MeshInstance3D = city[visual_key]
			if is_instance_valid(city_visual):
				city_visual.visible = show_city_models and not ruined
		var zone_fill: MeshInstance3D = city["zone_fill"]
		var zone_border: MeshInstance3D = city["zone_border"]
		if is_instance_valid(zone_fill):
			zone_fill.visible = camera_distance <= 165.0 and not ruined
		if is_instance_valid(zone_border):
			zone_border.visible = camera_distance <= TERRAIN_SIZE * 2.0 and not ruined
		var far_marker: MeshInstance3D = city["far_marker"]
		if is_instance_valid(far_marker):
			far_marker.visible = show_far_markers and not ruined
		var city_label: Label3D = city["label"]
		if is_instance_valid(city_label):
			city_label.visible = show_city_labels
		var roads: MeshInstance3D = city["roads"]
		if is_instance_valid(roads):
			roads.visible = show_neighbourhoods and not ruined
		var sidewalks: MeshInstance3D = city.get("sidewalks") as MeshInstance3D
		if is_instance_valid(sidewalks):
			sidewalks.visible = show_neighbourhoods and not ruined
		for house in city["houses"]:
			if is_instance_valid(house):
				house.visible = show_neighbourhoods and not ruined
	var person_range: float = clampf(camera_distance * 0.54, 22.0, 68.0)
	var person_range_squared: float = person_range * person_range
	for person in people:
		var person_node: Node3D = person["node"]
		if not is_instance_valid(person_node):
			continue
		var position: Vector3 = person["pos"]
		var dx: float = position.x - camera_target.x
		var dz: float = position.z - camera_target.z
		var indoors: bool = str(person.get("activity", "")) == "indoors" or str(person.get("activity", "")) == "riding"
		person_node.visible = show_people and not indoors and bool(person.get("alive", true)) and dx * dx + dz * dz <= person_range_squared
	for car in cars:
		var car_node: Node3D = car["node"]
		if not is_instance_valid(car_node):
			continue
		var car_position: Vector3 = car["pos"]
		var dx: float = car_position.x - camera_target.x
		var dz: float = car_position.z - camera_target.z
		var render_range: float = maxf(42.0, camera_distance * 0.68)
		car_node.visible = show_neighbourhoods and dx * dx + dz * dz <= render_range * render_range
	for resource in resources:
		var resource_node: Node3D = resource["node"]
		if is_instance_valid(resource_node):
			resource_node.visible = show_resources and bool(resource.get("alive", true)) and int(resource.get("amount", 1)) > 0


func _run_save_load_smoke_test() -> void:
	reset_speed_on_city_event = true
	sim_speed = 16.0
	_record_city_event(0, "SMOKE TEST", Color(0.30, 0.80, 0.95))
	if not is_equal_approx(sim_speed, 1.0):
		push_error("SAVE_LOAD_TEST_FAILED: City event did not reset simulation speed to 1x.")
		get_tree().quit(1)
		return
	var expected_reset_speed_setting: bool = reset_speed_on_city_event
	var expected_sim_speed: float = sim_speed
	var expected_city_count: int = cities.size()
	var expected_people_count: int = people.size()
	var expected_resource_count: int = 0
	for resource in resources:
		if bool(resource.get("alive", true)) and int(resource.get("amount", 0)) > 0:
			expected_resource_count += 1
	var expected_height: float = float(terrain_heights[7][11])
	var expected_food: float = float(cities[0]["food"])
	cities[0]["destroyed_building_debt"] = int(cities[0].get("destroyed_building_debt", 0)) + 1
	cities[0]["next_plot_index"] = maxi(int(cities[0].get("next_plot_index", 0)), 9)
	var expected_destroyed_debt: int = int(cities[0]["destroyed_building_debt"])
	var expected_next_plot_index: int = int(cities[0]["next_plot_index"])
	if rubble_records.is_empty():
		_spawn_persistent_rubble(cities[0]["pos"] + Vector3(4.0, 0.0, 4.0), false, Color(0.42, 0.40, 0.37))
	var expected_rubble_count: int = rubble_records.size()

	_save_world()
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("SAVE_LOAD_TEST_FAILED: Save World did not create a save file.")
		get_tree().quit(1)
		return

	terrain_heights[7][11] = expected_height + 3.0
	cities[0]["food"] = 0.0
	_rebuild_terrain()
	_load_world()

	if cities.size() != expected_city_count:
		push_error("SAVE_LOAD_TEST_FAILED: City count changed during load.")
		get_tree().quit(1)
		return
	if people.size() != expected_people_count:
		push_error("SAVE_LOAD_TEST_FAILED: Population count changed during load.")
		get_tree().quit(1)
		return
	if resources.size() != expected_resource_count:
		push_error("SAVE_LOAD_TEST_FAILED: Active resource count changed during load.")
		get_tree().quit(1)
		return
	if absf(float(terrain_heights[7][11]) - expected_height) > 0.001:
		push_error("SAVE_LOAD_TEST_FAILED: Terrain height was not restored.")
		get_tree().quit(1)
		return
	if absf(float(cities[0]["food"]) - expected_food) > 0.001:
		push_error("SAVE_LOAD_TEST_FAILED: City stock was not restored.")
		get_tree().quit(1)
		return
	if int(cities[0].get("destroyed_building_debt", 0)) != expected_destroyed_debt:
		push_error("SAVE_LOAD_TEST_FAILED: Destroyed building debt was not restored.")
		get_tree().quit(1)
		return
	if int(cities[0].get("next_plot_index", 0)) < expected_next_plot_index:
		push_error("SAVE_LOAD_TEST_FAILED: City building plot index was not restored.")
		get_tree().quit(1)
		return
	if rubble_records.size() != expected_rubble_count:
		push_error("SAVE_LOAD_TEST_FAILED: Rubble was not restored.")
		get_tree().quit(1)
		return
	if reset_speed_on_city_event != expected_reset_speed_setting or not is_equal_approx(sim_speed, expected_sim_speed):
		push_error("SAVE_LOAD_TEST_FAILED: City-event speed preference was not restored.")
		get_tree().quit(1)
		return

	print("CIVITERRA_SAVE_LOAD_TEST_PASSED")
	get_tree().quit(0)


func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _array_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var parts: Array = value
	if parts.size() < 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _serialize_city_buildings(city: Dictionary) -> Array:
	var saved_buildings: Array = []
	for house in city.get("houses", []):
		if not is_instance_valid(house):
			continue
		saved_buildings.append({
			"pos": _vector3_to_array(house.position),
			"base_type": int(house.get_meta("base_building_type", house.get_meta("building_type", 0))),
			"plot_index": int(house.get_meta("plot_index", 0))
		})
	return saved_buildings


func _save_world() -> void:
	var saved_cities: Array = []
	for city in cities:
		saved_cities.append({
			"name": str(city["name"]),
			"pos": _vector3_to_array(city["pos"]),
			"color": (city["color"] as Color).to_html(true),
			"owner": int(city["owner"]),
			"food": float(city["food"]),
			"wood": float(city["wood"]),
			"stone": float(city["stone"]),
			"stability": float(city.get("stability", 72.0)),
			"security": float(city.get("security", 44.0)),
			"wealth": float(city.get("wealth", 12.0)),
			"stage": int(city.get("stage", 0)),
			"abandoned": bool(city.get("abandoned", false)),
			"abandoned_age": float(city.get("abandoned_age", 0.0)),
			"abandoned_decay_timer": float(city.get("abandoned_decay_timer", 8.0)),
			"ruined": bool(city.get("ruined", false)),
			"buildings": _serialize_city_buildings(city),
			"destroyed_building_debt": int(city.get("destroyed_building_debt", 0)),
			"next_plot_index": int(city.get("next_plot_index", 0))
		})

	var saved_people: Array = []
	for person in people:
		var p: Vector3 = person["pos"]
		var target: Vector3 = person["target"]
		saved_people.append({
			"pos": _vector3_to_array(p),
			"target": _vector3_to_array(target),
			"city_id": int(person["city_id"]),
			"home_offset": [float(person.get("home_offset", Vector2.ZERO).x), float(person.get("home_offset", Vector2.ZERO).y)],
			"alive": bool(person.get("alive", true)),
			"infected": bool(person.get("infected", false)),
			"infection_time": float(person.get("infection_time", 0.0)),
			"spread_timer": float(person.get("spread_timer", 1.0)),
			"walk_timer": float(person.get("walk_timer", 1.0))
		})

	var saved_resources: Array = []
	for resource in resources:
		if not bool(resource.get("alive", true)) or int(resource.get("amount", 0)) <= 0:
			continue
		saved_resources.append({
			"pos": _vector3_to_array(resource["pos"]),
			"type": str(resource["type"]),
			"amount": int(resource["amount"])
		})

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"terrain_size": TERRAIN_SIZE,
		"world_seed": world_seed,
		"game_clock": game_clock,
		"terrain_heights": terrain_heights,
		"cities": saved_cities,
		"people": saved_people,
		"resources": saved_resources,
		"rubble": rubble_records,
		"selected_city": selected_city,
		"controlled_city": controlled_city,
		"camera_target": _vector3_to_array(camera_target),
		"camera_distance": camera_distance,
		"camera_yaw": camera_yaw,
		"camera_pitch": camera_pitch,
		"sim_speed": sim_speed,
		"reset_speed_on_city_event": reset_speed_on_city_event,
		"city_events_total": city_events_total
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_log("SAVE FAILED: Could not open the world save file.")
		return
	file.store_string(JSON.stringify(save_data))
	file.close()
	_log("WORLD SAVED: Terrain, cities, people, resources, city damage, rubble, camera, and simulation time saved locally.")


func _adapt_saved_heightmap(saved_heights: Array, saved_world_size: float) -> Array:
	if saved_heights.size() == TERRAIN_RES and is_equal_approx(saved_world_size, TERRAIN_SIZE):
		return saved_heights
	var result: Array = terrain_heights.duplicate(true)
	var old_resolution: int = saved_heights.size()
	if old_resolution < 2 or saved_world_size <= 0.0:
		return result
	var old_half: float = saved_world_size * 0.5
	for z_index in range(TERRAIN_RES):
		var world_z: float = (float(z_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
		if absf(world_z) > old_half:
			continue
		var old_z: int = clampi(roundi((world_z / saved_world_size + 0.5) * float(old_resolution - 1)), 0, old_resolution - 1)
		var row: Array = result[z_index]
		var saved_row: Array = saved_heights[old_z]
		for x_index in range(TERRAIN_RES):
			var world_x: float = (float(x_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
			if absf(world_x) > old_half:
				continue
			var old_x: int = clampi(roundi((world_x / saved_world_size + 0.5) * float(old_resolution - 1)), 0, old_resolution - 1)
			row[x_index] = float(saved_row[old_x])
		result[z_index] = row
	return result


func _load_world() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_log("LOAD FAILED: No saved world exists yet. Use Save World first.")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_log("LOAD FAILED: Could not read the world save file.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_log("LOAD FAILED: The save file is invalid or corrupted.")
		return
	var save_data: Dictionary = parsed
	var save_version: int = int(save_data.get("version", 1))
	if save_version < 1 or save_version > SAVE_VERSION:
		_log("LOAD FAILED: This save uses an unsupported version.")
		return
	var raw_heights: Variant = save_data.get("terrain_heights", [])
	if typeof(raw_heights) != TYPE_ARRAY or raw_heights.size() < 32:
		_log("LOAD FAILED: The save has an incompatible terrain grid.")
		return
	var saved_height_resolution: int = raw_heights.size()
	var saved_terrain_size: float = float(save_data.get("terrain_size", 160.0 if save_version == 1 else TERRAIN_SIZE))
	var restored_heights: Array = []
	for raw_row in raw_heights:
		if typeof(raw_row) != TYPE_ARRAY or raw_row.size() != saved_height_resolution:
			_log("LOAD FAILED: The saved terrain grid is incomplete.")
			return
		var row: Array = []
		for height_value in raw_row:
			row.append(float(height_value))
		restored_heights.append(row)

	var saved_cities: Variant = save_data.get("cities", [])
	var saved_people: Variant = save_data.get("people", [])
	var saved_resources: Variant = save_data.get("resources", [])
	var saved_rubble: Variant = save_data.get("rubble", [])
	if typeof(saved_cities) != TYPE_ARRAY or typeof(saved_people) != TYPE_ARRAY or typeof(saved_resources) != TYPE_ARRAY or typeof(saved_rubble) != TYPE_ARRAY:
		_log("LOAD FAILED: The save is missing world data.")
		return
	if saved_cities.is_empty():
		_log("LOAD FAILED: The save does not contain any cities.")
		return

	_clear_loaded_world()
	world_seed = int(save_data.get("world_seed", 14029))
	seed(world_seed)
	_generate_terrain_heights() # Refresh climate noise from the saved seed.
	terrain_heights = _adapt_saved_heightmap(restored_heights, saved_terrain_size)
	_rebuild_terrain()
	game_clock = float(save_data.get("game_clock", 0.0))
	city_events_total = int(save_data.get("city_events_total", 0))
	wars.clear()
	armies.clear()
	missiles.clear()
	explosions.clear()
	god_effects.clear()
	fire_zones.clear()
	falling_meteors.clear()
	tornadoes.clear()
	log_entries.clear()
	pending_action = ""
	camera_auto_zoom_active = false
	camera_auto_zoom_follow_city = false

	for saved_city in saved_cities:
		if typeof(saved_city) != TYPE_DICTIONARY:
			continue
		var city_data: Dictionary = saved_city
		var position: Vector3 = _array_to_vector3(city_data.get("pos", []))
		position.y = _height_at(position.x, position.z)
		var city_color: Color = Color.from_string(str(city_data.get("color", "d8e4e8")), Color(0.20, 0.65, 0.85))
		var city_name: String = str(city_data.get("name", "New Settlement"))
		var city_id: int = _create_city(position, city_name, city_color)
		var city: Dictionary = cities[city_id]
		city["owner"] = clampi(int(city_data.get("owner", city_id)), 0, saved_cities.size() - 1)
		city["food"] = float(city_data.get("food", 8.0))
		city["wood"] = float(city_data.get("wood", 5.0))
		city["stone"] = float(city_data.get("stone", 3.0))
		city["stability"] = float(city_data.get("stability", 72.0))
		city["security"] = float(city_data.get("security", 44.0))
		city["wealth"] = float(city_data.get("wealth", 12.0))
		city["stage"] = clampi(int(city_data.get("stage", 0)), 0, 4)
		city["abandoned"] = bool(city_data.get("abandoned", false))
		city["abandoned_age"] = maxf(0.0, float(city_data.get("abandoned_age", 0.0)))
		city["abandoned_decay_timer"] = maxf(0.0, float(city_data.get("abandoned_decay_timer", 8.0)))
		city["ruined"] = bool(city_data.get("ruined", false))
		city["destroyed_building_debt"] = maxi(0, int(city_data.get("destroyed_building_debt", 0)))
		city["next_plot_index"] = maxi(0, int(city_data.get("next_plot_index", 0)))
		var saved_buildings: Variant = city_data.get("buildings", [])
		if typeof(saved_buildings) == TYPE_ARRAY:
			for saved_building in saved_buildings:
				if typeof(saved_building) != TYPE_DICTIONARY:
					continue
				var building_data: Dictionary = saved_building
				var house := Node3D.new()
				house.position = _array_to_vector3(building_data.get("pos", [0.0, 0.0, 0.0]))
				city["node"].add_child(house)
				var base_type: int = int(building_data.get("base_type", 0))
				house.set_meta("building_type", base_type)
				house.set_meta("base_building_type", base_type)
				house.set_meta("plot_index", int(building_data.get("plot_index", 0)))
				city["houses"].append(house)
		cities[city_id] = city

	for saved_person in saved_people:
		if typeof(saved_person) != TYPE_DICTIONARY or people.size() >= MAX_PEOPLE:
			continue
		var person_data: Dictionary = saved_person
		var person_position: Vector3 = _array_to_vector3(person_data.get("pos", []))
		person_position.y = _height_at(person_position.x, person_position.z)
		var city_id: int = int(person_data.get("city_id", -1))
		if city_id < 0 or city_id >= cities.size():
			city_id = -1
		_spawn_human(person_position, city_id)
		var person_index: int = people.size() - 1
		var person: Dictionary = people[person_index]
		person["target"] = _array_to_vector3(person_data.get("target", _vector3_to_array(person_position)))
		person["city_id"] = city_id
		var saved_home_offset: Variant = person_data.get("home_offset", [])
		if typeof(saved_home_offset) == TYPE_ARRAY and saved_home_offset.size() >= 2:
			person["home_offset"] = Vector2(float(saved_home_offset[0]), float(saved_home_offset[1]))
		person["alive"] = bool(person_data.get("alive", true))
		person["infected"] = bool(person_data.get("infected", false))
		person["infection_time"] = float(person_data.get("infection_time", 0.0))
		person["spread_timer"] = float(person_data.get("spread_timer", 1.0))
		person["walk_timer"] = float(person_data.get("walk_timer", 1.0))
		var infection_marker: MeshInstance3D = person["infection_marker"]
		if is_instance_valid(infection_marker):
			infection_marker.visible = bool(person["infected"])
		people[person_index] = person

	for saved_resource in saved_resources:
		if typeof(saved_resource) != TYPE_DICTIONARY:
			continue
		var resource_data: Dictionary = saved_resource
		var resource_position: Vector3 = _array_to_vector3(resource_data.get("pos", []))
		resource_position.y = _height_at(resource_position.x, resource_position.z)
		var kind: String = str(resource_data.get("type", "tree"))
		if kind not in ["tree", "stone", "food"]:
			continue
		_spawn_resource(resource_position, kind, maxi(1, int(resource_data.get("amount", 1))))

	# Rebuild homes and territory after all people and cities exist, so borders
	# are calculated against the final city population and neighbouring zones.
	for city_id in range(cities.size()):
		var loaded_population: int = _city_population(city_id)
		if loaded_population > 0:
			cities[city_id]["stage"] = _city_stage_for_population(loaded_population)
		else:
			cities[city_id]["stage"] = clampi(int(cities[city_id].get("stage", 0)), 0, 4)
		_apply_city_stage_appearance(city_id)
	for city_id in range(cities.size()):
		_refresh_city_development(city_id)
		for house in cities[city_id]["houses"]:
			if is_instance_valid(house):
				house.scale = Vector3.ONE * (1.0 + float(cities[city_id].get("stage", 0)) * 0.07)
		_apply_building_era_appearance(city_id, _world_year())
	_refresh_city_territory(0)
	for city_id in range(cities.size()):
		_rebuild_city_roads(city_id)

	for rubble_entry_data in saved_rubble:
		if typeof(rubble_entry_data) != TYPE_DICTIONARY:
			continue
		var rubble_data: Dictionary = rubble_entry_data
		var rubble_position: Vector3 = _array_to_vector3(rubble_data.get("position", []))
		var rubble_color: Color = Color.from_string(str(rubble_data.get("color", "777777")), Color(0.42, 0.40, 0.37))
		_spawn_persistent_rubble(rubble_position, bool(rubble_data.get("tall", false)), rubble_color, true, str(rubble_data.get("kind", "building")), int(rubble_data.get("id", -1)))

	selected_city = int(save_data.get("selected_city", -1))
	if selected_city < 0 or selected_city >= cities.size():
		selected_city = -1
	controlled_city = int(save_data.get("controlled_city", -1))
	if controlled_city < 0 or controlled_city >= cities.size():
		controlled_city = -1
	camera_target = _array_to_vector3(save_data.get("camera_target", [0.0, 0.0, 0.0]))
	camera_distance = clampf(float(save_data.get("camera_distance", 94.0)), 24.0, TERRAIN_SIZE * 1.75)
	camera_yaw = float(save_data.get("camera_yaw", -0.72))
	camera_pitch = clampf(float(save_data.get("camera_pitch", 0.56)), 0.20, 1.25)
	sim_speed = clampf(float(save_data.get("sim_speed", 1.0)), 1.0, 16.0)
	reset_speed_on_city_event = bool(save_data.get("reset_speed_on_city_event", save_data.get("pause_on_city_event", false)))
	if is_instance_valid(speed_button):
		speed_button.text = "Simulation Speed: %s×" % str(int(sim_speed))
	for node in ui_root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text.begins_with("Reset Speed on City Event:"):
			button.text = "Reset Speed on City Event: ON" if reset_speed_on_city_event else "Reset Speed on City Event: OFF"
	paused = false
	_update_camera()
	_update_world_detail_levels()
	_refresh_ui()
	_log("WORLD LOADED: Saved terrain, cities, people, resources, and camera restored. Active battles and temporary effects are not saved yet.")


func _queue_nodes_from_entries(entries: Array) -> void:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = entry
		if item.has("node") and item["node"] is Node and is_instance_valid(item["node"]):
			(item["node"] as Node).queue_free()


func _clear_loaded_world() -> void:
	for existing_child in get_children():
		if existing_child is Node3D and existing_child.name in ["BuildingRubble", "VehicleWreck"]:
			existing_child.queue_free()
	rubble_records.clear()
	rubble_nodes.clear()
	rubble_id_sequence = 1
	for city in cities:
		for key in ["node", "zone_fill", "zone_border"]:
			if city.has(key) and city[key] is Node and is_instance_valid(city[key]):
				(city[key] as Node).queue_free()
	_queue_nodes_from_entries(people)
	_queue_nodes_from_entries(cars)
	_queue_nodes_from_entries(resources)
	_queue_nodes_from_entries(armies)
	_queue_nodes_from_entries(missiles)
	_queue_nodes_from_entries(explosions)
	_queue_nodes_from_entries(god_effects)
	_queue_nodes_from_entries(fire_zones)
	_queue_nodes_from_entries(falling_meteors)
	_queue_nodes_from_entries(tornadoes)
	_queue_nodes_from_entries(city_event_scenes)
	city_event_scenes.clear()
	cities.clear()
	people.clear()
	cars.clear()
	resources.clear()
	last_detail_signature = ""
	armies.clear()
	missiles.clear()
	explosions.clear()
	god_effects.clear()
	fire_zones.clear()
	falling_meteors.clear()
	tornadoes.clear()
	wars.clear()
	selected_city = -1
	controlled_city = -1


func _world_year() -> int:
	return STARTING_YEAR + int(game_clock / SECONDS_PER_YEAR)


func _historical_era_index(year: int) -> int:
	if year >= 2000:
		return 5
	if year >= 1950:
		return 4
	if year >= 1880:
		return 3
	if year >= 1780:
		return 2
	if year >= 1450:
		return 1
	return 0


func _historical_era_name(year: int) -> String:
	match _historical_era_index(year):
		5:
			return "CONTEMPORARY"
		4:
			return "MODERN AGE"
		3:
			return "SKYSCRAPER AGE"
		2:
			return "INDUSTRIAL AGE"
		1:
			return "RENAISSANCE"
		_:
			return "MEDIEVAL AGE"


func _on_era_skipper_selected(index: int) -> void:
	if index < 0 or index >= ERA_SKIP_YEARS.size():
		return
	var target_year: int = ERA_SKIP_YEARS[index]
	game_clock = maxf(0.0, float(target_year - STARTING_YEAR) * SECONDS_PER_YEAR)
	last_architecture_era = -1
	_update_historical_era(true)
	if target_year < 1900:
		for car in cars:
			if is_instance_valid(car.get("node")):
				car["node"].queue_free()
		cars.clear()
		_update_world_detail_levels()
	else:
		_update_traffic_population()
	_refresh_ui()
	_log("DEBUG ERA SKIP: Time set to %d (%s)." % [target_year, _historical_era_name(target_year)])


func _update_historical_era(force: bool = false) -> void:
	var year: int = _world_year()
	var era: int = _historical_era_index(year)
	if not force and era == last_architecture_era:
		return
	var previous_era: int = last_architecture_era
	last_architecture_era = era
	for city_id in range(cities.size()):
		_apply_building_era_appearance(city_id, year)
	if previous_era >= 0 and era > previous_era:
		_log("HISTORICAL SHIFT: %s begins in year %d. Cities can now develop new architecture and social events." % [_historical_era_name(year), year])


func _format_time(seconds: float) -> String:
	var total_seconds: int = int(seconds)
	var minutes: int = int(total_seconds / 60)
	var remainder: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remainder]
