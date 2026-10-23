extends Node3D

const TERRAIN_RES: int = 241
const TERRAIN_SIZE: float = 768.0
const TERRAIN_LOD_STEPS: Array[int] = [1, 2, 4, 8]
const TERRAIN_CHUNK_CELLS: int = 48
const TERRAIN_CHUNKS_PER_AXIS: int = 5
const TERRAIN_EDIT_REBUILD_INTERVAL: float = 0.12
const MAX_TERRAIN_CHUNKS_PER_FRAME: int = 1
const MAX_METEOR_IMPACTS_PER_FRAME: int = 2
const MAX_CITIES: int = 18
const MAX_PEOPLE: int = 1600
const MAX_CITY_POPULATION: int = 900
const MAX_CITY_HOUSES: int = 360
const MAX_TRANSPORTS: int = 48
const MAX_OIL_RIGS: int = 14
const MAX_BUILDINGS_PER_DEVELOPMENT_TICK: int = 1
const MAX_BUILDING_STARTS_PER_FRAME: int = 1
const BUILDING_VISUAL_MUTATION_INTERVAL_USEC: int = 120000
const CITY_ROAD_REBUILD_INTERVAL_USEC: int = 450000
const MAX_CONSTRUCTION_SITE_UPDATES_PER_FRAME: int = 16
const MAX_CARS: int = 36
const ROAD_GRID_SIZE: float = 7.5
const WATER_LEVEL: float = -0.15
const STARTING_YEAR: int = 1200
const SECONDS_PER_YEAR: float = 3.0
const TERRITORY_CELL_SIZE: float = 4.0
const SAVE_PATH: String = "user://civiterra_world.json"
const SAVE_VERSION: int = 6
const MISSILE_UNLOCK_YEAR: int = 1945
const ERA_SKIP_YEARS: Array[int] = [1200, 1450, 1780, 1880, 1950, 2000, 2026]
const TRADE_GOODS: Array[String] = ["food", "wood", "stone", "iron", "copper", "coal", "gold"]
const PERFORMANCE_LOG_PATH: String = "user://civiterra-performance.log"
const SLOW_OPERATION_THRESHOLD_USEC: int = 40000
const FRAME_HITCH_THRESHOLD_USEC: int = 100000
const MAX_ACTIVE_BUILDING_SMOKE_PUFFS: int = 72
const URBAN_FACADE_PALETTE := [
	Color(0.68, 0.57, 0.45), Color(0.50, 0.53, 0.53), Color(0.70, 0.48, 0.35),
	Color(0.43, 0.50, 0.43), Color(0.71, 0.67, 0.56), Color(0.40, 0.43, 0.44),
	Color(0.68, 0.52, 0.43), Color(0.58, 0.59, 0.56), Color(0.48, 0.39, 0.34)
]
const TOWER_FACADE_PALETTE := [
	Color(0.43, 0.48, 0.50), Color(0.59, 0.53, 0.46), Color(0.34, 0.40, 0.39),
	Color(0.48, 0.36, 0.32), Color(0.56, 0.59, 0.59), Color(0.40, 0.44, 0.48),
	Color(0.63, 0.60, 0.52), Color(0.37, 0.39, 0.39), Color(0.48, 0.47, 0.42)
]
const GLASS_PALETTE := [
	Color(0.45, 0.67, 0.70), Color(0.63, 0.68, 0.64), Color(0.58, 0.50, 0.40),
	Color(0.41, 0.56, 0.52), Color(0.48, 0.54, 0.60), Color(0.71, 0.66, 0.55),
	Color(0.38, 0.44, 0.47), Color(0.68, 0.61, 0.50)
]

var terrain: MeshInstance3D
var terrain_material: StandardMaterial3D
var terrain_lod_nodes: Array[MeshInstance3D] = []
var terrain_lod_chunk_nodes: Array = []
var terrain_lod_dirty: Array[bool] = [true, true, true, true]
var pending_terrain_edits: Array[Dictionary] = []
var pending_terrain_chunk_updates: Dictionary = {}
var pending_terrain_shoreline_change: bool = false
var terrain_rebuild_cooldown: float = 0.0
var last_road_terrain_lod: int = -1
var terrain_moisture_noise: FastNoiseLite
var terrain_temperature_noise: FastNoiseLite
var terrain_moisture_grid: Array = []
var terrain_temperature_grid: Array = []
var selection_ring: MeshInstance3D
var camera_auto_zoom_active: bool = false
var camera_auto_zoom_follow_city: bool = false
var camera_auto_zoom_target: float = 94.0
var camera_auto_focus_target: Vector3 = Vector3.ZERO
var terrain_heights: Array = []
var city_names: Array[String] = ["Asterfall", "Mossreach", "Copper Bay", "New Avalon", "Westhaven", "Emberplain", "Stonebridge", "Northstar", "Rivermark", "Sunfield", "Iron Harbor", "Redwood", "Cedar Flats", "Lakeview", "Port Sterling", "Mesa Vista", "Southpoint", "Clearwater"]
var city_colors: Array[Color] = [
	Color(0.17, 0.67, 0.93), Color(0.94, 0.48, 0.18), Color(0.62, 0.42, 0.88),
	Color(0.22, 0.76, 0.48), Color(0.91, 0.32, 0.40), Color(0.91, 0.76, 0.22),
	Color(0.24, 0.55, 0.91), Color(0.86, 0.43, 0.70), Color(0.42, 0.78, 0.77), Color(0.72, 0.72, 0.75)
]
var cities: Array = []
var people: Array = []
var cars: Array = []
var resources: Array = []
var transports: Array = []
var oil_rigs: Array = []
var alliances: Dictionary = {}
var _material_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var spiral_grid_offsets: Array[Vector2i] = []
var spiral_grid_position: Vector2i = Vector2i.ZERO
var spiral_grid_direction: Vector2i = Vector2i(1, 0)
var spiral_grid_segment_length: int = 1
var spiral_grid_segment_steps: int = 0
var spiral_grid_segments_at_length: int = 0
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
var city_relations: Dictionary = {}
var trade_timer: float = 0.0
var trade_events_total: int = 0
var transport_timer: float = 0.0
var oil_update_timer: float = 0.0
var diplomacy_timer: float = 0.0
var city_event_scenes: Array = []
var rubble_records: Array = []
var rubble_nodes: Array = []
var rubble_id_sequence: int = 1
var active_building_smoke_puffs: int = 0
var construction_sites: Array = []
var construction_id_sequence: int = 1
var construction_site_update_cursor: int = 0
var construction_simulation_clock: float = 0.0
var pending_city_development: Array[int] = []
var pending_city_development_set: Dictionary = {}
var pending_city_road_rebuilds: Array[int] = []
var pending_city_road_rebuild_set: Dictionary = {}
var next_city_road_rebuild_usec: int = 0
var next_building_visual_mutation_usec: int = 0
var building_visual_mutation_consumed_this_frame: bool = false
var building_start_budget_remaining: int = 0
var in_simulation_frame: bool = false
var is_loading_world: bool = false
var people_lod_proxy: MultiMeshInstance3D
var construction_tick_timer: float = 0.0
var abandoned_check_timer: float = 0.0
var rubble_aging_timer: float = 0.0
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
var performance_log: FileAccess
var performance_frame_count: int = 0
var stress_csv: FileAccess
var stress_suite_active: bool = false
var stress_suite_started_usec: int = 0
var stress_scenarios: Array[Dictionary] = []
var stress_scenario_index: int = -1
var stress_scenario_started_usec: int = 0
var stress_last_sample_usec: int = 0
var stress_repeat_started_usec: int = 0
var stress_scenarios_completed: int = 0
var stress_frames_total: int = 0
var stress_window_frame_ms: Array[float] = []
var stress_window_process_ms: Array[float] = []
var stress_scenario_frame_ms: Array[float] = []
var stress_scenario_process_ms: Array[float] = []
var stress_scenario_max_action_ms: float = 0.0
var stress_camera_lod_step: int = 0
var stress_last_frame_end_usec: int = 0
var stress_capture_name: String = ""
var stress_capture_wait_frames: int = 0
var stress_capture_sequence: int = 0

var camera: Camera3D
var camera_target: Vector3 = Vector3.ZERO
var camera_yaw: float = -0.72
var camera_pitch: float = 0.56
var camera_distance: float = 230.0
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
var chronicle_panel: PanelContainer
var chronicle_button: Button
var chronicle_expanded: bool = false
var traffic_light_records: Array = []
var traffic_light_timer: float = 0.0
var detail_refresh_cooldown: float = 0.0
var building_occlusion_refresh_cooldown: float = 0.0
var people_lod_refresh_cooldown: float = 0.0
var traffic_light_phase: int = 0
var traffic_lights_enabled: bool = false
var stuck_recovery_timer: float = 0.0
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
	performance_log = FileAccess.open(PERFORMANCE_LOG_PATH, FileAccess.WRITE)
	if performance_log != null:
		performance_log.store_line("Civiterra performance trace started. Slow-op threshold: %d ms; hitch threshold: %d ms." % [SLOW_OPERATION_THRESHOLD_USEC / 1000, FRAME_HITCH_THRESHOLD_USEC / 1000])
		performance_log.flush()
	randomize()
	world_seed = randi() & 0x7FFFFFFF
	seed(world_seed)
	_build_world()
	_build_people_lod_proxy()
	_build_ui()
	_seed_civilizations()
	_scatter_world_resources()
	_seed_oil_rigs()
	_set_tool("select")
	_log("Generated a multi-continent world. Seed: %d." % world_seed)
	_log("The world is alive. Select a city to inspect it, then take control to issue orders.")
	_log("Tip: spawn humans in a cluster and they can found a new settlement on their own.")
	_update_historical_era(true)
	_refresh_ui()
	var command_args: PackedStringArray = OS.get_cmdline_user_args()
	if command_args.has("--civiterra-runtime-stress-tests") or command_args.has("--civiterra-freeze-stress-test"):
		_start_runtime_stress_tests()
	if command_args.has("--civiterra-save-load-smoke-test"):
		call_deferred("_run_save_load_smoke_test")



func _trace_slow_operation(operation_name: String, started_usec: int) -> void:
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	if elapsed_usec >= SLOW_OPERATION_THRESHOLD_USEC:
		_write_performance_sample(operation_name, elapsed_usec)


func _write_performance_sample(operation_name: String, elapsed_usec: int) -> void:
	var building_count: int = 0
	for city in cities:
		building_count += (city.get("houses", []) as Array).size()
	var sample: String = "PERF %s %dms | frame=%d | year=%d | speed=%dx | cities=%d | buildings=%d | people=%d | cars=%d | construction_sites=%d | resources=%d | distance=%.1f" % [
		operation_name, int(elapsed_usec / 1000), performance_frame_count, _world_year(), int(sim_speed),
		cities.size(), building_count, people.size(), cars.size(), construction_sites.size(), resources.size(), camera_distance
	]
	print(sample)
	if performance_log != null:
		performance_log.store_line(sample)
		performance_log.flush()


func _start_runtime_stress_tests() -> void:
	stress_scenarios = [
		{"name": "baseline_1x", "duration": 7.0, "speed": 1.0, "action": "none"},
		{"name": "simulation_4x", "duration": 6.0, "speed": 4.0, "action": "none"},
		{"name": "simulation_16x", "duration": 8.0, "speed": 16.0, "action": "none"},
		{"name": "dense_cities_and_crowds", "duration": 9.0, "speed": 4.0, "action": "dense_cities"},
		{"name": "construction_and_era_refurbishment", "duration": 8.0, "speed": 8.0, "action": "construction"},
		{"name": "mass_civilian_spawn", "duration": 7.0, "speed": 4.0, "action": "spawn_wave"},
		{"name": "resources_and_traffic", "duration": 8.0, "speed": 8.0, "action": "resources_traffic"},
		{"name": "camera_zoom_and_lod_transitions", "duration": 7.0, "speed": 4.0, "action": "camera_lod"},
		{"name": "large_debris_field", "duration": 8.0, "speed": 8.0, "action": "debris"},
		{"name": "wildfire_plague_tornado", "duration": 8.0, "speed": 8.0, "action": "fire_plague"},
		{"name": "meteors_lightning_disasters", "duration": 9.0, "speed": 16.0, "action": "meteor_storm"},
		{"name": "earthquake_terrain_edits", "duration": 8.0, "speed": 4.0, "action": "terrain_edits"},
		{"name": "settlement_transport_network", "duration": 9.0, "speed": 8.0, "action": "transport_network"},
		{"name": "oil_rig_diplomacy_war", "duration": 9.0, "speed": 16.0, "action": "oil_wars"},
		{"name": "urban_battle_hostages_artillery", "duration": 9.0, "speed": 8.0, "action": "battle_hostages"},
		{"name": "mass_building_collapse", "duration": 9.0, "speed": 8.0, "action": "collapse"},
		{"name": "save_load_large_world_rebuild", "duration": 8.0, "speed": 1.0, "action": "save_load"},
		{"name": "combined_16x_city_load", "duration": 12.0, "speed": 16.0, "action": "combined"}
	]
	stress_suite_active = true
	stress_suite_started_usec = Time.get_ticks_usec()
	stress_scenario_index = -1
	stress_scenarios_completed = 0
	stress_frames_total = 0
	stress_csv = FileAccess.open("user://civiterra-stresstests.csv", FileAccess.WRITE)
	if stress_csv != null:
		stress_csv.store_line("record_type,scenario,elapsed_seconds,frame_samples,engine_fps,mean_wall_fps,avg_frame_interval_ms,p95_frame_interval_ms,p99_frame_interval_ms,max_frame_interval_ms,max_process_ms,max_action_ms,cities,buildings,citizens,cars,resources,rubble,fire_zones,meteors,tornadoes,effects,construction_sites,armies,missiles,transports,oil_rigs,alliances,hostages")
		stress_csv.flush()
	paused = false
	game_clock = float(2026 - STARTING_YEAR) * SECONDS_PER_YEAR
	last_architecture_era = -1
	_update_historical_era(true)
	sim_speed = 1.0
	camera_distance = 68.0
	if not cities.is_empty():
		camera_target = cities[0]["pos"]
	_update_camera()
	_refresh_ui()
	_stress_emit("STRESS_SUITE_BEGIN|commit_runtime=godot|scenarios=%d|rendering_fps=Engine.get_frames_per_second|note=GUI-rendered run where supported; process/frame timings are also recorded" % stress_scenarios.size())
	_begin_next_runtime_stress_scenario()


func _begin_next_runtime_stress_scenario() -> void:
	if stress_scenario_index >= 0:
		_finish_runtime_stress_scenario()
	stress_scenario_index += 1
	if stress_scenario_index >= stress_scenarios.size():
		_finish_runtime_stress_suite()
		return
	var scenario: Dictionary = stress_scenarios[stress_scenario_index]
	stress_window_frame_ms.clear()
	stress_window_process_ms.clear()
	stress_scenario_frame_ms.clear()
	stress_scenario_process_ms.clear()
	stress_scenario_max_action_ms = 0.0
	sim_speed = clampf(float(scenario.get("speed", 1.0)), 1.0, 16.0)
	paused = false
	var scenario_name: String = str(scenario["name"])
	if scenario_name in ["dense_cities_and_crowds", "large_debris_field", "mass_building_collapse"]:
		camera_distance = 38.0
	elif scenario_name in ["resources_and_traffic", "wildfire_plague_tornado"]:
		camera_distance = 54.0
	elif scenario_name == "earthquake_terrain_edits":
		camera_distance = 94.0
	else:
		camera_distance = 68.0
	if not cities.is_empty():
		camera_target = cities[0]["pos"]
	_update_camera()
	var begin_line: String = "STRESS_SCENARIO_BEGIN|%s|speed=%dx|duration=%.1fs|cities=%d|buildings=%d|citizens=%d|resources=%d|rubble=%d" % [
		scenario_name, int(sim_speed), float(scenario["duration"]), cities.size(), _total_building_count(), people.size(), resources.size(), rubble_nodes.size()
	]
	_stress_emit(begin_line)
	var action_name: String = str(scenario.get("action", "none"))
	var action_started_usec: int = Time.get_ticks_usec()
	if action_name != "none":
		_run_runtime_stress_action(action_name)
	var action_elapsed_ms: float = float(Time.get_ticks_usec() - action_started_usec) / 1000.0
	stress_scenario_max_action_ms = maxf(stress_scenario_max_action_ms, action_elapsed_ms)
	_stress_emit("STRESS_ACTION|scenario=%s|action=%s|duration_ms=%.2f|cities=%d|buildings=%d|citizens=%d|cars=%d|resources=%d|rubble=%d|fires=%d|meteors=%d|tornadoes=%d" % [
		scenario_name, action_name, action_elapsed_ms, cities.size(), _total_building_count(), people.size(), cars.size(), resources.size(), rubble_nodes.size(), fire_zones.size(), falling_meteors.size(), tornadoes.size()
	])
	stress_scenario_started_usec = Time.get_ticks_usec()
	stress_last_sample_usec = stress_scenario_started_usec
	stress_last_frame_end_usec = stress_scenario_started_usec
	stress_repeat_started_usec = stress_scenario_started_usec
	stress_capture_sequence = stress_scenario_index + 1
	stress_capture_name = "%02d_%s" % [stress_capture_sequence, scenario_name]
	stress_capture_wait_frames = 3


func _tick_runtime_stress_screenshot() -> void:
	if stress_capture_wait_frames <= 0 or stress_capture_name.is_empty():
		return
	stress_capture_wait_frames -= 1
	if stress_capture_wait_frames > 0:
		return
	var screenshot_dir: String = "user://civiterra-screenshots"
	var absolute_dir: String = ProjectSettings.globalize_path(screenshot_dir)
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		_stress_emit("STRESS_SCREENSHOT_FAILED|scenario=%s|reason=directory_error_%d" % [stress_capture_name, make_dir_error])
		stress_capture_name = ""
		return
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_stress_emit("STRESS_SCREENSHOT_FAILED|scenario=%s|reason=empty_viewport" % stress_capture_name)
		stress_capture_name = ""
		return
	var image_path: String = screenshot_dir.path_join(stress_capture_name + ".png")
	var save_error: Error = image.save_png(image_path)
	if save_error == OK:
		_stress_emit("STRESS_SCREENSHOT|scenario=%s|path=%s|width=%d|height=%d" % [stress_capture_name, image_path, image.get_width(), image.get_height()])
	else:
		_stress_emit("STRESS_SCREENSHOT_FAILED|scenario=%s|reason=save_error_%d" % [stress_capture_name, save_error])
	stress_capture_name = ""

func _tick_runtime_stress_tests() -> void:
	if not stress_suite_active or stress_scenario_index < 0 or stress_scenario_index >= stress_scenarios.size():
		return
	var now_usec: int = Time.get_ticks_usec()
	var scenario: Dictionary = stress_scenarios[stress_scenario_index]
	var scenario_elapsed: float = float(now_usec - stress_scenario_started_usec) / 1000000.0
	if scenario_elapsed >= float(scenario.get("duration", 8.0)):
		_begin_next_runtime_stress_scenario()
		return
	var active_action: String = str(scenario.get("action", ""))
	var repeat_interval_usec: int = 2500000
	var repeat_action: String = "combined_pulse"
	if active_action == "camera_lod":
		repeat_interval_usec = 1250000
		repeat_action = "camera_lod_pulse"
	if active_action == "terrain_edits":
		repeat_interval_usec = 1800000
		repeat_action = "terrain_edit_pulse"
	if active_action in ["combined", "camera_lod", "terrain_edits"] and now_usec - stress_repeat_started_usec >= repeat_interval_usec:
		var action_started_usec: int = Time.get_ticks_usec()
		_run_runtime_stress_action(repeat_action)
		var action_elapsed_ms: float = float(Time.get_ticks_usec() - action_started_usec) / 1000.0
		stress_scenario_max_action_ms = maxf(stress_scenario_max_action_ms, action_elapsed_ms)
		_stress_emit("STRESS_ACTION|scenario=%s|action=%s|duration_ms=%.2f|citizens=%d|resources=%d|rubble=%d|fires=%d|tornadoes=%d|camera_distance=%.1f" % [
			str(scenario["name"]), repeat_action, action_elapsed_ms, people.size(), resources.size(), rubble_nodes.size(), fire_zones.size(), tornadoes.size(), camera_distance
		])
		stress_repeat_started_usec = Time.get_ticks_usec()


func _record_runtime_stress_frame(delta: float, process_usec: int) -> void:
	var now_usec: int = Time.get_ticks_usec()
	# Use the wall-clock time between actual frame samples, not just Godot's
	# delta. Some engines clamp delta after a long stall; doing so here would
	# conceal exactly the multi-second hitch this suite is intended to measure.
	var interval_ms: float = maxf(0.01, delta * 1000.0)
	if stress_last_frame_end_usec > 0:
		interval_ms = maxf(0.01, float(now_usec - stress_last_frame_end_usec) / 1000.0)
	stress_last_frame_end_usec = now_usec
	var process_ms: float = float(process_usec) / 1000.0
	stress_window_frame_ms.append(interval_ms)
	stress_window_process_ms.append(process_ms)
	stress_scenario_frame_ms.append(interval_ms)
	stress_scenario_process_ms.append(process_ms)
	stress_frames_total += 1
	if now_usec - stress_last_sample_usec >= 1000000:
		_write_runtime_stress_metrics("SAMPLE", false)
		stress_last_sample_usec = now_usec


func _write_runtime_stress_metrics(record_type: String, whole_scenario: bool) -> void:
	var interval_samples: Array[float] = stress_scenario_frame_ms if whole_scenario else stress_window_frame_ms
	var process_samples: Array[float] = stress_scenario_process_ms if whole_scenario else stress_window_process_ms
	var frame_count: int = interval_samples.size()
	var interval_sum_ms: float = 0.0
	var process_max_ms: float = 0.0
	for sample_ms in interval_samples:
		interval_sum_ms += sample_ms
	for sample_ms in process_samples:
		process_max_ms = maxf(process_max_ms, sample_ms)
	var average_interval_ms: float = interval_sum_ms / float(maxi(1, frame_count))
	var mean_fps: float = 1000.0 / maxf(0.01, average_interval_ms)
	var sorted_intervals: Array[float] = interval_samples.duplicate()
	sorted_intervals.sort()
	var p95_frame_ms: float = 0.0
	var p99_frame_ms: float = 0.0
	var max_frame_ms: float = 0.0
	if not sorted_intervals.is_empty():
		p95_frame_ms = sorted_intervals[clampi(ceili(float(sorted_intervals.size()) * 0.95) - 1, 0, sorted_intervals.size() - 1)]
		p99_frame_ms = sorted_intervals[clampi(ceili(float(sorted_intervals.size()) * 0.99) - 1, 0, sorted_intervals.size() - 1)]
		max_frame_ms = sorted_intervals[sorted_intervals.size() - 1]
	var scenario_name: String = "startup" if stress_scenario_index < 0 or stress_scenario_index >= stress_scenarios.size() else str(stress_scenarios[stress_scenario_index]["name"])
	var scenario_elapsed: float = 0.0
	if stress_scenario_started_usec > 0:
		scenario_elapsed = float(Time.get_ticks_usec() - stress_scenario_started_usec) / 1000000.0
	var counts: Dictionary = _runtime_stress_counts()
	var metric_line: String = "STRESS_%s|scenario=%s|elapsed_s=%.2f|samples=%d|engine_fps=%d|mean_wall_fps=%.2f|avg_frame_ms=%.2f|p95_frame_ms=%.2f|p99_frame_ms=%.2f|max_frame_ms=%.2f|max_process_ms=%.2f|max_action_ms=%.2f|cities=%d|buildings=%d|citizens=%d|cars=%d|resources=%d|rubble=%d|fire_zones=%d|meteors=%d|tornadoes=%d|effects=%d|construction_sites=%d|armies=%d|missiles=%d|transports=%d|oil_rigs=%d|alliances=%d|hostages=%d" % [
		record_type, scenario_name, scenario_elapsed, frame_count, Engine.get_frames_per_second(), mean_fps, average_interval_ms, p95_frame_ms, p99_frame_ms, max_frame_ms, process_max_ms, stress_scenario_max_action_ms,
		int(counts["cities"]), int(counts["buildings"]), int(counts["citizens"]), int(counts["cars"]), int(counts["resources"]), int(counts["rubble"]), int(counts["fires"]), int(counts["meteors"]), int(counts["tornadoes"]), int(counts["effects"]), int(counts["construction_sites"]), int(counts["armies"]), int(counts["missiles"]), int(counts["transports"]), int(counts["oil_rigs"]), int(counts["alliances"]), int(counts["hostages"])
	]
	_stress_emit(metric_line)
	if stress_csv != null:
		stress_csv.store_line("%s,%s,%.3f,%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
			record_type.to_lower(), scenario_name, scenario_elapsed, frame_count, Engine.get_frames_per_second(), mean_fps, average_interval_ms, p95_frame_ms, p99_frame_ms, max_frame_ms, process_max_ms, stress_scenario_max_action_ms,
			int(counts["cities"]), int(counts["buildings"]), int(counts["citizens"]), int(counts["cars"]), int(counts["resources"]), int(counts["rubble"]), int(counts["fires"]), int(counts["meteors"]), int(counts["tornadoes"]), int(counts["effects"]), int(counts["construction_sites"]), int(counts["armies"]), int(counts["missiles"]), int(counts["transports"]), int(counts["oil_rigs"]), int(counts["alliances"]), int(counts["hostages"])
		])
		stress_csv.flush()
	if not whole_scenario:
		stress_window_frame_ms.clear()
		stress_window_process_ms.clear()


func _finish_runtime_stress_scenario() -> void:
	if stress_scenario_index < 0 or stress_scenario_index >= stress_scenarios.size():
		return
	_write_runtime_stress_metrics("SCENARIO_END", true)
	var scenario: Dictionary = stress_scenarios[stress_scenario_index]
	_stress_emit("STRESS_SCENARIO_COMPLETE|%s|speed=%dx|duration_s=%.2f|action_max_ms=%.2f" % [
		str(scenario["name"]), int(scenario.get("speed", 1.0)), float(Time.get_ticks_usec() - stress_scenario_started_usec) / 1000000.0, stress_scenario_max_action_ms
	])
	stress_scenarios_completed += 1


func _finish_runtime_stress_suite() -> void:
	stress_suite_active = false
	sim_speed = 1.0
	var elapsed_seconds: float = float(Time.get_ticks_usec() - stress_suite_started_usec) / 1000000.0
	_stress_emit("STRESS_SUITE_END|status=completed|scenarios_completed=%d|frames=%d|elapsed_s=%.2f|cities=%d|buildings=%d|citizens=%d|cars=%d|resources=%d|rubble=%d|fires=%d|meteors=%d|tornadoes=%d" % [
		stress_scenarios_completed, stress_frames_total, elapsed_seconds, cities.size(), _total_building_count(), people.size(), cars.size(), resources.size(), rubble_nodes.size(), fire_zones.size(), falling_meteors.size(), tornadoes.size()
	])
	if stress_csv != null:
		stress_csv.flush()
		stress_csv.close()
		stress_csv = null
	if performance_log != null:
		performance_log.flush()
	get_tree().quit(0)


func _stress_emit(line: String) -> void:
	print(line)
	if performance_log != null:
		performance_log.store_line(line)
		performance_log.flush()


func _runtime_stress_counts() -> Dictionary:
	var total_hostages: int = 0
	for person in people:
		if str(person.get("activity", "")) == "hostage":
			total_hostages += 1
	return {
		"cities": cities.size(),
		"buildings": _total_building_count(),
		"citizens": people.size(),
		"cars": cars.size(),
		"resources": resources.size(),
		"rubble": rubble_nodes.size(),
		"fires": fire_zones.size(),
		"meteors": falling_meteors.size(),
		"tornadoes": tornadoes.size(),
		"effects": god_effects.size(),
		"construction_sites": construction_sites.size(),
		"armies": armies.size(),
		"missiles": missiles.size(),
		"transports": transports.size(),
		"oil_rigs": oil_rigs.size(),
		"alliances": alliances.size(),
		"hostages": total_hostages
	}


func _run_runtime_stress_action(action_name: String) -> void:
	match action_name:
		"dense_cities":
			_stress_create_extra_cities(MAX_CITIES)
			_stress_spawn_crowd(mini(MAX_PEOPLE, maxi(people.size(), 560)))
			for city_id in range(cities.size()):
				cities[city_id]["treasury"] = 5000.0
				cities[city_id]["wood"] = 45.0
				cities[city_id]["stone"] = 35.0
				cities[city_id]["iron"] = 30.0
				cities[city_id]["copper"] = 25.0
				cities[city_id]["coal"] = 35.0
				_refresh_city_development(city_id)
				_queue_city_roads_rebuild(city_id)
		"construction":
			last_architecture_era = -1
			for city_id in range(cities.size()):
				cities[city_id]["treasury"] = 5000.0
				cities[city_id]["wood"] = 90.0
				cities[city_id]["stone"] = 70.0
				cities[city_id]["iron"] = 50.0
				cities[city_id]["copper"] = 40.0
				cities[city_id]["coal"] = 60.0
				_queue_city_development(city_id)
			_update_historical_era(true)
			for city_id in range(cities.size()):
				_queue_city_development(city_id)
		"spawn_wave":
			_stress_spawn_crowd(mini(MAX_PEOPLE, 760))
		"resources_traffic":
			_stress_spawn_resources(260)
			while cars.size() < MAX_CARS and not cities.is_empty():
				_spawn_car(randi_range(0, cities.size() - 1))
		"camera_lod":
			stress_camera_lod_step = 0
			camera_distance = 28.0
			_update_camera()
			_update_world_detail_levels()
		"camera_lod_pulse":
			var lod_distances: Array[float] = [26.0, 58.0, 104.0, 178.0]
			camera_distance = lod_distances[stress_camera_lod_step % lod_distances.size()]
			stress_camera_lod_step += 1
			_update_camera()
			_update_world_detail_levels()
		"debris":
			for debris_index in range(65):
				_stress_spawn_rubble_piece()
		"fire_plague":
			if cities.is_empty():
				return
			for fire_index in range(7):
				_god_fire(_stress_city_target(fire_index))
			_god_plague(cities[0]["pos"])
			for tornado_index in range(3):
				_god_tornado(_stress_city_target(tornado_index + 2))
		"meteor_storm":
			if cities.is_empty():
				return
			brush_radius = 7.0
			for meteor_index in range(6):
				_god_meteor(_stress_city_target(meteor_index))
			for tornado_index in range(4):
				_god_tornado(_stress_city_target(tornado_index + 1))
			for lightning_index in range(3):
				_god_lightning(_stress_city_target(lightning_index + 2))
		"terrain_edits":
			if cities.is_empty():
				return
			brush_radius = 7.0
			# Include the real god-power path, not just raw height-map edits: the
			# regression should catch collapse/road/damage cost as well as terrain work.
			_god_earthquake(_stress_city_target(0))
			for terrain_edit_index in range(1, 3):
				var target: Vector3 = _stress_city_target(terrain_edit_index)
				_sculpt_terrain(target, -0.24 if terrain_edit_index % 2 == 0 else 0.28)
		"terrain_edit_pulse":
			if cities.is_empty():
				return
			brush_radius = 7.0
			# Repeat small local edits while the scenario runs so the stress log
			# captures the delayed mesh/object-alignment cost, not just dispatch cost.
			var edit_target: Vector3 = _stress_city_target(stress_camera_lod_step % mini(3, cities.size()))
			stress_camera_lod_step += 1
			_sculpt_terrain(edit_target, -0.18, false)
			_sculpt_terrain(edit_target + Vector3(5.0, 0.0, 4.0), 0.16, false)
		"transport_network":
			_stress_create_extra_cities(mini(12, MAX_CITIES))
			_stress_spawn_crowd(mini(MAX_PEOPLE, maxi(people.size(), 900)))
			for city_id in range(cities.size()):
				var city: Dictionary = cities[city_id]
				city["treasury"] = maxf(1200.0, float(city.get("treasury", 0.0)))
				city["wood"] = maxf(45.0, float(city.get("wood", 0.0)))
				city["stone"] = maxf(35.0, float(city.get("stone", 0.0)))
				city["iron"] = maxf(30.0, float(city.get("iron", 0.0)))
				city["copper"] = maxf(25.0, float(city.get("copper", 0.0)))
				cities[city_id] = city
				while _city_population(city_id) < 24 and people.size() < MAX_PEOPLE:
					var home: Vector3 = cities[city_id]["pos"]
					_spawn_human(_surface_position(home.x + randf_range(-12.0, 12.0), home.z + randf_range(-12.0, 12.0)), city_id)
			last_architecture_era = -1
			_update_historical_era(true)
			if oil_rigs.is_empty():
				_seed_oil_rigs()
			for departure in range(10):
				_spawn_transport_wave()
			camera_target = Vector3.ZERO
			camera_distance = 330.0
			_update_camera()
		"oil_wars":
			if cities.size() < 2:
				return
			if oil_rigs.is_empty():
				_seed_oil_rigs()
			if not oil_rigs.is_empty():
				var stress_rig_index: int = randi_range(0, oil_rigs.size() - 1)
				oil_rigs[stress_rig_index]["owner_city"] = 0
			_declare_war(0, 1)
			_launch_army(0, 1, true)
			_launch_army(1, 0, true)
			_spawn_defenders(1, 0)
			_update_oil_rigs()
		"battle_hostages":
			if cities.size() < 2:
				return
			_declare_war(0, 1)
			_launch_army(0, 1, true)
			_launch_army(1, 0, true)
			_spawn_defenders(0, 1)
			_spawn_defenders(1, 0)
			_capture_city_hostages(1, 0, 3)
			for city_id in [0, 1]:
				var target_position: Vector3 = cities[city_id]["pos"]
				_damage_roads_at_position(target_position, 7.0, false)
				_queue_city_roads_rebuild(city_id)
			camera_target = cities[1]["pos"]
			camera_distance = 96.0
			_update_camera()
		"collapse":
			var collapse_count: int = 0
			for city_id in range(cities.size()):
				var houses: Array = cities[city_id]["houses"]
				for house in houses:
					if collapse_count >= 22:
						break
					if is_instance_valid(house) and not bool(house.get_meta("is_collapsing", false)):
						if _collapse_specific_building(city_id, house, true, false, 0, 0.45):
							collapse_count += 1
				if collapse_count >= 22:
					break
		"save_load":
			_save_world()
			_load_world()
		"combined":
			_stress_spawn_crowd(mini(MAX_PEOPLE, people.size() + 30))
			_stress_spawn_resources(75)
			while cars.size() < MAX_CARS and not cities.is_empty():
				_spawn_car(randi_range(0, cities.size() - 1))
			for debris_index in range(15):
				_stress_spawn_rubble_piece()
			if not cities.is_empty():
				_god_plague(cities[0]["pos"])
				_god_fire(_stress_city_target(0))
				_god_fire(_stress_city_target(2))
				_god_tornado(_stress_city_target(1))
				for city_id in range(cities.size()):
					_refresh_city_development(city_id)
		"combined_pulse":
			_stress_spawn_crowd(mini(MAX_PEOPLE, people.size() + 3))
			_stress_spawn_resources(8)
			for debris_index in range(3):
				_stress_spawn_rubble_piece()
			if not cities.is_empty():
				_god_fire(_stress_city_target(randi_range(0, cities.size() - 1)))
				if tornadoes.size() < 5:
					_god_tornado(_stress_city_target(randi_range(0, cities.size() - 1)))
				for city_id in range(cities.size()):
					_queue_city_development(city_id)
		_:
			return


func _stress_create_extra_cities(target_city_count: int) -> void:
	while cities.size() < target_city_count:
		var site_found: bool = false
		var candidate_position: Vector3 = Vector3.ZERO
		for attempt in range(120):
			var x: float = randf_range(-TERRAIN_SIZE * 0.40, TERRAIN_SIZE * 0.40)
			var z: float = randf_range(-TERRAIN_SIZE * 0.40, TERRAIN_SIZE * 0.40)
			var surface: Vector3 = _surface_position(x, z)
			if surface.y <= WATER_LEVEL + 0.55:
				continue
			var has_room: bool = true
			for existing_city in cities:
				var existing_position: Vector3 = existing_city["pos"]
				if Vector2(existing_position.x - surface.x, existing_position.z - surface.z).length() < 30.0:
					has_room = false
					break
			if has_room:
				candidate_position = surface
				site_found = true
				break
		if not site_found:
			_stress_emit("STRESS_WARNING|could_not_place_additional_city|cities=%d|target=%d" % [cities.size(), target_city_count])
			break
		var city_name: String = "Stress City %d" % (cities.size() + 1)
		var color: Color = city_colors[cities.size() % city_colors.size()]
		var new_city_id: int = _create_city(candidate_position, city_name, color)
		cities[new_city_id]["treasury"] = 5000.0
		cities[new_city_id]["wood"] = 45.0
		cities[new_city_id]["stone"] = 35.0
		cities[new_city_id]["iron"] = 30.0
		cities[new_city_id]["copper"] = 25.0
		cities[new_city_id]["coal"] = 35.0


func _stress_spawn_crowd(target_people: int) -> void:
	var population_by_city: Array[int] = []
	population_by_city.resize(cities.size())
	population_by_city.fill(0)
	for person in people:
		var city_id: int = int(person.get("city_id", -1))
		if city_id >= 0 and city_id < population_by_city.size():
			population_by_city[city_id] += 1
	var spawn_sequence: int = 0
	while people.size() < mini(target_people, MAX_PEOPLE) and people.size() < MAX_PEOPLE and not cities.is_empty():
		var selected_city_id: int = 0
		for city_id in range(1, cities.size()):
			if population_by_city[city_id] < population_by_city[selected_city_id]:
				selected_city_id = city_id
		var city_position: Vector3 = cities[selected_city_id]["pos"]
		var angle: float = float(spawn_sequence) * 2.39996
		var radius: float = 4.0 + float(spawn_sequence % 17) * 0.70
		var x: float = clampf(city_position.x + cos(angle) * radius, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
		var z: float = clampf(city_position.z + sin(angle) * radius, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
		var spawn_position: Vector3 = _surface_position(x, z)
		if spawn_position.y <= WATER_LEVEL + 0.1:
			spawn_position = _surface_position(city_position.x, city_position.z)
		_spawn_human(spawn_position, selected_city_id)
		population_by_city[selected_city_id] += 1
		spawn_sequence += 1


func _stress_spawn_resources(amount: int) -> void:
	var kinds: Array[String] = ["tree", "stone", "food", "iron_ore", "copper_ore", "coal", "gold_ore"]
	if cities.is_empty():
		return
	for resource_index in range(amount):
		var city_id: int = resource_index % cities.size()
		var city_position: Vector3 = cities[city_id]["pos"]
		var angle: float = float(resource_index) * 2.39996 + float(city_id) * 0.41
		var radius: float = 12.0 + float(resource_index % 41) * 0.75
		var x: float = clampf(city_position.x + cos(angle) * radius, -TERRAIN_SIZE * 0.48, TERRAIN_SIZE * 0.48)
		var z: float = clampf(city_position.z + sin(angle) * radius, -TERRAIN_SIZE * 0.48, TERRAIN_SIZE * 0.48)
		var candidate: Vector3 = _surface_position(x, z)
		if candidate.y <= WATER_LEVEL + 0.1:
			candidate = _surface_position(city_position.x, city_position.z)
		_spawn_resource(candidate, kinds[resource_index % kinds.size()], randi_range(4, 12))


func _stress_spawn_rubble_piece() -> void:
	if cities.is_empty():
		return
	var city_id: int = randi_range(0, cities.size() - 1)
	var city_position: Vector3 = cities[city_id]["pos"]
	var angle: float = randf() * TAU
	var radius: float = randf_range(0.0, 25.0)
	var debris_position: Vector3 = _surface_position(city_position.x + cos(angle) * radius, city_position.z + sin(angle) * radius)
	var tall: bool = randf() < 0.25
	_spawn_persistent_rubble(debris_position, tall, cities[city_id]["color"], true, "building")


func _stress_city_target(offset: int = 0) -> Vector3:
	if cities.is_empty():
		return Vector3.ZERO
	var city_id: int = posmod(offset, cities.size())
	var city_position: Vector3 = cities[city_id]["pos"]
	var angle: float = float(offset + stress_scenario_index + 1) * 1.618
	var radius: float = 3.0 + float((offset * 3) % 6) * 1.2
	return _surface_position(city_position.x + cos(angle) * radius, city_position.z + sin(angle) * radius)

func _total_building_count() -> int:
	var total: int = 0
	for city in cities:
		total += (city.get("houses", []) as Array).size()
	return total


func _recover_stuck_citizens() -> void:
	if paused:
		return
	for person_index in range(people.size()):
		var person: Dictionary = people[person_index]
		if not bool(person.get("alive", true)):
			continue
		var activity: String = str(person.get("activity", "wandering"))
		if activity in ["indoors", "riding", "cleaning", "constructing"]:
			continue
		var position: Vector3 = person["pos"]
		var target: Vector3 = person.get("target", position)
		var distance_to_target: float = Vector2(position.x - target.x, position.z - target.z).length()
		var last_watch_position: Vector3 = person.get("stuck_watch_position", position)
		var moved_distance: float = Vector2(position.x - last_watch_position.x, position.z - last_watch_position.z).length()
		var stuck_timer: float = float(person.get("stuck_timer", 0.0))
		if distance_to_target > 1.1 and moved_distance < 0.25:
			stuck_timer += 1.0
		else:
			stuck_timer = 0.0
		person["stuck_watch_position"] = position
		person["stuck_timer"] = stuck_timer
		if stuck_timer >= 6.0:
			var cleanup_id: int = int(person.get("cleanup_rubble_id", -1))
			if cleanup_id >= 0:
				_reserve_cleanup_rubble(cleanup_id, false)
			person["activity"] = "wandering"
			person["activity_timer"] = 0.0
			person["indoor_house"] = null
			person["vehicle_node"] = null
			person["cleanup_rubble_id"] = -1
			person["target"] = _choose_citizen_street_target(int(person.get("city_id", -1)), position, 10.0)
			person["walk_timer"] = 0.0
			person["stuck_timer"] = 0.0
			var node: Node3D = person.get("node") as Node3D
			if is_instance_valid(node):
				node.position = position
				node.visible = true
		people[person_index] = person


func _update_rubble_aging(delta: float) -> void:
	# Citizen crews normally clear debris first. This is a long-stop maintenance
	# cleanup so wrecks do not remain forever if the area has no residents.
	rubble_aging_timer += delta
	if rubble_aging_timer < 2.0:
		return
	var age_step: float = rubble_aging_timer
	rubble_aging_timer = 0.0
	var expired_ids: Array[int] = []
	for i in range(rubble_nodes.size()):
		var entry: Dictionary = rubble_nodes[i]
		entry["age"] = float(entry.get("age", 0.0)) + age_step
		if float(entry["age"]) >= 90.0:
			expired_ids.append(int(entry["id"]))
		rubble_nodes[i] = entry
	for rubble_id in expired_ids:
		_clear_rubble_by_id(rubble_id)


func _process(delta: float) -> void:
	var frame_started_usec: int = Time.get_ticks_usec()
	performance_frame_count += 1
	in_simulation_frame = not paused
	building_visual_mutation_consumed_this_frame = false
	building_start_budget_remaining = MAX_BUILDING_STARTS_PER_FRAME if Time.get_ticks_usec() >= next_building_visual_mutation_usec else 0
	detail_refresh_cooldown = maxf(0.0, detail_refresh_cooldown - delta)
	terrain_rebuild_cooldown = maxf(0.0, terrain_rebuild_cooldown - delta)
	var occlusion_was_cooling: bool = building_occlusion_refresh_cooldown > 0.0
	building_occlusion_refresh_cooldown = maxf(0.0, building_occlusion_refresh_cooldown - delta)
	if occlusion_was_cooling and building_occlusion_refresh_cooldown <= 0.0:
		# Force the next detail tick to recompute cached occlusion, even if the
		# camera and entity-count signature has otherwise stopped changing.
		last_detail_signature = ""
	people_lod_refresh_cooldown = maxf(0.0, people_lod_refresh_cooldown - delta)
	_process_one_pending_city_road_rebuild()
	_update_traffic_lights(delta)
	if not paused:
		stuck_recovery_timer += delta
		if stuck_recovery_timer >= 1.0:
			stuck_recovery_timer = fmod(stuck_recovery_timer, 1.0)
			_recover_stuck_citizens()
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
		construction_simulation_clock += sim_delta

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
		var people_started_usec: int = Time.get_ticks_usec()
		if people_update_interval <= 0.0:
			people_update_accumulator = 0.0
			_update_people(sim_delta)
		else:
			people_update_accumulator += sim_delta
			if people_update_accumulator >= people_update_interval:
				var people_delta: float = people_update_accumulator
				people_update_accumulator = fmod(people_update_accumulator, people_update_interval)
				_update_people(people_delta)
		_trace_slow_operation("citizen-update", people_started_usec)

		if not cars.is_empty():
			var car_update_interval: float = 0.09 if camera_distance <= 85.0 else (0.18 if camera_distance <= 165.0 else 0.42)
			car_update_accumulator += sim_delta
			if car_update_accumulator >= car_update_interval:
				var cars_delta: float = car_update_accumulator
				car_update_accumulator = fmod(car_update_accumulator, car_update_interval)
				_update_cars(cars_delta)

		_update_armies(sim_delta)
		_update_transports(sim_delta)
		_update_hostages(sim_delta)
		_update_missiles(sim_delta)
		_update_explosions(sim_delta)
		_update_god_effects(sim_delta)
		_update_fire_zones(sim_delta)
		_update_falling_meteors(sim_delta)
		_update_tornadoes(sim_delta)
		_update_plague(sim_delta)
		var simulation_timers_started_usec: int = Time.get_ticks_usec()
		_update_simulation_timers(sim_delta)
		_trace_slow_operation("economy-growth-trade-events-total", simulation_timers_started_usec)
		var queued_development_started_usec: int = Time.get_ticks_usec()
		_process_one_pending_city_development()
		_trace_slow_operation("queued-city-development", queued_development_started_usec)
		_update_rubble_aging(sim_delta)
		var construction_started_usec: int = Time.get_ticks_usec()
		_update_construction_sites(sim_delta)
		_trace_slow_operation("construction-site-update", construction_started_usec)
		_update_city_event_markers(sim_delta)
		_update_city_event_scenes(sim_delta)
		var era_started_usec: int = Time.get_ticks_usec()
		_update_historical_era()
		_trace_slow_operation("era-refurbishment", era_started_usec)
	if not pending_terrain_edits.is_empty() and terrain_rebuild_cooldown <= 0.0:
		_flush_pending_terrain_edits()
	_process_pending_terrain_chunk_updates()
	ui_timer += delta
	if ui_timer >= 0.35:
		ui_timer = 0.0
		var detail_started_usec: int = Time.get_ticks_usec()
		_update_world_detail_levels()
		_trace_slow_operation("world-detail-and-occlusion", detail_started_usec)
		var ui_started_usec: int = Time.get_ticks_usec()
		_refresh_ui()
		_trace_slow_operation("ui-refresh", ui_started_usec)
	if stress_suite_active:
		_tick_runtime_stress_tests()
		_tick_runtime_stress_screenshot()
	var frame_elapsed_usec: int = Time.get_ticks_usec() - frame_started_usec
	if frame_elapsed_usec >= FRAME_HITCH_THRESHOLD_USEC:
		_write_performance_sample("FRAME-HITCH", frame_elapsed_usec)
	if stress_suite_active:
		_record_runtime_stress_frame(delta, frame_elapsed_usec)
	# Start this cooldown only after synchronous construction/mesh work has
	# finished. A slow build must not overrun a cooldown stamped at its start.
	if building_visual_mutation_consumed_this_frame:
		next_building_visual_mutation_usec = Time.get_ticks_usec() + BUILDING_VISUAL_MUTATION_INTERVAL_USEC
	in_simulation_frame = false


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
	terrain_moisture_grid.clear()
	terrain_temperature_grid.clear()
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
		Vector2(-129.0, -81.0), Vector2(168.0, -84.0), Vector2(9.0, 159.0),
		Vector2(-255.0, 96.0), Vector2(255.0, 183.0), Vector2(-246.0, -219.0)
	]
	var continent_radii: Array[Vector2] = [
		Vector2(166.5, 139.5), Vector2(126.0, 171.0), Vector2(198.0, 144.0),
		Vector2(72.0, 94.5), Vector2(63.0, 76.5), Vector2(67.5, 58.5)
	]
	for z_index in range(TERRAIN_RES):
		var row: Array = []
		var moisture_row: Array[float] = []
		var temperature_row: Array[float] = []
		for x_index in range(TERRAIN_RES):
			var x: float = (float(x_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
			var z: float = (float(z_index) / float(TERRAIN_RES - 1) - 0.5) * TERRAIN_SIZE
			moisture_row.append((terrain_moisture_noise.get_noise_2d(x, z) + 1.0) * 0.5)
			temperature_row.append(terrain_temperature_noise.get_noise_2d(x, z))
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
		terrain_moisture_grid.append(moisture_row)
		terrain_temperature_grid.append(temperature_row)


func _ensure_terrain_lod_chunks() -> void:
	if terrain_lod_chunk_nodes.size() == TERRAIN_LOD_STEPS.size():
		return
	terrain_lod_nodes.clear()
	terrain_lod_chunk_nodes.clear()
	for lod_index in range(TERRAIN_LOD_STEPS.size()):
		var chunk_nodes: Array[MeshInstance3D] = []
		for chunk_z in range(TERRAIN_CHUNKS_PER_AXIS):
			for chunk_x in range(TERRAIN_CHUNKS_PER_AXIS):
				var chunk_node: MeshInstance3D
				if lod_index == 0 and chunk_x == 0 and chunk_z == 0 and is_instance_valid(terrain):
					chunk_node = terrain
				else:
					chunk_node = MeshInstance3D.new()
					chunk_node.name = "TerrainLOD_%d_Chunk_%d_%d" % [lod_index, chunk_x, chunk_z]
					add_child(chunk_node)
				chunk_node.material_override = terrain_material
				chunk_nodes.append(chunk_node)
		terrain_lod_chunk_nodes.append(chunk_nodes)
		terrain_lod_nodes.append(chunk_nodes[0])


func _set_active_terrain_lod_visibility(active_lod: int) -> void:
	for lod_index in range(terrain_lod_chunk_nodes.size()):
		var chunk_nodes: Array = terrain_lod_chunk_nodes[lod_index]
		var lod_visible: bool = lod_index == active_lod
		for chunk_variant in chunk_nodes:
			var chunk_node: MeshInstance3D = chunk_variant as MeshInstance3D
			if is_instance_valid(chunk_node):
				chunk_node.visible = lod_visible


func _rebuild_terrain() -> void:
	# Full rebuild is reserved for initial generation/load and other operations that
	# replace the whole heightmap. Normal edits rebuild only touched terrain chunks.
	_ensure_terrain_lod_chunks()
	for lod_index in range(TERRAIN_LOD_STEPS.size()):
		terrain_lod_dirty[lod_index] = true
	var active_lod: int = _terrain_lod_index_for_distance(camera_distance)
	_build_terrain_lod(active_lod)
	_set_active_terrain_lod_visibility(active_lod)


func _build_terrain_lod(lod_index: int) -> void:
	if lod_index < 0 or lod_index >= terrain_lod_chunk_nodes.size():
		return
	for chunk_z in range(TERRAIN_CHUNKS_PER_AXIS):
		for chunk_x in range(TERRAIN_CHUNKS_PER_AXIS):
			_build_terrain_chunk(lod_index, chunk_x, chunk_z)
	terrain_lod_dirty[lod_index] = false
	# A full active-LOD build includes every edit already applied to the heightmap,
	# so any incremental chunk work queued for that same visible LOD is redundant.
	if lod_index == _terrain_lod_index_for_distance(camera_distance):
		pending_terrain_chunk_updates.clear()


func _build_terrain_chunk(lod_index: int, chunk_x: int, chunk_z: int) -> void:
	if lod_index < 0 or lod_index >= terrain_lod_chunk_nodes.size():
		return
	if chunk_x < 0 or chunk_x >= TERRAIN_CHUNKS_PER_AXIS or chunk_z < 0 or chunk_z >= TERRAIN_CHUNKS_PER_AXIS:
		return
	var stride: int = TERRAIN_LOD_STEPS[lod_index]
	var spacing: float = TERRAIN_SIZE / float(TERRAIN_RES - 1)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start_x: int = chunk_x * TERRAIN_CHUNK_CELLS
	var start_z: int = chunk_z * TERRAIN_CHUNK_CELLS
	var end_x: int = mini(start_x + TERRAIN_CHUNK_CELLS, TERRAIN_RES - 1)
	var end_z: int = mini(start_z + TERRAIN_CHUNK_CELLS, TERRAIN_RES - 1)
	var vertex_columns: int = int((end_x - start_x) / stride) + 1
	var vertex_rows: int = int((end_z - start_z) / stride) + 1

	# Submit each heightmap sample only once. The old builder emitted six duplicate
	# vertices per cell, then called SurfaceTool.index() to deduplicate them again.
	# Explicit indices cut vertex/color work by roughly 5-6x per terrain chunk.
	for z_index in range(start_z, end_z + 1, stride):
		var z: float = -TERRAIN_SIZE * 0.5 + float(z_index) * spacing
		for x_index in range(start_x, end_x + 1, stride):
			var x: float = -TERRAIN_SIZE * 0.5 + float(x_index) * spacing
			_add_terrain_vertex(surface, Vector3(x, terrain_heights[z_index][x_index], z))

	for z_step in range(vertex_rows - 1):
		for x_step in range(vertex_columns - 1):
			var top_left: int = z_step * vertex_columns + x_step
			var top_right: int = top_left + 1
			var bottom_left: int = top_left + vertex_columns
			var bottom_right: int = bottom_left + 1
			# Preserve the tested top-facing winding order used by the previous mesh.
			surface.add_index(top_left)
			surface.add_index(top_right)
			surface.add_index(bottom_left)
			surface.add_index(top_right)
			surface.add_index(bottom_right)
			surface.add_index(bottom_left)
	surface.generate_normals(true)
	var chunk_index: int = chunk_z * TERRAIN_CHUNKS_PER_AXIS + chunk_x
	var chunk_nodes: Array = terrain_lod_chunk_nodes[lod_index]
	var chunk_node: MeshInstance3D = chunk_nodes[chunk_index] as MeshInstance3D
	chunk_node.mesh = surface.commit()
	chunk_node.material_override = terrain_material


func _rebuild_terrain_around_many(edits: Array[Dictionary]) -> void:
	if edits.is_empty():
		return
	_ensure_terrain_lod_chunks()
	for lod_index in range(TERRAIN_LOD_STEPS.size()):
		terrain_lod_dirty[lod_index] = true
	var active_lod: int = _terrain_lod_index_for_distance(camera_distance)
	var spacing: float = TERRAIN_SIZE / float(TERRAIN_RES - 1)
	for edit in edits:
		var center: Vector3 = edit.get("center", Vector3.ZERO)
		var radius: float = maxf(0.1, float(edit.get("radius", brush_radius)))
		var min_x: int = clampi(floori((center.x - radius + TERRAIN_SIZE * 0.5) / spacing), 0, TERRAIN_RES - 1)
		var max_x: int = clampi(ceili((center.x + radius + TERRAIN_SIZE * 0.5) / spacing), 0, TERRAIN_RES - 1)
		var min_z: int = clampi(floori((center.z - radius + TERRAIN_SIZE * 0.5) / spacing), 0, TERRAIN_RES - 1)
		var max_z: int = clampi(ceili((center.z + radius + TERRAIN_SIZE * 0.5) / spacing), 0, TERRAIN_RES - 1)
		var min_chunk_x: int = clampi(floori(float(min_x) / float(TERRAIN_CHUNK_CELLS)), 0, TERRAIN_CHUNKS_PER_AXIS - 1)
		var max_chunk_x: int = clampi(floori(float(max_x) / float(TERRAIN_CHUNK_CELLS)), 0, TERRAIN_CHUNKS_PER_AXIS - 1)
		var min_chunk_z: int = clampi(floori(float(min_z) / float(TERRAIN_CHUNK_CELLS)), 0, TERRAIN_CHUNKS_PER_AXIS - 1)
		var max_chunk_z: int = clampi(floori(float(max_z) / float(TERRAIN_CHUNK_CELLS)), 0, TERRAIN_CHUNKS_PER_AXIS - 1)
		for chunk_z in range(min_chunk_z, max_chunk_z + 1):
			for chunk_x in range(min_chunk_x, max_chunk_x + 1):
				var chunk_index: int = chunk_z * TERRAIN_CHUNKS_PER_AXIS + chunk_x
				pending_terrain_chunk_updates[chunk_index] = true

	# The heightmap has already been edited. Rebuild only a small number of affected
	# meshes per frame instead of committing several chunks on the brush/disaster
	# frame. A full LOD rebuild remains the fallback when the camera changes LOD.
	terrain_lod_dirty[active_lod] = false
	_set_active_terrain_lod_visibility(active_lod)


func _process_pending_terrain_chunk_updates() -> void:
	if pending_terrain_chunk_updates.is_empty():
		return
	var active_lod: int = _terrain_lod_index_for_distance(camera_distance)
	if active_lod < 0 or active_lod >= terrain_lod_dirty.size() or terrain_lod_dirty[active_lod]:
		# A pending LOD transition will rebuild the complete visible mesh once.
		return
	var started_usec: int = Time.get_ticks_usec()
	var chunk_keys: Array = pending_terrain_chunk_updates.keys()
	chunk_keys.sort()
	var rebuilt_count: int = 0
	for chunk_key in chunk_keys:
		if rebuilt_count >= MAX_TERRAIN_CHUNKS_PER_FRAME:
			break
		var chunk_index: int = int(chunk_key)
		var chunk_x: int = posmod(chunk_index, TERRAIN_CHUNKS_PER_AXIS)
		var chunk_z: int = floori(float(chunk_index) / float(TERRAIN_CHUNKS_PER_AXIS))
		_build_terrain_chunk(active_lod, chunk_x, chunk_z)
		pending_terrain_chunk_updates.erase(chunk_index)
		rebuilt_count += 1
	terrain_lod_dirty[active_lod] = false
	_trace_slow_operation("terrain-mesh-chunk-budget", started_usec)


func _queue_terrain_edit_update(center: Vector3, radius: float) -> void:
	pending_terrain_edits.append({"center": center, "radius": maxf(0.1, radius)})


func _flush_pending_terrain_edits() -> void:
	if pending_terrain_edits.is_empty():
		return
	var edits: Array[Dictionary] = pending_terrain_edits.duplicate()
	pending_terrain_edits.clear()
	var rebuild_started_usec: int = Time.get_ticks_usec()
	_rebuild_terrain_around_many(edits)
	var alignment_started_usec: int = Time.get_ticks_usec()
	var refresh_territory: bool = pending_terrain_shoreline_change
	pending_terrain_shoreline_change = false
	_update_placed_object_heights_near_many(edits, refresh_territory)
	_trace_slow_operation("terrain-object-alignment-only", alignment_started_usec)
	terrain_rebuild_cooldown = TERRAIN_EDIT_REBUILD_INTERVAL
	_trace_slow_operation("terrain-chunk-rebuild-and-object-alignment", rebuild_started_usec)


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
	var grid_x: int = clampi(roundi((point.x / TERRAIN_SIZE + 0.5) * float(TERRAIN_RES - 1)), 0, TERRAIN_RES - 1)
	var grid_z: int = clampi(roundi((point.z / TERRAIN_SIZE + 0.5) * float(TERRAIN_RES - 1)), 0, TERRAIN_RES - 1)
	if terrain_moisture_grid.size() == TERRAIN_RES and terrain_temperature_grid.size() == TERRAIN_RES:
		moisture = float((terrain_moisture_grid[grid_z] as Array)[grid_x])
		climate = float((terrain_temperature_grid[grid_z] as Array)[grid_x])
	else:
		# Safe fallback for any legacy startup path before the heightmap caches exist.
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


func _terrain_render_height_at(x: float, z: float) -> float:
	# Match the actual triangle interpolation used by the currently visible
	# terrain LOD, not the bilinear approximation. This keeps asphalt above
	# the visible ground even when terrain is viewed at a coarse zoom level.
	var resolution: int = terrain_heights.size()
	if resolution < 2:
		return _height_at(x, z)
	var grid_x: float = clampf((x / TERRAIN_SIZE + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var grid_z: float = clampf((z / TERRAIN_SIZE + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var lod_index: int = clampi(_terrain_lod_index_for_distance(camera_distance), 0, TERRAIN_LOD_STEPS.size() - 1)
	var stride: int = TERRAIN_LOD_STEPS[lod_index]
	var x0: int = mini((int(floor(grid_x / float(stride))) * stride), resolution - 1)
	var z0: int = mini((int(floor(grid_z / float(stride))) * stride), resolution - 1)
	var x1: int = mini(x0 + stride, resolution - 1)
	var z1: int = mini(z0 + stride, resolution - 1)
	if x1 == x0 or z1 == z0:
		return float(terrain_heights[z0][x0])
	var tx: float = (grid_x - float(x0)) / float(x1 - x0)
	var tz: float = (grid_z - float(z0)) / float(z1 - z0)
	var h00: float = float(terrain_heights[z0][x0])
	var h10: float = float(terrain_heights[z0][x1])
	var h01: float = float(terrain_heights[z1][x0])
	var h11: float = float(terrain_heights[z1][x1])
	if tx + tz <= 1.0:
		return h00 + tx * (h10 - h00) + tz * (h01 - h00)
	return (1.0 - tz) * h10 + (tx + tz - 1.0) * h11 + (1.0 - tx) * h01


func _max_terrain_height_in_radius(center_x: float, center_z: float, radius: float) -> float:
	var resolution: int = terrain_heights.size()
	var grid_step: float = TERRAIN_SIZE / float(resolution - 1)
	var center_ix: int = clampi(roundi((center_x / TERRAIN_SIZE + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var center_iz: int = clampi(roundi((center_z / TERRAIN_SIZE + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var cell_radius: int = ceili(radius / grid_step)
	var maximum: float = -INF
	for zi in range(maxi(0, center_iz - cell_radius), mini(resolution, center_iz + cell_radius + 1)):
		for xi in range(maxi(0, center_ix - cell_radius), mini(resolution, center_ix + cell_radius + 1)):
			var wx: float = (float(xi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			var wz: float = (float(zi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			if Vector2(wx - center_x, wz - center_z).length() <= radius:
				maximum = maxf(maximum, float(terrain_heights[zi][xi]))
	return _height_at(center_x, center_z) if is_inf(maximum) else maximum


func _sample_building_plot_grade(center_x: float, center_z: float, radius: float) -> Dictionary:
	var resolution: int = terrain_heights.size()
	if resolution < 2:
		return {"changed": false, "steep": false, "base_height": _height_at(center_x, center_z)}
	var grid_step: float = TERRAIN_SIZE / float(resolution - 1)
	var center_ix: int = clampi(roundi((center_x / TERRAIN_SIZE + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var center_iz: int = clampi(roundi((center_z / TERRAIN_SIZE + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var cell_radius: int = ceili((radius + 0.25) / grid_step)
	var minimum: float = INF
	var maximum: float = -INF
	var samples: int = 0
	for zi in range(maxi(0, center_iz - cell_radius), mini(resolution, center_iz + cell_radius + 1)):
		for xi in range(maxi(0, center_ix - cell_radius), mini(resolution, center_ix + cell_radius + 1)):
			var wx: float = (float(xi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			var wz: float = (float(zi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			if Vector2(wx - center_x, wz - center_z).length() > radius:
				continue
			var height: float = float(terrain_heights[zi][xi])
			minimum = minf(minimum, height)
			maximum = maxf(maximum, height)
			samples += 1
	var base_height: float = _height_at(center_x, center_z)
	if samples == 0:
		return {"changed": false, "steep": false, "base_height": base_height}
	if maximum - minimum > 1.55:
		return {"changed": false, "steep": true, "base_height": _max_terrain_height_in_radius(center_x, center_z, radius) + 0.18}
	return {"changed": false, "steep": false, "base_height": base_height}


func _grade_building_plot(center_x: float, center_z: float, radius: float) -> Dictionary:
	# Low-slope plots receive a gently feathered pad. On steep ground preserve
	# the hillside and lift the structure onto a terrace with visible supports.
	var resolution: int = terrain_heights.size()
	var grid_step: float = TERRAIN_SIZE / float(resolution - 1)
	var center_ix: int = clampi(roundi((center_x / TERRAIN_SIZE + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var center_iz: int = clampi(roundi((center_z / TERRAIN_SIZE + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var cell_radius: int = ceili((radius + 0.25) / grid_step)
	var minimum: float = INF
	var maximum: float = -INF
	var total: float = 0.0
	var samples: int = 0
	for zi in range(maxi(0, center_iz - cell_radius), mini(resolution, center_iz + cell_radius + 1)):
		for xi in range(maxi(0, center_ix - cell_radius), mini(resolution, center_ix + cell_radius + 1)):
			var wx: float = (float(xi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			var wz: float = (float(zi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			if Vector2(wx - center_x, wz - center_z).length() > radius:
				continue
			var height: float = float(terrain_heights[zi][xi])
			minimum = minf(minimum, height)
			maximum = maxf(maximum, height)
			total += height
			samples += 1
	var base_height: float = _height_at(center_x, center_z)
	if samples == 0:
		return {"changed": false, "steep": false, "base_height": base_height}
	var local_range: float = maximum - minimum
	if local_range > 1.55:
		return {"changed": false, "steep": true, "base_height": _max_terrain_height_in_radius(center_x, center_z, radius) + 0.18}
	var target_height: float = total / float(samples)
	var feather_radius: float = radius + 1.25
	var changed: bool = false
	for zi in range(maxi(0, center_iz - cell_radius - 2), mini(resolution, center_iz + cell_radius + 3)):
		for xi in range(maxi(0, center_ix - cell_radius - 2), mini(resolution, center_ix + cell_radius + 3)):
			var wx: float = (float(xi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			var wz: float = (float(zi) / float(resolution - 1) - 0.5) * TERRAIN_SIZE
			var distance: float = Vector2(wx - center_x, wz - center_z).length()
			if distance >= feather_radius:
				continue
			var weight: float = 1.0
			if distance > radius * 0.62:
				var blend_t: float = clampf((feather_radius - distance) / maxf(0.01, feather_radius - radius * 0.62), 0.0, 1.0)
				weight = blend_t * blend_t * (3.0 - 2.0 * blend_t)
			weight *= 0.92
			var old_height: float = float(terrain_heights[zi][xi])
			var new_height: float = lerpf(old_height, target_height, weight)
			if absf(new_height - old_height) > 0.015:
				terrain_heights[zi][xi] = new_height
				changed = true
	base_height = _height_at(center_x, center_z)
	return {"changed": changed, "steep": false, "base_height": base_height}


func _add_terraced_building_foundation(house: Node3D, width: float, depth: float) -> void:
	if not is_instance_valid(house):
		return
	var support_mesh := BoxMesh.new()
	var support_material: Material = _material(Color(0.43, 0.42, 0.39))
	var corner_x: float = width * 0.44
	var corner_z: float = depth * 0.44
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			var x_offset: float = float(sign_x) * corner_x
			var z_offset: float = float(sign_z) * corner_z
			var ground_y: float = _terrain_render_height_at(house.global_position.x + x_offset, house.global_position.z + z_offset) - house.global_position.y
			if ground_y >= -0.28:
				continue
			var post_height: float = -ground_y + 0.12
			support_mesh = BoxMesh.new()
			support_mesh.size = Vector3(0.42, post_height, 0.42)
			_add_mesh(house, support_mesh, support_material, Vector3(x_offset, (ground_y + 0.12) * 0.5, z_offset))


func _road_point_damaged(city_id: int, point: Vector2, padding: float = 0.0) -> bool:
	if city_id < 0 or city_id >= cities.size():
		return false
	for damage in cities[city_id].get("road_damage", []):
		var center_data: Variant = damage.get("center", [])
		if not (center_data is Array) or center_data.size() < 2:
			continue
		var center := Vector2(float(center_data[0]), float(center_data[1]))
		if point.distance_to(center) <= float(damage.get("radius", 0.0)) + padding:
			return true
	return false


func _road_segment_intersects_damage(city_id: int, from_point: Vector2, to_point: Vector2, half_width: float) -> bool:
	if city_id < 0 or city_id >= cities.size():
		return false
	var segment: Vector2 = to_point - from_point
	var length_squared: float = segment.length_squared()
	for damage in cities[city_id].get("road_damage", []):
		var center_data: Variant = damage.get("center", [])
		if not (center_data is Array) or center_data.size() < 2:
			continue
		var center := Vector2(float(center_data[0]), float(center_data[1]))
		var t: float = clampf((center - from_point).dot(segment) / maxf(0.001, length_squared), 0.0, 1.0)
		var closest: Vector2 = from_point + segment * t
		if closest.distance_to(center) <= float(damage.get("radius", 0.0)) + half_width:
			return true
	return false


func _add_damaged_aware_road_segment(surface: SurfaceTool, city_id: int, city_position: Vector3, from_point: Vector2, to_point: Vector2, width: float = 0.48, height_offset: float = 0.10, endpoint_padding: float = 0.0) -> void:
	var delta: Vector2 = to_point - from_point
	var length: float = delta.length()
	if length < 0.5:
		return
	var direction: Vector2 = delta / length
	var start_point: Vector2 = from_point + direction * endpoint_padding
	var finish_point: Vector2 = to_point - direction * endpoint_padding
	var pieces: int = maxi(1, int(ceil(start_point.distance_to(finish_point) / 1.8)))
	for piece_index in range(pieces):
		var t0: float = float(piece_index) / float(pieces)
		var t1: float = float(piece_index + 1) / float(pieces)
		var a: Vector2 = start_point.lerp(finish_point, t0)
		var b: Vector2 = start_point.lerp(finish_point, t1)
		if _road_segment_intersects_damage(city_id, a, b, width * 0.5 + 0.08):
			continue
		_add_road_segment(surface, city_position, a, b, width, height_offset, 0.0)


func _damage_city_roads(city_id: int, world_position: Vector3, radius: float, rebuild_after: bool = true) -> bool:
	if city_id < 0 or city_id >= cities.size():
		return false
	var city: Dictionary = cities[city_id]
	if bool(city.get("ruined", false)) and (city.get("road_damage", []) as Array).is_empty():
		return false
	var city_position: Vector3 = city["pos"]
	var local_center := Vector2(world_position.x - city_position.x, world_position.z - city_position.z)
	var min_x: float = float(city.get("road_grid_min_x", -7.5))
	var max_x: float = float(city.get("road_grid_max_x", 7.5))
	var min_z: float = float(city.get("road_grid_min_z", -7.5))
	var max_z: float = float(city.get("road_grid_max_z", 7.5))
	if local_center.x + radius < min_x or local_center.x - radius > max_x or local_center.y + radius < min_z or local_center.y - radius > max_z:
		return false
	var damages: Array = city.get("road_damage", [])
	for damage_index in range(damages.size()):
		var damage: Dictionary = damages[damage_index]
		var center_data: Variant = damage.get("center", [])
		if not (center_data is Array) or center_data.size() < 2:
			continue
		var existing_center := Vector2(float(center_data[0]), float(center_data[1]))
		var existing_radius: float = float(damage.get("radius", 0.0))
		var separation: float = existing_center.distance_to(local_center)
		if separation <= existing_radius + radius * 0.70:
			damage["radius"] = maxf(existing_radius, separation + radius * 0.72)
			damages[damage_index] = damage
			city["road_damage"] = damages
			cities[city_id] = city
			if rebuild_after:
				_rebuild_city_roads(city_id)
			return true
	var damage_id: int = rubble_id_sequence
	damages.append({"id": damage_id, "center": [local_center.x, local_center.y], "radius": radius})
	city["road_damage"] = damages
	cities[city_id] = city
	_spawn_persistent_rubble(world_position, false, Color(0.23, 0.24, 0.24), true, "road", damage_id)
	if rebuild_after:
		_rebuild_city_roads(city_id)
	return true


func _damage_roads_at_position(world_position: Vector3, radius: float, rebuild_after: bool = true) -> Array[int]:
	var affected_city_ids: Array[int] = []
	for city_id in range(cities.size()):
		if _damage_city_roads(city_id, world_position, radius, false):
			affected_city_ids.append(city_id)
	if rebuild_after:
		for city_id in affected_city_ids:
			_rebuild_city_roads(city_id)
	return affected_city_ids


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


func _sculpt_terrain(center: Vector3, amount: float, finalize_edit: bool = true) -> void:
	# Convert the brush bounds to heightmap coordinates first. The old full-map
	# scan touched all 58,081 vertices for even a tiny crater.
	var spacing: float = TERRAIN_SIZE / float(TERRAIN_RES - 1)
	var radius: float = maxf(0.1, brush_radius)
	var half_size: float = TERRAIN_SIZE * 0.5
	var min_x: int = clampi(floori((center.x - radius + half_size) / spacing), 0, TERRAIN_RES - 1)
	var max_x: int = clampi(ceili((center.x + radius + half_size) / spacing), 0, TERRAIN_RES - 1)
	var min_z: int = clampi(floori((center.z - radius + half_size) / spacing), 0, TERRAIN_RES - 1)
	var max_z: int = clampi(ceili((center.z + radius + half_size) / spacing), 0, TERRAIN_RES - 1)
	var radius_squared: float = radius * radius
	for z_index in range(min_z, max_z + 1):
		var z: float = -half_size + float(z_index) * spacing
		var dz: float = z - center.z
		if dz * dz > radius_squared:
			continue
		for x_index in range(min_x, max_x + 1):
			var x: float = -half_size + float(x_index) * spacing
			var dx: float = x - center.x
			var distance_squared: float = dx * dx + dz * dz
			if distance_squared > radius_squared:
				continue
			var distance: float = sqrt(distance_squared)
			var strength: float = 1.0 - distance / radius
			var h: float = float(terrain_heights[z_index][x_index])
			var updated_height: float = clampf(h + amount * strength, -4.5, 10.0)
			# City territory only depends on which sampled cells are land. Avoid
			# rebuilding every city's territory meshes for inland sculpting that
			# cannot change the land/water mask.
			if (h > WATER_LEVEL + 0.10) != (updated_height > WATER_LEVEL + 0.10):
				pending_terrain_shoreline_change = true
			terrain_heights[z_index][x_index] = updated_height
	_queue_terrain_edit_update(center, radius)
	if not finalize_edit:
		return
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
			if not is_instance_valid(house):
				continue
			var house_world_x: float = p.x + house.position.x
			var house_world_z: float = p.z + house.position.z
			var base_height: float = _height_at(house_world_x, house_world_z)
			if bool(house.get_meta("terrain_terraced", false)):
				base_height = _max_terrain_height_in_radius(house_world_x, house_world_z, float(house.get_meta("plot_grade_radius", 2.25))) + 0.18
			house.position.y = base_height - p.y
	_schedule_city_territory_refresh()
	for city_id in range(cities.size()):
		_queue_city_roads_rebuild(city_id)
	for army in armies:
		var p: Vector3 = army["pos"]
		p.y = _height_at(p.x, p.z)
		army["pos"] = p
		if is_instance_valid(army["node"]):
			army["node"].position = p


func _update_placed_object_heights_near(center: Vector3, radius: float) -> void:
	_update_placed_object_heights_near_many([{"center": center, "radius": radius}])


func _terrain_edit_affects_point(x: float, z: float, edits: Array[Dictionary], extra_radius: float = 0.0) -> bool:
	for edit in edits:
		var center: Vector3 = edit.get("center", Vector3.ZERO)
		var radius: float = maxf(0.1, float(edit.get("radius", brush_radius))) + extra_radius
		var dx: float = x - center.x
		var dz: float = z - center.z
		if dx * dx + dz * dz <= radius * radius:
			return true
	return false


func _update_placed_object_heights_near_many(edits: Array[Dictionary], refresh_territory: bool = true) -> void:
	if edits.is_empty():
		return
	# Scan each world collection once for all brush strokes or meteor craters.
	for person_index in range(people.size()):
		var person: Dictionary = people[person_index]
		var position: Vector3 = person["pos"]
		if not _terrain_edit_affects_point(position.x, position.z, edits):
			continue
		position.y = _height_at(position.x, position.z)
		person["pos"] = position
		if is_instance_valid(person.get("node") as Node3D):
			(person["node"] as Node3D).position = position
		people[person_index] = person

	for resource_index in range(resources.size()):
		var resource: Dictionary = resources[resource_index]
		var position: Vector3 = resource["pos"]
		if not _terrain_edit_affects_point(position.x, position.z, edits):
			continue
		position.y = _height_at(position.x, position.z)
		resource["pos"] = position
		if is_instance_valid(resource.get("node") as Node3D):
			(resource["node"] as Node3D).position = position
		resources[resource_index] = resource

	for car_index in range(cars.size()):
		var car: Dictionary = cars[car_index]
		var car_position: Vector3 = car["pos"]
		var car_changed: bool = false
		if _terrain_edit_affects_point(car_position.x, car_position.z, edits):
			car_position.y = _height_at(car_position.x, car_position.z)
			car["pos"] = car_position
			car_changed = true
		var waypoint: Vector3 = car["waypoint"]
		if _terrain_edit_affects_point(waypoint.x, waypoint.z, edits):
			waypoint.y = _height_at(waypoint.x, waypoint.z)
			car["waypoint"] = waypoint
			car_changed = true
		if car_changed:
			var car_node: Node3D = car.get("node") as Node3D
			if is_instance_valid(car_node):
				car_node.position = car_position
			cars[car_index] = car

	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var old_city_position: Vector3 = city["pos"]
		var city_position: Vector3 = old_city_position
		var city_centre_affected: bool = _terrain_edit_affects_point(city_position.x, city_position.z, edits)
		if city_centre_affected:
			city_position.y = _height_at(city_position.x, city_position.z)
			city["pos"] = city_position
			var city_node: Node3D = city.get("node") as Node3D
			if is_instance_valid(city_node):
				city_node.position = city_position
		var anchor_y_offset: float = old_city_position.y - city_position.y
		for house in city["houses"]:
			if not is_instance_valid(house):
				continue
			var house_world_x: float = old_city_position.x + house.position.x
			var house_world_z: float = old_city_position.z + house.position.z
			var grade_radius: float = float(house.get_meta("plot_grade_radius", 2.25)) if bool(house.get_meta("terrain_terraced", false)) else 0.0
			if _terrain_edit_affects_point(house_world_x, house_world_z, edits, grade_radius):
				var base_height: float = _height_at(house_world_x, house_world_z)
				if grade_radius > 0.0:
					base_height = _max_terrain_height_in_radius(house_world_x, house_world_z, grade_radius) + 0.18
				house.position.y = base_height - city_position.y
			elif city_centre_affected:
				house.position.y += anchor_y_offset

		var road_min_x: float = float(city.get("road_grid_min_x", -7.5))
		var road_max_x: float = float(city.get("road_grid_max_x", 7.5))
		var road_min_z: float = float(city.get("road_grid_min_z", -7.5))
		var road_max_z: float = float(city.get("road_grid_max_z", 7.5))
		var road_intersects_edit: bool = false
		for edit in edits:
			var center: Vector3 = edit.get("center", Vector3.ZERO)
			var radius: float = maxf(0.1, float(edit.get("radius", brush_radius))) + 1.5
			var local_x: float = center.x - city_position.x
			var local_z: float = center.z - city_position.z
			if local_x + radius >= road_min_x and local_x - radius <= road_max_x and local_z + radius >= road_min_z and local_z - radius <= road_max_z:
				road_intersects_edit = true
				break
		if road_intersects_edit or (city_centre_affected and not is_equal_approx(anchor_y_offset, 0.0)):
			_queue_city_roads_rebuild(city_id)
		cities[city_id] = city

	for army_index in range(armies.size()):
		var army: Dictionary = armies[army_index]
		var position: Vector3 = army["pos"]
		if not _terrain_edit_affects_point(position.x, position.z, edits):
			continue
		position.y = _height_at(position.x, position.z)
		army["pos"] = position
		var army_node: Node3D = army.get("node") as Node3D
		if is_instance_valid(army_node):
			army_node.position = position
		armies[army_index] = army

	if refresh_territory:
		_schedule_city_territory_refresh()


func _scatter_world_resources() -> void:
	# Spread resource clusters over land that isn't already claimed by the
	# starter towns. Forest patches, food clearings, and stone deposits make
	# the continents feel inhabited beyond the initial city centres.
	var resources_before: int = resources.size()
	for patch_index in range(90):
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
			if patch_roll < 0.38:
				kind = "tree" if resource_roll < 0.76 else "food"
			elif patch_roll < 0.56:
				kind = "food" if resource_roll < 0.60 else "tree"
			elif patch_roll < 0.73:
				kind = "stone" if resource_roll < 0.72 else "tree"
			elif patch_roll < 0.84:
				kind = "iron_ore"
			elif patch_roll < 0.92:
				kind = "copper_ore"
			elif patch_roll < 0.975:
				kind = "coal"
			else:
				kind = "gold_ore"
			_spawn_resource(p, kind, randi_range(5, 10))

	_log("Scattered %d extra resources in natural patches across the land." % (resources.size() - resources_before))


func _seed_civilizations() -> void:
	# Start across the major continents and a few smaller islands so the map
	# immediately feels like a world with room for competing civilizations.
	var starts: Array[Vector2] = [
		Vector2(-102.0, -72.0),
		Vector2(114.0, -81.0),
		Vector2(9.0, 153.0),
		Vector2(-255.0, 96.0),
		Vector2(255.0, 183.0)
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
		cities[city_id]["treasury"] = 120.0
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
	var crosswalk_network := MeshInstance3D.new()
	crosswalk_network.name = "CrosswalkNetwork"
	crosswalk_network.material_override = _material(Color(0.88, 0.88, 0.80), 0.96)
	town.add_child(crosswalk_network)
	var island_network := MeshInstance3D.new()
	island_network.name = "RoundaboutIslands"
	island_network.material_override = _material(Color(0.24, 0.43, 0.24), 0.98)
	town.add_child(island_network)

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
		"crosswalks": crosswalk_network,
		"islands": island_network,
		"label": city_label,
		"event_marker": event_marker,
		"event_timer": 0.0,
		"far_marker": far_marker,
		"zone_fill": zone_fill,
		"zone_border": zone_border,
		"zone_radius": 0.0,
		"territory_cells": {},
		"next_plot_index": 0,
		"road_damage": [],
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
		"capital_id": index,
		"is_capital": true,
		"loyalty": 100.0,
		"autonomy": 0.0,
		"hostage_count": 0,
		"hostage_cooldown": 0.0,
		"airport": null,
		"seaport": null,
		"airport_attempted": false,
		"seaport_attempted": false,
		"food": 8.0,
		"wood": 5.0,
		"stone": 3.0,
		"iron": 0.0,
		"copper": 0.0,
		"coal": 0.0,
		"gold": 0.0,
		"treasury": 85.0,
		"electricity": 0.0,
		"internet": 0.0,
		"trade_volume": 0.0,
		"power_plant": null,
		"internet_hub": null,
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


func _apply_building_era_appearance(city_id: int, year: int, only_house_index: int = -1, update_all: bool = false) -> void:
	var appearance_started_usec: int = Time.get_ticks_usec()
	if city_id < 0 or city_id >= cities.size():
		return
	# Modernisation is deliberately serial per city. This keeps a new era from
	# replacing every roof in one frame, and gives each refurbishment visible time.
	if only_house_index < 0 and not update_all:
		for active_site in construction_sites:
			if int(active_site.get("city_id", -1)) == city_id and bool(active_site.get("refurbishment", false)):
				return
	var city: Dictionary = cities[city_id]
	var stage: int = int(city.get("stage", 0))
	var era: int = _historical_era_index(year)
	var population: int = int(city.get("population", _city_population(city_id)))
	var wealth: float = float(city.get("wealth", 12.0))
	var pop_band: int = int(population / 15)
	var wealth_band: int = 3 if wealth >= 50.0 else (2 if wealth >= 25.0 else (1 if wealth >= 18.0 else 0))
	for house_index in range((city["houses"] as Array).size()):
		if only_house_index >= 0 and house_index != only_house_index:
			continue
		var house: Node3D = city["houses"][house_index]
		if not is_instance_valid(house):
			continue
		if bool(house.get_meta("is_construction_site", false)):
			continue
		if int(house.get_meta("visual_era", -1)) == era and int(house.get_meta("visual_stage", -1)) == stage and int(house.get_meta("visual_pop_band", -1)) == pop_band and int(house.get_meta("visual_wealth_band", -1)) == wealth_band:
			continue
		var original_type: int = int(house.get_meta("base_building_type", house.get_meta("building_type", house_index % 5)))
		var plot_id: int = int(house.get_meta("plot_index", house_index))
		var variation_seed: int = abs((plot_id + 1) * 92821 + (city_id + 3) * 68917)
		var variation: int = variation_seed % URBAN_FACADE_PALETTE.size()
		var large_plot: bool = bool(house.get_meta("large_plot", false))
		var previous_visual_era: int = int(house.get_meta("visual_era", -1))
		if only_house_index < 0 and not update_all and previous_visual_era >= 0 and previous_visual_era < era:
			# Era renewals are visual mutations too. Queue the city when this frame's
			# shared building budget is spent, instead of starting one refurbishment
			# in every city during the same era transition.
			if in_simulation_frame and building_start_budget_remaining <= 0:
				_queue_city_development(city_id)
				break
			_setup_construction_site(house, city_id, original_type, plot_id, 0.0, true)
			if in_simulation_frame:
				building_start_budget_remaining = maxi(0, building_start_budget_remaining - 1)
				building_visual_mutation_consumed_this_frame = true
			break
		var kind: int = original_type
		# Farms give way to urban blocks after industrialisation.
		if year >= 1850 and stage >= 2 and kind == 4:
			kind = 3
		elif year < 1880 and kind >= 5:
			kind = 1 if kind == 5 else 3
		if large_plot and year >= 1950 and kind != 4:
			# Modern multi-lot sites tend to become offices, shops, or apartment blocks.
			match variation_seed % 3:
				0:
					kind = 6
				1:
					kind = 3
				_:
					kind = 5
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
			var width_variants: Array[float] = [2.30, 2.52, 2.66, 2.78, 2.42, 2.88, 2.58, 2.72, 2.35]
			var depth_variants: Array[float] = [2.52, 2.34, 2.48, 2.62, 2.70, 2.30, 2.56, 2.42, 2.64]
			width = width_variants[variation] + float(stage) * 0.10
			depth = depth_variants[(variation + 3) % depth_variants.size()] + float(stage) * 0.08
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
			height = float(floors) * (0.72 + float(variation % 4) * 0.055 if year < 1950 else 0.79 + float(variation % 5) * 0.035)
			wall = URBAN_FACADE_PALETTE[variation].lerp(wall, 0.42)
			roof_color = [Color(0.29, 0.27, 0.24), Color(0.24, 0.27, 0.29), Color(0.31, 0.25, 0.21)][variation % 3]
			if (kind in [1, 3, 5, 6] or (house_index % 9 == 0 and kind != 7)) and year >= 1880:
				if year >= 2000 and stage >= 3 and population >= 45 and wealth >= 20.0:
					floors = clampi(12 + int((population - 45) / 30) + (variation % 7) - 3, 10, 34)
					skyscraper = true
				elif year >= 1950 and stage >= 3 and population >= 35 and wealth >= 15.0:
					floors = clampi(7 + int((population - 35) / 18) + (variation % 5) - 2, 6, 23)
					skyscraper = true
				elif stage >= 2 and population >= 30 and wealth >= 18.0:
					floors = clampi(4 + int((population - 30) / 14) + (variation % 5) - 2, 3, 12)
					skyscraper = true
			if skyscraper:
				width = 2.40 if floors < 9 else (2.85 if floors < 18 else 3.22)
				depth = 2.32 if floors < 9 else (2.70 if floors < 18 else 3.02)
				height = float(floors) * (0.82 + float(variation % 5) * 0.035)
				wall = TOWER_FACADE_PALETTE[variation].lerp(city["color"], 0.04)
				roof_color = URBAN_FACADE_PALETTE[(variation + 3) % URBAN_FACADE_PALETTE.size()].darkened(0.12)
				if large_plot:
					width = 4.1
					depth = 3.9
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

		if not skyscraper and large_plot and kind != 4:
			width = minf(4.1, width * 1.52)
			depth = minf(3.9, depth * 1.48)
		elif urban and not skyscraper:
			width *= [0.91, 0.97, 1.0, 1.05, 0.89, 1.08, 0.96, 1.02, 0.93][variation]
			depth *= [1.03, 0.93, 1.0, 1.06, 0.97, 0.90, 1.05, 0.96, 1.01][variation]
		else:
			height *= [0.90, 1.0, 1.08, 0.95, 1.12, 0.92, 1.04, 0.98, 1.15][variation]
		if bool(house.get_meta("terrain_terraced", false)):
			_add_terraced_building_foundation(house, width, depth)
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
			var glass_material: StandardMaterial3D = _material(GLASS_PALETTE[(variation + (1 if skyscraper else 0)) % GLASS_PALETTE.size()], 0.38)
			glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			windows.material_override = glass_material
			house.add_child(windows)
			var flat_roof := BoxMesh.new()
			flat_roof.size = Vector3(width + 0.16, 0.18, depth + 0.16)
			_add_mesh(house, flat_roof, _material(roof_color), Vector3(0.0, height + 0.09, 0.0))
			if skyscraper:
				var crown := BoxMesh.new()
				crown.size = Vector3(width * (0.30 + float(variation % 4) * 0.08), 0.35 + float(variation % 3) * 0.18, depth * (0.30 + float((variation + 2) % 4) * 0.08))
				_add_mesh(house, crown, _material(URBAN_FACADE_PALETTE[(variation + 4) % URBAN_FACADE_PALETTE.size()].darkened(0.20)), Vector3(0.0, height + crown.size.y * 0.5, 0.0))
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
		if urban and large_plot and year >= 1950:
			# Commercial and office super-lots get recognisable loading/roof plant details.
			for unit_index in range(3):
				var rooftop_unit := BoxMesh.new()
				rooftop_unit.size = Vector3(0.34, 0.24, 0.30)
				var unit_x: float = (float(unit_index) - 1.0) * width * 0.26
				_add_mesh(house, rooftop_unit, _material(Color(0.34, 0.39, 0.41)), Vector3(unit_x, height + 0.31, -depth * 0.18))
			var canopy := BoxMesh.new()
			canopy.size = Vector3(width * 0.62, 0.12, 0.42)
			_add_mesh(house, canopy, _material(roof_color.lightened(0.18)), Vector3(0.0, minf(1.5, height * 0.48), depth * 0.5 + 0.18))
		if kind == 7:
			for stack_index in range(2):
				var stack := CylinderMesh.new()
				stack.top_radius = 0.16
				stack.bottom_radius = 0.22
				stack.height = 1.2
				stack.radial_segments = 8
				_add_mesh(house, stack, _material(Color(0.37, 0.38, 0.36)), Vector3((float(stack_index) - 0.5) * 1.25, height + 0.65, -depth * 0.22))
		var door := BoxMesh.new()
		door.size = Vector3(0.22, 0.42, 0.045)
		_add_mesh(house, door, _material(Color(0.23, 0.16, 0.11)), Vector3(0.0, 0.22, depth * 0.5 + 0.03))
		house.set_meta("building_type", kind)
		house.set_meta("visual_era", era)
		house.set_meta("visual_stage", stage)
		house.set_meta("visual_pop_band", pop_band)
		house.set_meta("visual_wealth_band", wealth_band)
		house.set_meta("building_height", height * house.scale.y)
		house.set_meta("building_width", width * house.scale.x)
		house.set_meta("building_depth", depth * house.scale.z)
		house.set_meta("is_skyscraper", skyscraper)
		if only_house_index < 0 and not update_all:
			# One eligible old building is either refurbished or refreshed per call.
			break
	_trace_slow_operation("building-facade-render", appearance_started_usec)


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
	var sync_started_usec: int = Time.get_ticks_usec()
	var houses_changed: bool = _sync_city_buildings(city_id) if population > 0 and not bool(city.get("ruined", false)) else false
	_trace_slow_operation("development-building-sync", sync_started_usec)
	if population > 0 and not bool(city.get("ruined", false)):
		# Cached era/population/wealth bands make this check cheap unless a building needs to change.
		var appearance_started_usec: int = Time.get_ticks_usec()
		_apply_building_era_appearance(city_id, _world_year())
		_trace_slow_operation("development-era-appearance", appearance_started_usec)
	var infrastructure_started_usec: int = Time.get_ticks_usec()
	_ensure_city_infrastructure(city_id, _world_year())
	_trace_slow_operation("development-infrastructure", infrastructure_started_usec)
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
			var plot_scale: float = 0.04 if bool(house.get_meta("large_plot", false)) else 0.07
			house.scale = Vector3.ONE * (1.0 + float(stage) * plot_scale)


func _spiral_grid_offset(index: int) -> Vector2i:
	if index < 0:
		return Vector2i.ZERO
	while spiral_grid_offsets.size() <= index:
		spiral_grid_position += spiral_grid_direction
		spiral_grid_offsets.append(spiral_grid_position)
		spiral_grid_segment_steps += 1
		if spiral_grid_segment_steps >= spiral_grid_segment_length:
			spiral_grid_segment_steps = 0
			spiral_grid_direction = Vector2i(-spiral_grid_direction.y, spiral_grid_direction.x)
			spiral_grid_segments_at_length += 1
			if spiral_grid_segments_at_length >= 2:
				spiral_grid_segments_at_length = 0
				spiral_grid_segment_length += 1
	return spiral_grid_offsets[index]

func _is_diagonal_avenue_plot(city_id: int, plot: Vector2i, year: int) -> bool:
	if year < 1880 or city_id < 0 or city_id >= cities.size():
		return false
	var city: Dictionary = cities[city_id]
	if int(city.get("stage", 0)) < 2:
		return false

	# Five distinct grid/arterial patterns, all grounded in North American and
	# Australian urban forms. The rectangular local grid stays intact; diagonals
	# are reserved for major corridors rather than turning the whole city into a
	# pinwheel of roads.
	var primary_diagonal: bool = false
	match city_id % 5:
		0: # Los Angeles-inspired: broad diagonal supergrid.
			primary_diagonal = plot.x == plot.y
		1: # New York-inspired: dense orthogonal grid with a few offset avenues.
			primary_diagonal = plot.x == -plot.y
		2: # Melbourne-inspired: regular grid with a diagonal CBD cut-through.
			primary_diagonal = plot.x == plot.y - 2
		3: # San Francisco-inspired: diagonal streets and hillside connectors.
			primary_diagonal = plot.x == -plot.y + 2
		_: # Brisbane-inspired: offset arterial crossing the regular street grid.
			primary_diagonal = plot.x == plot.y + 2
	if primary_diagonal:
		return true
	if year < 1950:
		return false

	# Auto-era road widening adds a second corridor, with different spacing and
	# offsets for each planning style so cities do not all copy the same template.
	match city_id % 5:
		0:
			return plot.x == plot.y - 4 or plot.x == plot.y + 4
		1:
			return plot.x == -plot.y + 5
		2:
			return plot.x == -plot.y + 2
		3:
			return plot.x == plot.y
		_:
			return plot.x == -plot.y - 2


func _large_plot_period_for_year(year: int, city_id: int = -1) -> int:
	var period: int = 16
	if year >= 2000:
		period = 6
	elif year >= 1950:
		period = 8
	elif year >= 1880:
		period = 11
	if city_id >= 0:
		# Dense downtown plans get more multi-lot office/apartment sites, while
		# hillside and river-edge plans keep more small parcels for irregular lots.
		match city_id % 5:
			0:
				period -= 1
			1:
				period -= 1 if year >= 1950 else 0
			3:
				period += 1
			_:
				pass
	return maxi(4, period)


func _is_large_city_plot(city_id: int, plot_index: int, year: int) -> bool:
	if year < 1780:
		return false
	var period: int = _large_plot_period_for_year(year, city_id)
	return (plot_index + city_id * 3) % period == int(period / 2)


func _setup_construction_site(house: Node3D, city_id: int, building_type: int, plot_index: int, progress: float = 0.0, refurbishment: bool = false) -> void:
	var setup_started_usec: int = Time.get_ticks_usec()
	if not is_instance_valid(house):
		return
	for child in house.get_children():
		child.free()
	var pad_size: float = 5.8 if bool(house.get_meta("large_plot", false)) else 2.8
	house.set_meta("is_construction_site", true)
	house.set_meta("is_refurbishment_site", refurbishment)
	house.set_meta("construction_progress", clampf(progress, 0.0, 0.99))
	house.set_meta("visual_era", -999)
	house.set_meta("visual_stage", -999)
	house.set_meta("visual_pop_band", -999)
	house.set_meta("visual_wealth_band", -999)
	var foundation := BoxMesh.new()
	foundation.size = Vector3(pad_size, 0.18, pad_size)
	_add_mesh(house, foundation, _material(Color(0.43, 0.43, 0.40)), Vector3(0.0, 0.09, 0.0))
	var scaffold := Node3D.new()
	scaffold.name = "ConstructionScaffold"
	house.add_child(scaffold)
	var post_mesh: Mesh = _cached_box_mesh(Vector3(0.10, 1.0, 0.10))
	var post_material: Material = _material(Color(0.78, 0.57, 0.27))
	var half: float = pad_size * 0.5
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			_add_mesh(scaffold, post_mesh, post_material, Vector3(float(sign_x) * half, 1.0, float(sign_z) * half))
	for level in range(1, 4):
		var rail := BoxMesh.new()
		rail.size = Vector3(pad_size, 0.07, 0.07)
		_add_mesh(scaffold, rail, _material(Color(0.55, 0.43, 0.28)), Vector3(0.0, float(level) * 0.65, -half))
		_add_mesh(scaffold, rail, _material(Color(0.55, 0.43, 0.28)), Vector3(0.0, float(level) * 0.65, half))
		var side_rail := BoxMesh.new()
		side_rail.size = Vector3(0.07, 0.07, pad_size)
		_add_mesh(scaffold, side_rail, _material(Color(0.55, 0.43, 0.28)), Vector3(-half, float(level) * 0.65, 0.0))
		_add_mesh(scaffold, side_rail, _material(Color(0.55, 0.43, 0.28)), Vector3(half, float(level) * 0.65, 0.0))
	var site_id: int = construction_id_sequence
	construction_id_sequence += 1
	var worker_targets: Array[Vector3] = [
		Vector3(-half - 0.45, 0.0, -half - 0.45),
		Vector3(half + 0.45, 0.0, half + 0.35)
	]
	var assigned_workers: int = 0
	var assigned_worker_entries: Array[Dictionary] = []
	var worker_search_started_usec: int = Time.get_ticks_usec()
	for person_index in range(people.size()):
		if assigned_workers >= worker_targets.size():
			break
		var person: Dictionary = people[person_index]
		if int(person.get("city_id", -1)) != city_id or not bool(person.get("alive", true)):
			continue
		if str(person.get("activity", "wandering")) not in ["wandering", "entering"]:
			continue
		var worker_node: Node3D = person.get("node") as Node3D
		if not is_instance_valid(worker_node):
			continue
		var target: Vector3 = _surface_position(house.global_position.x + worker_targets[assigned_workers].x, house.global_position.z + worker_targets[assigned_workers].z)
		person["activity"] = "constructing_walk"
		person["construction_site_id"] = site_id
		person["construction_target"] = target
		person["target"] = target
		person["walk_timer"] = 999.0
		person["indoor_house"] = null
		people[person_index] = person
		assigned_worker_entries.append({"person": person, "phase_index": person_index})
		assigned_workers += 1
	_trace_slow_operation("construction-worker-search", worker_search_started_usec)
	construction_sites.append({
		"id": site_id, "node": house, "city_id": city_id,
		"building_type": building_type, "plot_index": plot_index,
		"progress": clampf(progress, 0.0, 0.99),
		"duration": randf_range(6.0, 10.0) if refurbishment else randf_range(10.0, 18.0),
		"refurbishment": refurbishment, "scaffold": scaffold, "phase": randf() * TAU,
		"worker_count": assigned_workers, "worker_entries": assigned_worker_entries, "pad_size": pad_size,
		"last_simulation_clock": construction_simulation_clock
	})
	_trace_slow_operation("construction-scaffold-full-setup", setup_started_usec)


func _get_construction_site(site_id: int) -> Dictionary:
	for site in construction_sites:
		if int(site.get("id", -1)) == site_id:
			return site
	return {}


func _cancel_construction_site(house: Node3D) -> void:
	for site_index in range(construction_sites.size() - 1, -1, -1):
		var site: Dictionary = construction_sites[site_index]
		if site.get("node") != house:
			continue
		var site_id: int = int(site.get("id", -1))
		var worker_entries: Array = site.get("worker_entries", [])
		for worker_entry in worker_entries:
			var person: Dictionary = worker_entry.get("person", {})
			if int(person.get("construction_site_id", -1)) != site_id:
				continue
			person["construction_site_id"] = -1
			person["activity"] = "wandering"
			person["walk_timer"] = 0.0
			person["activity_timer"] = 0.0
		construction_sites.remove_at(site_index)
		return


func _update_construction_sites(_delta: float) -> void:
	var update_batch_started_usec: int = Time.get_ticks_usec()
	if construction_sites.is_empty():
		construction_site_update_cursor = 0
		return
	# Worker/scaffold updates can be surprisingly expensive when a large city has
	# dozens of active sites. Rotate through a small batch per frame, but calculate
	# each site's progress from the full accumulated simulation-time gap so the
	# animation cadence does not change the actual construction duration.
	var initial_count: int = construction_sites.size()
	var update_count: int = mini(MAX_CONSTRUCTION_SITE_UPDATES_PER_FRAME, initial_count)
	var start_index: int = posmod(construction_site_update_cursor, initial_count)
	var site_ids_to_update: Array[int] = []
	for offset in range(update_count):
		var source_index: int = (start_index + offset) % initial_count
		site_ids_to_update.append(int(construction_sites[source_index].get("id", -1)))
	construction_site_update_cursor = (start_index + update_count) % maxi(1, initial_count)

	for requested_site_id in site_ids_to_update:
		var site_index: int = -1
		for lookup_index in range(construction_sites.size()):
			if int(construction_sites[lookup_index].get("id", -1)) == requested_site_id:
				site_index = lookup_index
				break
		if site_index < 0:
			continue
		var site: Dictionary = construction_sites[site_index]
		var house: Node3D = site.get("node") as Node3D
		var city_id: int = int(site.get("city_id", -1))
		if not is_instance_valid(house) or city_id < 0 or city_id >= cities.size():
			construction_sites.remove_at(site_index)
			continue

		var previous_clock: float = float(site.get("last_simulation_clock", construction_simulation_clock))
		var site_delta: float = maxf(0.0, construction_simulation_clock - previous_clock)
		site["last_simulation_clock"] = construction_simulation_clock
		var progress: float = minf(1.0, float(site.get("progress", 0.0)) + site_delta / maxf(4.0, float(site.get("duration", 14.0))))
		if progress >= 1.0 and in_simulation_frame and building_start_budget_remaining <= 0:
			progress = 0.999
		site["progress"] = progress
		house.set_meta("construction_progress", progress)
		site["phase"] = float(site.get("phase", 0.0)) + site_delta * 2.8
		var scaffold: Node3D = site.get("scaffold") as Node3D
		if is_instance_valid(scaffold):
			scaffold.scale.y = 0.32 + progress * 0.68
		var worker_entries: Array = site.get("worker_entries", [])
		for worker_entry in worker_entries:
			var person: Dictionary = worker_entry.get("person", {})
			if int(person.get("construction_site_id", -1)) != int(site["id"]):
				continue
			var worker_node: Node3D = person.get("node") as Node3D
			if not bool(person.get("alive", true)) or not is_instance_valid(worker_node):
				continue
			if str(person.get("activity", "")) == "constructing":
				var phase_index: int = int(worker_entry.get("phase_index", 0))
				var phase: float = float(site["phase"]) + float(phase_index) * 0.75
				var reach: float = float(site["pad_size"]) * 0.35
				var worker_position: Vector3 = _surface_position(house.global_position.x + cos(phase) * reach, house.global_position.z + sin(phase) * reach)
				person["pos"] = worker_position
				person["target"] = worker_position
				worker_node.position = worker_position
				worker_node.rotation.y = -phase
				var arm: Node3D = person.get("right_arm") as Node3D
				if is_instance_valid(arm):
					arm.rotation.x = sin(phase * 3.0) * 0.75
		construction_sites[site_index] = site
		if progress < 1.0:
			continue

		if in_simulation_frame:
			building_start_budget_remaining = maxi(0, building_start_budget_remaining - 1)
			building_visual_mutation_consumed_this_frame = true
		var completed_city_id: int = int(site["city_id"])
		var site_id: int = int(site["id"])
		construction_sites.remove_at(site_index)
		for child in house.get_children():
			child.free()
		house.set_meta("is_construction_site", false)
		for worker_entry in worker_entries:
			var person: Dictionary = worker_entry.get("person", {})
			if int(person.get("construction_site_id", -1)) != site_id:
				continue
			person["construction_site_id"] = -1
			person["activity"] = "wandering"
			person["activity_timer"] = 0.0
			person["walk_timer"] = 0.0
			person["target"] = _choose_citizen_street_target(completed_city_id, person.get("pos", house.global_position), 12.0)
		house.set_meta("is_refurbishment_site", false)
		var completed_house_index: int = -1
		var city_houses: Array = cities[completed_city_id]["houses"]
		for candidate_index in range(city_houses.size()):
			if city_houses[candidate_index] == house:
				completed_house_index = candidate_index
				break
		if completed_house_index >= 0:
			_apply_building_era_appearance(completed_city_id, _world_year(), completed_house_index)
		else:
			_apply_building_era_appearance(completed_city_id, _world_year())
		if bool(site.get("refurbishment", false)):
			_log("%s refurbished an older building for the %s era." % [cities[completed_city_id]["name"], _historical_era_name(_world_year()).to_lower()])
		else:
			_log("%s completed a new building." % cities[completed_city_id]["name"])
		last_detail_signature = ""
	_trace_slow_operation("construction-site-batch", update_batch_started_usec)

func _queue_city_roads_rebuild(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size() or bool(cities[city_id].get("ruined", false)):
		return
	if pending_city_road_rebuild_set.has(city_id):
		return
	pending_city_road_rebuild_set[city_id] = true
	pending_city_road_rebuilds.append(city_id)


func _process_one_pending_city_road_rebuild() -> void:
	if Time.get_ticks_usec() < next_city_road_rebuild_usec or pending_city_road_rebuilds.is_empty():
		return
	var city_id: int = pending_city_road_rebuilds.pop_front()
	pending_city_road_rebuild_set.erase(city_id)
	if city_id < 0 or city_id >= cities.size() or bool(cities[city_id].get("ruined", false)):
		return
	var road_started_usec: int = Time.get_ticks_usec()
	_rebuild_city_roads(city_id)
	_trace_slow_operation("city-road-mesh-rebuild", road_started_usec)
	next_city_road_rebuild_usec = Time.get_ticks_usec() + CITY_ROAD_REBUILD_INTERVAL_USEC


func _queue_city_development(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	if bool(cities[city_id].get("ruined", false)) or _city_population(city_id) <= 0:
		return
	if pending_city_development_set.has(city_id):
		return
	pending_city_development_set[city_id] = true
	pending_city_development.append(city_id)


func _process_one_pending_city_development() -> void:
	if paused or not in_simulation_frame or building_start_budget_remaining <= 0 or pending_city_development.is_empty():
		return
	var city_id: int = pending_city_development.pop_front()
	pending_city_development_set.erase(city_id)
	if city_id < 0 or city_id >= cities.size():
		return
	if bool(cities[city_id].get("ruined", false)) or _city_population(city_id) <= 0:
		return
	_refresh_city_development(city_id)


func _sync_city_buildings(city_id: int) -> bool:
	if city_id < 0 or city_id >= cities.size() or _city_population(city_id) <= 0 or bool(cities[city_id].get("ruined", false)):
		return false
	# Loading must restore the saved building list exactly; it must never trigger
	# new purchases or rewrite the saved treasury during development refresh.
	if is_loading_world:
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
	var terrain_changed: bool = false
	var sync_buildings_started_usec: int = Time.get_ticks_usec()
	# A single city refresh can start at most one building, and the entire game
	# starts at most one building per frame. Remaining demand is queued for later
	# frames so several growing cities cannot all rebuild roads/meshes together.
	if in_simulation_frame and building_start_budget_remaining <= 0:
		if houses.size() < desired_houses:
			_queue_city_development(city_id)
		_trace_slow_operation("city-building-sync-budget-check", sync_buildings_started_usec)
		return false
	# A population or era update must not synchronously instantiate an entire
	# neighbourhood in one frame. Queue at most one new lot per development call.
	while houses.size() < desired_houses and houses.size() < MAX_CITY_HOUSES and houses.size() - houses_before < MAX_BUILDINGS_PER_DEVELOPMENT_TICK:
		var offset_x: float = 0.0
		var offset_z: float = 0.0
		var found_building_site: bool = false
		var chosen_plot_index: int = plot_index
		var candidate_large_plot: bool = false
		var candidate_footprint: float = 3.6
		# Reserve occasional civic squares and two-plot commercial sites.
		var lot_search_started_usec: int = Time.get_ticks_usec()
		for attempt in range(64):
			var plot: Vector2i = _spiral_grid_offset(plot_index)
			if plot_index % 17 == 8 or _is_diagonal_avenue_plot(city_id, plot, _world_year()):
				plot_index += 1
				continue
			candidate_large_plot = _is_large_city_plot(city_id, plot_index, _world_year())
			candidate_footprint = 8.8 if candidate_large_plot else 3.6
			offset_x = float(plot.x) * ROAD_GRID_SIZE + ROAD_GRID_SIZE * 0.5
			offset_z = float(plot.y) * ROAD_GRID_SIZE + ROAD_GRID_SIZE * 0.5
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
					var existing_footprint: float = float(existing_house.get_meta("plot_footprint", 3.6))
					if existing_offset.distance_to(Vector2(offset_x, offset_z)) < (candidate_footprint + existing_footprint) * 0.5 + 0.35:
						overlaps_existing = true
						break
			if on_land and not overlaps_existing:
				found_building_site = true
				chosen_plot_index = plot_index
				break
			plot_index += 1
		_trace_slow_operation("building-lot-search-overlap", lot_search_started_usec)
		if not found_building_site:
			break
		var building_year: int = _world_year()
		var pending_building_type: int = house_index_to_building_type(houses.size(), stage)
		var large_plot: bool = candidate_large_plot
		if large_plot and building_year >= 1880 and stage >= 2:
			if building_year >= 1950:
				pending_building_type = 6 if chosen_plot_index % 3 == 0 else 3
			else:
				pending_building_type = 3
		var money_cost: float = 3.6 + float(stage) * 0.65 + (5.0 if large_plot else 0.0)
		if building_year >= 1780:
			money_cost += 1.2
		if building_year >= 1950:
			money_cost += 1.5
		if pending_building_type == 7:
			money_cost += 1.0
		var wood_cost: float = 0.32 + (0.42 if large_plot else 0.0)
		var stone_cost: float = 0.24 + (0.40 if large_plot else 0.0)
		var iron_cost: float = 0.0
		if building_year >= 1780 and pending_building_type in [5, 6]:
			iron_cost = 0.22 + (0.22 if large_plot else 0.0)
		var copper_cost: float = 0.0
		if building_year >= 1950 and pending_building_type in [5, 6]:
			copper_cost = 0.08
		if float(city.get("treasury", 0.0)) < money_cost or float(city["wood"]) < wood_cost or float(city["stone"]) < stone_cost or float(city.get("iron", 0.0)) < iron_cost or float(city.get("copper", 0.0)) < copper_cost:
			plot_index = chosen_plot_index
			break
		city["treasury"] = maxf(0.0, float(city.get("treasury", 0.0)) - money_cost)
		city["wood"] = maxf(0.0, float(city["wood"]) - wood_cost)
		city["stone"] = maxf(0.0, float(city["stone"]) - stone_cost)
		city["iron"] = maxf(0.0, float(city.get("iron", 0.0)) - iron_cost)
		city["copper"] = maxf(0.0, float(city.get("copper", 0.0)) - copper_cost)
		plot_index = chosen_plot_index + 1
		var plot_radius: float = 3.45 if large_plot else 2.25
		var plot_grade_started_usec: int = Time.get_ticks_usec()
		var plot_grade: Dictionary = _sample_building_plot_grade(city["pos"].x + offset_x, city["pos"].z + offset_z, plot_radius)
		_trace_slow_operation("building-plot-grade-sampling", plot_grade_started_usec)
		terrain_changed = terrain_changed or bool(plot_grade.get("changed", false))
		var base_world_height: float = float(plot_grade.get("base_height", _height_at(city["pos"].x + offset_x, city["pos"].z + offset_z)))
		var house := Node3D.new()
		house.set_meta("terrain_terraced", bool(plot_grade.get("steep", false)))
		house.set_meta("plot_grade_radius", plot_radius)
		house.scale = Vector3.ONE * (1.0 + float(stage) * (0.04 if candidate_large_plot else 0.07))
		house.position = Vector3(offset_x, base_world_height - float(city["pos"].y), offset_z)
		city["node"].add_child(house)
		if in_simulation_frame:
			building_start_budget_remaining = maxi(0, building_start_budget_remaining - 1)
			building_visual_mutation_consumed_this_frame = true

		var building_type: int = pending_building_type
		house.set_meta("building_type", building_type)
		house.set_meta("base_building_type", building_type)
		house.set_meta("plot_index", chosen_plot_index)
		house.set_meta("large_plot", large_plot)
		house.set_meta("plot_footprint", 8.8 if large_plot else 3.6)
		houses.append(house)
		var construction_setup_started_usec: int = Time.get_ticks_usec()
		_setup_construction_site(house, city_id, building_type, chosen_plot_index)
		_trace_slow_operation("new-building-construction-setup", construction_setup_started_usec)
	city["houses"] = houses
	city["next_plot_index"] = plot_index
	cities[city_id] = city
	var houses_changed: bool = houses.size() != houses_before
	if in_simulation_frame and houses_changed and houses.size() < desired_houses and building_start_budget_remaining <= 0:
		_queue_city_development(city_id)
	if terrain_changed:
		_rebuild_terrain()
		_update_placed_object_heights()
	if houses_changed:
		if not terrain_changed:
			if in_simulation_frame:
				_queue_city_roads_rebuild(city_id)
			else:
				_rebuild_city_roads(city_id)
		var new_building_appearance_started_usec: int = Time.get_ticks_usec()
		_apply_building_era_appearance(city_id, _world_year())
		_trace_slow_operation("new-building-era-appearance", new_building_appearance_started_usec)
	_trace_slow_operation("city-building-sync-total", sync_buildings_started_usec)
	return houses_changed


func house_index_to_building_type(index: int, stage: int) -> int:
	var year: int = _world_year()
	var kind: int = index % 5
	if year >= 1780 and stage >= 2 and index % 13 == 6:
		return 7 # Industrial mine / metalworks.
	if year >= 1850 and stage >= 2 and kind == 4:
		kind = 3
	if year >= 1880 and stage >= 2 and kind != 4 and index % 5 == 1:
		kind = 5
	if year >= 1950 and stage >= 3 and kind != 4 and index % 7 == 2:
		kind = 6
	return kind


func _add_road_segment(surface: SurfaceTool, city_position: Vector3, from_point: Vector2, to_point: Vector2, width: float = 0.48, height_offset: float = 0.10, endpoint_padding: float = 0.0) -> void:
	var delta: Vector2 = to_point - from_point
	var distance: float = delta.length()
	if distance < 0.5:
		return
	var direction: Vector2 = delta / distance
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	var start_point: Vector2 = from_point + direction * endpoint_padding
	var finish_point: Vector2 = to_point - direction * endpoint_padding
	if finish_point.distance_to(start_point) < 0.1:
		return
	var segment_count: int = maxi(2, int(ceil(start_point.distance_to(finish_point) / 0.70)))
	var previous_left := Vector3.ZERO
	var previous_right := Vector3.ZERO
	for segment in range(segment_count + 1):
		var t: float = float(segment) / float(segment_count)
		var center_line: Vector2 = start_point.lerp(finish_point, t)
		var left_xz: Vector2 = center_line + side
		var right_xz: Vector2 = center_line - side
		var left := Vector3(left_xz.x, _terrain_render_height_at(city_position.x + left_xz.x, city_position.z + left_xz.y) - city_position.y + height_offset, left_xz.y)
		var right := Vector3(right_xz.x, _terrain_render_height_at(city_position.x + right_xz.x, city_position.z + right_xz.y) - city_position.y + height_offset, right_xz.y)
		if segment > 0:
			surface.add_vertex(previous_left)
			surface.add_vertex(previous_right)
			surface.add_vertex(left)
			surface.add_vertex(previous_right)
			surface.add_vertex(right)
			surface.add_vertex(left)
		previous_left = left
		previous_right = right


func _add_sidewalk_corner(surface: SurfaceTool, city_position: Vector3, intersection_x: float, intersection_z: float, sign_x: float, sign_z: float) -> void:
	var curb_edge: float = 0.81
	var walk_centre: float = 1.05
	var xa: float = intersection_x + sign_x * curb_edge
	var xb: float = intersection_x + sign_x * walk_centre
	var za: float = intersection_z + sign_z * curb_edge
	var zb: float = intersection_z + sign_z * walk_centre
	var min_x: float = minf(xa, xb)
	var max_x: float = maxf(xa, xb)
	var min_z: float = minf(za, zb)
	var max_z: float = maxf(za, zb)
	var a := Vector3(min_x, _terrain_render_height_at(city_position.x + min_x, city_position.z + min_z) - city_position.y + 0.55, min_z)
	var b := Vector3(max_x, _terrain_render_height_at(city_position.x + max_x, city_position.z + min_z) - city_position.y + 0.55, min_z)
	var c := Vector3(max_x, _terrain_render_height_at(city_position.x + max_x, city_position.z + max_z) - city_position.y + 0.55, max_z)
	var d := Vector3(min_x, _terrain_render_height_at(city_position.x + min_x, city_position.z + max_z) - city_position.y + 0.55, max_z)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)


func _add_roundabout_island(surface: SurfaceTool, city_position: Vector3, center_x: float, center_z: float, radius: float) -> void:
	var center_local := Vector2(center_x, center_z)
	var center_y: float = _height_at(city_position.x + center_x, city_position.z + center_z) - city_position.y + 0.48
	for segment in range(24):
		var angle_a: float = TAU * float(segment) / 24.0
		var angle_b: float = TAU * float(segment + 1) / 24.0
		var a_xz := center_local + Vector2(cos(angle_a), sin(angle_a)) * radius
		var b_xz := center_local + Vector2(cos(angle_b), sin(angle_b)) * radius
		var a := Vector3(a_xz.x, _height_at(city_position.x + a_xz.x, city_position.z + a_xz.y) - city_position.y + 0.48, a_xz.y)
		var b := Vector3(b_xz.x, _height_at(city_position.x + b_xz.x, city_position.z + b_xz.y) - city_position.y + 0.48, b_xz.y)
		surface.add_vertex(Vector3(center_x, center_y, center_z))
		surface.add_vertex(a)
		surface.add_vertex(b)


func _diagonal_road_is_clear(city_id: int, from_point: Vector2, to_point: Vector2, clearance: float = 2.6) -> bool:
	if city_id < 0 or city_id >= cities.size():
		return false
	var city: Dictionary = cities[city_id]
	var segment: Vector2 = to_point - from_point
	var length_squared: float = segment.length_squared()
	for house in city["houses"]:
		if not is_instance_valid(house):
			continue
		var building_center := Vector2(house.position.x, house.position.z)
		var t: float = clampf((building_center - from_point).dot(segment) / maxf(0.001, length_squared), 0.0, 1.0)
		var closest: Vector2 = from_point + segment * t
		if closest.distance_to(building_center) < clearance + float(house.get_meta("building_width", 2.8)) * 0.22:
			return false
	return true


func _rebuild_city_roads(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var road_node: MeshInstance3D = city["roads"]
	var sidewalk_node: MeshInstance3D = city.get("sidewalks") as MeshInstance3D
	var crosswalk_node: MeshInstance3D = city.get("crosswalks") as MeshInstance3D
	var island_node: MeshInstance3D = city.get("islands") as MeshInstance3D
	if not is_instance_valid(road_node):
		return
	var road_surface := SurfaceTool.new()
	road_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sidewalk_surface := SurfaceTool.new()
	sidewalk_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crosswalk_surface := SurfaceTool.new()
	crosswalk_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var island_surface := SurfaceTool.new()
	island_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var city_position: Vector3 = city["pos"]
	var houses: Array = city["houses"]
	if houses.is_empty():
		road_node.mesh = null
		if is_instance_valid(sidewalk_node):
			sidewalk_node.mesh = null
		if is_instance_valid(crosswalk_node):
			crosswalk_node.mesh = null
		if is_instance_valid(island_node):
			island_node.mesh = null
		city["road_grid_min_x"] = -7.5
		city["road_grid_max_x"] = 7.5
		city["road_grid_min_z"] = -7.5
		city["road_grid_max_z"] = 7.5
		cities[city_id] = city
		_rebuild_city_traffic_lights(city_id, [-7.5, 0.0, 7.5], [-7.5, 0.0, 7.5])
		return
	var min_x: float = 0.0
	var max_x: float = 0.0
	var min_z: float = 0.0
	var max_z: float = 0.0
	for house in houses:
		if not is_instance_valid(house):
			continue
		var footprint: float = maxf(3.0, float(house.get_meta("plot_footprint", 3.6)) * 0.28)
		min_x = minf(min_x, house.position.x - footprint)
		max_x = maxf(max_x, house.position.x + footprint)
		min_z = minf(min_z, house.position.z - footprint)
		max_z = maxf(max_z, house.position.z + footprint)
	var first_x: float = floor(min_x / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var last_x: float = ceil(max_x / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var first_z: float = floor(min_z / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	var last_z: float = ceil(max_z / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
	city["road_grid_min_x"] = first_x
	city["road_grid_max_x"] = last_x
	city["road_grid_min_z"] = first_z
	city["road_grid_max_z"] = last_z
	cities[city_id] = city
	var grid_x: Array[float] = []
	var grid_z: Array[float] = []
	var cursor_x: float = first_x
	while cursor_x <= last_x + 0.001:
		grid_x.append(cursor_x)
		var x_line_index: int = grid_x.size() - 1
		var x_road_width: float = 1.62
		if _world_year() >= 1950 and (x_line_index + city_id) % 4 == 1:
			x_road_width = 2.30
		elif _world_year() >= 1880 and (x_line_index + city_id) % 5 == 1:
			x_road_width = 1.92
		_add_damaged_aware_road_segment(road_surface, city_id, city_position, Vector2(cursor_x, min_z), Vector2(cursor_x, max_z), x_road_width, 0.34, 0.0)
		cursor_x += ROAD_GRID_SIZE
	var cursor_z: float = first_z
	while cursor_z <= last_z + 0.001:
		grid_z.append(cursor_z)
		var z_line_index: int = grid_z.size() - 1
		var z_road_width: float = 1.62
		if _world_year() >= 1950 and (z_line_index + city_id) % 4 == 2:
			z_road_width = 2.30
		elif _world_year() >= 1880 and (z_line_index + city_id) % 5 == 2:
			z_road_width = 1.92
		_add_damaged_aware_road_segment(road_surface, city_id, city_position, Vector2(min_x, cursor_z), Vector2(max_x, cursor_z), z_road_width, 0.34, 0.0)
		cursor_z += ROAD_GRID_SIZE

	for x_index in range(grid_x.size()):
		var x_value: float = grid_x[x_index]
		for z_index in range(grid_z.size() - 1):
			var sidewalk_start: float = grid_z[z_index] + 1.05
			var sidewalk_end: float = grid_z[z_index + 1] - 1.05
			if sidewalk_end <= sidewalk_start:
				continue
			for side_sign in [-1.0, 1.0]:
				_add_damaged_aware_road_segment(sidewalk_surface, city_id, city_position, Vector2(x_value + side_sign * 1.05, sidewalk_start), Vector2(x_value + side_sign * 1.05, sidewalk_end), 0.48, 0.58, 0.0)
	for z_index in range(grid_z.size()):
		var z_value: float = grid_z[z_index]
		for x_index in range(grid_x.size() - 1):
			var sidewalk_start_x: float = grid_x[x_index] + 1.05
			var sidewalk_end_x: float = grid_x[x_index + 1] - 1.05
			if sidewalk_end_x <= sidewalk_start_x:
				continue
			for side_sign in [-1.0, 1.0]:
				_add_damaged_aware_road_segment(sidewalk_surface, city_id, city_position, Vector2(sidewalk_start_x, z_value + side_sign * 1.05), Vector2(sidewalk_end_x, z_value + side_sign * 1.05), 0.48, 0.58, 0.0)

	for x_index in range(grid_x.size()):
		var x_value: float = grid_x[x_index]
		for z_index in range(grid_z.size()):
			var z_value: float = grid_z[z_index]
			for side_x in [-1.0, 1.0]:
				for side_z in [-1.0, 1.0]:
					if not _road_point_damaged(city_id, Vector2(x_value + side_x * 1.05, z_value + side_z * 1.05), 0.12):
						_add_sidewalk_corner(sidewalk_surface, city_position, x_value, z_value, side_x, side_z)
			if _world_year() >= 1900:
				for stripe_index in range(4):
					var stripe_offset: float = 0.95 + float(stripe_index) * 0.25
					for stripe_sign in [-1.0, 1.0]:
						_add_damaged_aware_road_segment(crosswalk_surface, city_id, city_position, Vector2(x_value - 0.78, z_value + stripe_sign * stripe_offset), Vector2(x_value + 0.78, z_value + stripe_sign * stripe_offset), 0.13, 0.44, 0.0)
						_add_damaged_aware_road_segment(crosswalk_surface, city_id, city_position, Vector2(x_value + stripe_sign * stripe_offset, z_value - 0.78), Vector2(x_value + stripe_sign * stripe_offset, z_value + 0.78), 0.13, 0.44, 0.0)
			if _world_year() >= 1880 and x_index > 0 and z_index > 0 and x_index < grid_x.size() - 1 and z_index < grid_z.size() - 1 and (x_index * 3 + z_index * 5 + city_id) % 11 == 2:
				var island_clear: bool = true
				for house in houses:
					if not is_instance_valid(house):
						continue
					if Vector2(house.position.x - x_value, house.position.z - z_value).length() < 3.9:
						island_clear = false
						break
				if island_clear:
					var ring_radius: float = 2.05
					for segment in range(20):
						var angle_a: float = TAU * float(segment) / 20.0
						var angle_b: float = TAU * float(segment + 1) / 20.0
						var a := Vector2(x_value, z_value) + Vector2(cos(angle_a), sin(angle_a)) * ring_radius
						var b := Vector2(x_value, z_value) + Vector2(cos(angle_b), sin(angle_b)) * ring_radius
						_add_damaged_aware_road_segment(road_surface, city_id, city_position, a, b, 1.18, 0.37, 0.0)
					_add_roundabout_island(island_surface, city_position, x_value, z_value, 0.92)

	var current_road_year: int = _world_year()
	var diagonal_frequency: int = 18
	if current_road_year >= 2000:
		diagonal_frequency = 7
	elif current_road_year >= 1950:
		diagonal_frequency = 9
	elif current_road_year >= 1880:
		diagonal_frequency = 12
	for x_index in range(grid_x.size() - 1):
		for z_index in range(grid_z.size() - 1):
			if current_road_year >= 1780 and (x_index * 7 + z_index * 11 + city_id) % diagonal_frequency == int(diagonal_frequency / 3):
				var start_point := Vector2(grid_x[x_index] + 1.25, grid_z[z_index] + 1.25)
				var finish_point := Vector2(grid_x[x_index + 1] - 1.25, grid_z[z_index + 1] - 1.25)
				var diagonal_width: float = 0.88 if current_road_year < 1880 else (1.08 if current_road_year < 1950 else 1.42)
				if _diagonal_road_is_clear(city_id, start_point, finish_point, 2.4):
					_add_damaged_aware_road_segment(road_surface, city_id, city_position, start_point, finish_point, diagonal_width, 0.36, 0.0)
			var reverse_start := Vector2(grid_x[x_index] + 1.25, grid_z[z_index + 1] - 1.25)
			var reverse_finish := Vector2(grid_x[x_index + 1] - 1.25, grid_z[z_index] + 1.25)
			if current_road_year >= 1880 and (x_index + z_index + city_id) % max(6, diagonal_frequency + 3) == int(diagonal_frequency / 2) and _diagonal_road_is_clear(city_id, reverse_start, reverse_finish, 2.4):
				var reverse_width: float = 1.12 if current_road_year < 1950 else 1.42
				_add_damaged_aware_road_segment(road_surface, city_id, city_position, reverse_start, reverse_finish, reverse_width, 0.36, 0.0)

	# Reserve and build continuous city-specific diagonal avenues through deliberately
	# open plots. Some cities resemble a Manhattan/Broadway grid, others an offset
	# arterial, so the entire planet does not become the same chessboard.
	if current_road_year >= 1880:
		for x_index in range(grid_x.size() - 1):
			for z_index in range(grid_z.size() - 1):
				var avenue_plot := Vector2i(roundi(grid_x[x_index] / ROAD_GRID_SIZE), roundi(grid_z[z_index] / ROAD_GRID_SIZE))
				if not _is_diagonal_avenue_plot(city_id, avenue_plot, current_road_year):
					continue
				var avenue_start: Vector2
				var avenue_finish: Vector2
				if city_id % 4 in [0, 2]:
					avenue_start = Vector2(grid_x[x_index] + 1.25, grid_z[z_index] + 1.25)
					avenue_finish = Vector2(grid_x[x_index + 1] - 1.25, grid_z[z_index + 1] - 1.25)
				else:
					avenue_start = Vector2(grid_x[x_index] + 1.25, grid_z[z_index + 1] - 1.25)
					avenue_finish = Vector2(grid_x[x_index + 1] - 1.25, grid_z[z_index] + 1.25)
				var avenue_width: float = 1.25 if current_road_year < 1950 else 1.58
				if _diagonal_road_is_clear(city_id, avenue_start, avenue_finish, 1.45):
					_add_damaged_aware_road_segment(road_surface, city_id, city_position, avenue_start, avenue_finish, avenue_width, 0.36, 0.0)

	# Steep districts get a few winding connectors rather than forcing every
	# climb to run in a ruler-straight line up the slope.
	var terrain_minimum: float = INF
	var terrain_maximum: float = -INF
	for x_value in grid_x:
		for z_value in grid_z:
			var sample_height: float = _terrain_render_height_at(city_position.x + x_value, city_position.z + z_value)
			terrain_minimum = minf(terrain_minimum, sample_height)
			terrain_maximum = maxf(terrain_maximum, sample_height)
	if terrain_maximum - terrain_minimum >= 2.1 and city_id % 3 != 1 and grid_x.size() >= 4 and grid_z.size() >= 3:
		var switchback_row: float = grid_z[int(grid_z.size() / 2)]
		for x_index in range(grid_x.size() - 1):
			var start_offset: float = 2.65 if x_index % 2 == 0 else -2.65
			var finish_offset: float = -start_offset
			var switch_start := Vector2(grid_x[x_index] + 0.95, switchback_row + start_offset)
			var switch_finish := Vector2(grid_x[x_index + 1] - 0.95, switchback_row + finish_offset)
			if _diagonal_road_is_clear(city_id, switch_start, switch_finish, 1.15):
				_add_damaged_aware_road_segment(road_surface, city_id, city_position, switch_start, switch_finish, 1.02, 0.38, 0.0)
	road_surface.generate_normals(true)
	road_node.mesh = road_surface.commit()
	if is_instance_valid(sidewalk_node):
		sidewalk_surface.generate_normals(true)
		sidewalk_node.mesh = sidewalk_surface.commit()
	if is_instance_valid(crosswalk_node):
		crosswalk_surface.generate_normals(true)
		crosswalk_node.mesh = crosswalk_surface.commit()
	if is_instance_valid(island_node):
		island_surface.generate_normals(true)
		island_node.mesh = island_surface.commit()
	_rebuild_city_traffic_lights(city_id, grid_x, grid_z)


func _rebuild_city_traffic_lights(city_id: int, grid_x: Array, grid_z: Array) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var town: Node3D = city["node"]
	var old_lights: Node = town.get_node_or_null("TrafficLights")
	var enabled: bool = _world_year() >= 1900 and not bool(city.get("ruined", false)) and _city_population(city_id) > 0 and not bool(city.get("abandoned", false))
	if not enabled:
		for record_index in range(traffic_light_records.size() - 1, -1, -1):
			if int(traffic_light_records[record_index].get("city_id", -1)) == city_id:
				traffic_light_records.remove_at(record_index)
		if is_instance_valid(old_lights):
			old_lights.free()
		town.set_meta("traffic_light_grid_signature", "disabled")
		return
	var signature: String = "%d|%d|%.1f|%.1f|%.1f|%.1f" % [grid_x.size(), grid_z.size(), float(grid_x[0]), float(grid_x[grid_x.size() - 1]), float(grid_z[0]), float(grid_z[grid_z.size() - 1])]
	if is_instance_valid(old_lights) and str(town.get_meta("traffic_light_grid_signature", "")) == signature:
		for node in old_lights.find_children("*", "MeshInstance3D", true, false):
			if node.name.begins_with("Red") or node.name.begins_with("Amber") or node.name.begins_with("Green"):
				pass
		_update_traffic_light_states()
		return
	for record_index in range(traffic_light_records.size() - 1, -1, -1):
		if int(traffic_light_records[record_index].get("city_id", -1)) == city_id:
			traffic_light_records.remove_at(record_index)
	if is_instance_valid(old_lights):
		old_lights.free()
	town.set_meta("traffic_light_grid_signature", signature)
	var light_root := Node3D.new()
	light_root.name = "TrafficLights"
	town.add_child(light_root)
	var pole_mesh: Mesh = _cached_box_mesh(Vector3(0.10, 2.05, 0.10))
	var head_mesh: Mesh = _cached_box_mesh(Vector3(0.34, 0.68, 0.22))
	var lamp_mesh: Mesh = _cached_box_mesh(Vector3(0.18, 0.14, 0.07))
	var pole_material: Material = _material(Color(0.12, 0.14, 0.16))
	var head_material: Material = _material(Color(0.07, 0.08, 0.09))
	var red_material: Material = _material(Color(0.95, 0.16, 0.13), 0.38)
	var amber_material: Material = _material(Color(1.0, 0.66, 0.12), 0.38)
	var green_material: Material = _material(Color(0.15, 0.86, 0.42), 0.38)
	var counter: int = 0
	for xi in range(grid_x.size()):
		for zi in range(grid_z.size()):
			if xi % 3 != 1 or zi % 3 != 1:
				continue
			var x_value: float = float(grid_x[xi])
			var z_value: float = float(grid_z[zi])
			var mast := Node3D.new()
			mast.name = "Signal_%d" % counter
			mast.position = Vector3(x_value + 0.93, 0.0, z_value + 0.93)
			light_root.add_child(mast)
			_add_mesh(mast, pole_mesh, pole_material, Vector3(0.0, 1.025, 0.0))
			_add_mesh(mast, head_mesh, head_material, Vector3(0.0, 2.05, 0.0))
			var red := _add_mesh(mast, lamp_mesh, red_material, Vector3(0.0, 2.26, -0.118))
			var amber := _add_mesh(mast, lamp_mesh, amber_material, Vector3(0.0, 2.05, -0.118))
			var green := _add_mesh(mast, lamp_mesh, green_material, Vector3(0.0, 1.84, -0.118))
			red.name = "RedLamp"
			amber.name = "AmberLamp"
			green.name = "GreenLamp"
			traffic_light_records.append({"city_id": city_id, "intersection": city["pos"] + Vector3(x_value, 0.0, z_value), "red": red, "amber": amber, "green": green, "phase_offset": (xi + zi) % 2})
			counter += 1
	_update_traffic_light_states()


func _update_traffic_lights(delta: float) -> void:
	traffic_light_timer += delta
	var phase_durations: Array[float] = [3.8, 3.8, 0.85]
	if traffic_light_timer >= phase_durations[traffic_light_phase]:
		traffic_light_timer = 0.0
		traffic_light_phase = (traffic_light_phase + 1) % phase_durations.size()
		_update_traffic_light_states()


func _update_traffic_light_states() -> void:
	for record in traffic_light_records:
		var local_phase: int = (traffic_light_phase + int(record.get("phase_offset", 0))) % 3
		var red: MeshInstance3D = record.get("red") as MeshInstance3D
		var amber: MeshInstance3D = record.get("amber") as MeshInstance3D
		var green: MeshInstance3D = record.get("green") as MeshInstance3D
		if is_instance_valid(red):
			red.visible = local_phase == 0
		if is_instance_valid(amber):
			amber.visible = local_phase == 2
		if is_instance_valid(green):
			green.visible = local_phase == 1


func _car_should_stop_for_signal(city_id: int, waypoint: Vector3) -> bool:
	if city_id < 0 or city_id >= cities.size() or _world_year() < 1900:
		return false
	if bool(cities[city_id].get("ruined", false)) or _city_population(city_id) <= 0:
		return false
	for record in traffic_light_records:
		if int(record.get("city_id", -1)) != city_id:
			continue
		var intersection: Vector3 = record.get("intersection", Vector3.ZERO)
		var dx: float = waypoint.x - intersection.x
		var dz: float = waypoint.z - intersection.z
		if dx * dx + dz * dz <= 0.1:
			var green: MeshInstance3D = record.get("green") as MeshInstance3D
			return not is_instance_valid(green) or not green.visible
	return false


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
		if roll < 0.40:
			_spawn_resource(resource_position, "tree", 8)
		elif roll < 0.65:
			_spawn_resource(resource_position, "food", 8)
		elif roll < 0.80:
			_spawn_resource(resource_position, "stone", 8)
		elif roll < 0.875:
			_spawn_resource(resource_position, "iron_ore", 8)
		elif roll < 0.93:
			_spawn_resource(resource_position, "copper_ore", 8)
		elif roll < 0.975:
			_spawn_resource(resource_position, "coal", 8)
		else:
			_spawn_resource(resource_position, "gold_ore", 8)


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
	elif kind == "food":
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
	else:
		var ore_color: Color = Color(0.48, 0.34, 0.25)
		if kind == "copper_ore":
			ore_color = Color(0.72, 0.35, 0.20)
		elif kind == "coal":
			ore_color = Color(0.16, 0.18, 0.20)
		elif kind == "gold_ore":
			ore_color = Color(0.91, 0.69, 0.20)
		var ore_rock := SphereMesh.new()
		ore_rock.radius = 0.75
		ore_rock.height = 0.88
		ore_rock.radial_segments = 7
		ore_rock.rings = 4
		_add_mesh(node, ore_rock, _material(ore_color), Vector3(0.0, 0.45, 0.0), Vector3(1.25, 0.78, 1.0))
		var ore_rock_small := SphereMesh.new()
		ore_rock_small.radius = 0.40
		ore_rock_small.height = 0.60
		ore_rock_small.radial_segments = 6
		ore_rock_small.rings = 3
		_add_mesh(node, ore_rock_small, _material(ore_color.lightened(0.16)), Vector3(0.53, 0.34, 0.23), Vector3(1.0, 0.78, 0.9))
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
		# Captive civilians are moved by their escort, not the civilian wandering AI.
		if activity == "hostage":
			continue
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
					person["activity"] = "wandering"
					person["activity_timer"] = 0.0
					person["vehicle_node"] = null
					person["walk_timer"] = 0.0
					if is_instance_valid(node):
						node.position = position
						node.visible = true
			people[i] = person
			continue

		if activity == "constructing_walk" or activity == "constructing":
			var site_id: int = int(person.get("construction_site_id", -1))
			var site: Dictionary = _get_construction_site(site_id)
			var site_node: Node3D = site.get("node") as Node3D
			if site.is_empty() or not is_instance_valid(site_node):
				person["activity"] = "wandering"
				person["construction_site_id"] = -1
				person["walk_timer"] = 0.0
				people[i] = person
				continue
			if activity == "constructing_walk":
				var construction_target: Vector3 = person.get("construction_target", site_node.global_position)
				var construction_distance: float = Vector2(position.x - construction_target.x, position.z - construction_target.z).length()
				if construction_distance <= 1.1:
					person["activity"] = "constructing"
					person["pos"] = position
				else:
					position = position.move_toward(Vector3(construction_target.x, position.y, construction_target.z), delta * 2.0)
					position.y = _height_at(position.x, position.z)
					person["pos"] = position
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
					# Move every assigned cleaner toward the rubble even if its
					# render node is valid. This used to be nested under the
					# wrong else branch, so visible cleaners never reached debris.
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
			if city_id >= 0 and city_id < cities.size() and not rubble_nodes.is_empty() and randf() < 0.42:
				selected_rubble_id = _find_nearby_cleanup_rubble(position, 34.0)
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
			var x_steps: int = maxi(0, roundi((max_x - min_x) / ROAD_GRID_SIZE))
			var z_steps: int = maxi(0, roundi((max_z - min_z) / ROAD_GRID_SIZE))
			if x_steps > 0 and z_steps > 0:
				var local_x: float
				var local_z: float
				if randf() < 0.5:
					var street_index: int = randi_range(0, x_steps)
					var street_side: float = -1.0 if randf() < 0.5 else 1.0
					local_x = min_x + float(street_index) * ROAD_GRID_SIZE + street_side * 1.05 + randf_range(-0.08, 0.08)
					var block_z: int = randi_range(0, z_steps - 1)
					local_z = min_z + float(block_z) * ROAD_GRID_SIZE + randf_range(1.25, ROAD_GRID_SIZE - 1.25)
				else:
					var street_index: int = randi_range(0, z_steps)
					var street_side: float = -1.0 if randf() < 0.5 else 1.0
					local_z = min_z + float(street_index) * ROAD_GRID_SIZE + street_side * 1.05 + randf_range(-0.08, 0.08)
					var block_x: int = randi_range(0, x_steps - 1)
					local_x = min_x + float(block_x) * ROAD_GRID_SIZE + randf_range(1.25, ROAD_GRID_SIZE - 1.25)
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
		if distance <= 2.8 and _car_should_stop_for_signal(city_id, waypoint):
			car["pos"] = position
			car["waiting_at_signal"] = true
			node.position = position
			cars[i] = car
			continue
		car["waiting_at_signal"] = false
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
	trade_timer += delta
	founding_timer += delta
	auto_war_timer += delta
	transport_timer += delta
	oil_update_timer += delta
	diplomacy_timer += delta
	if city_event_timer >= 22.0:
		city_event_timer = fmod(city_event_timer, 22.0)
		var events_started_usec: int = Time.get_ticks_usec()
		_process_city_events()
		_trace_slow_operation("city-event-cycle", events_started_usec)
	if resource_timer >= 4.0:
		resource_timer = fmod(resource_timer, 4.0)
		var collection_started_usec: int = Time.get_ticks_usec()
		_collect_resources()
		_trace_slow_operation("resource-collection", collection_started_usec)
		var economies_started_usec: int = Time.get_ticks_usec()
		_update_city_economies()
		_trace_slow_operation("city-economy-production", economies_started_usec)
	if trade_timer >= 12.0:
		trade_timer = fmod(trade_timer, 12.0)
		var trade_started_usec: int = Time.get_ticks_usec()
		_update_city_trade()
		_trace_slow_operation("diplomacy-trade", trade_started_usec)
	if diplomacy_timer >= 12.0:
		diplomacy_timer = fmod(diplomacy_timer, 12.0)
		_update_diplomacy()
	if oil_update_timer >= 8.0:
		oil_update_timer = fmod(oil_update_timer, 8.0)
		_update_oil_rigs()
	if transport_timer >= 5.0:
		transport_timer = fmod(transport_timer, 5.0)
		_spawn_transport_wave()
	if growth_timer >= 9.0:
		growth_timer = fmod(growth_timer, 9.0)
		var growth_started_usec: int = Time.get_ticks_usec()
		_grow_cities()
		_trace_slow_operation("city-growth-and-building-placement", growth_started_usec)
	if founding_timer >= 4.0:
		founding_timer = fmod(founding_timer, 4.0)
		var people_assignment_started_usec: int = Time.get_ticks_usec()
		_assign_wild_people()
		_trace_slow_operation("wild-citizen-assignment", people_assignment_started_usec)
		var founding_started_usec: int = Time.get_ticks_usec()
		_try_found_cities()
		_trace_slow_operation("new-city-founding", founding_started_usec)
	if auto_war_timer >= 31.0:
		auto_war_timer = fmod(auto_war_timer, 31.0)
		var auto_war_started_usec: int = Time.get_ticks_usec()
		_try_start_ai_war()
		_trace_slow_operation("ai-war-search", auto_war_started_usec)


func _update_city_economies() -> void:
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var population: int = _city_population(city_id)
		if population <= 0 or bool(city.get("ruined", false)):
			city["wealth"] = maxf(0.0, float(city.get("wealth", 0.0)) - 0.04)
			cities[city_id] = city
			continue
		var farms: int = 0
		var workshops: int = 0
		var commercial: int = 0
		var apartments: int = 0
		var mines: int = 0
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
				7:
					mines += 1

		# Farms sustain the population. Workshops turn timber into value;
		# commerce, taxes and rent feed the treasury that actually pays builders.
		city["food"] = minf(60.0, float(city["food"]) + float(farms) * 0.28)
		if workshops > 0 and float(city["wood"]) > 0.0:
			city["wood"] = maxf(0.0, float(city["wood"]) - minf(float(city["wood"]), float(workshops) * 0.035))
			city["wealth"] = minf(100.0, float(city["wealth"]) + float(workshops) * 0.16)
		city["wealth"] = minf(100.0, float(city["wealth"]) + float(commercial) * 0.14 + float(apartments) * 0.025)
		city["treasury"] = clampf(float(city.get("treasury", 85.0)) + float(population) * 0.035 + float(workshops) * 0.22 + float(commercial) * 0.28 + float(apartments) * 0.06 + float(mines) * 0.08 - float(city["houses"].size()) * 0.012, 0.0, 5000.0)
		if mines > 0 and _world_year() >= 1780 and float(city["treasury"]) >= float(mines) * 0.04:
			city["iron"] = minf(100.0, float(city.get("iron", 0.0)) + float(mines) * 0.20)
			city["coal"] = minf(100.0, float(city.get("coal", 0.0)) + float(mines) * 0.14)
			city["treasury"] = maxf(0.0, float(city["treasury"]) - float(mines) * 0.04)
		if commercial > 0:
			city["security"] = minf(100.0, float(city["security"]) + float(commercial) * 0.025)
		if farms > 0 and float(city["food"]) >= 7.0:
			city["stability"] = minf(100.0, float(city["stability"]) + 0.035 * float(farms))

		var plant: Node3D = city.get("power_plant") as Node3D
		if _world_year() >= 1880 and is_instance_valid(plant) and float(city.get("coal", 0.0)) >= 0.10 and float(city["treasury"]) >= 0.05:
			city["coal"] = maxf(0.0, float(city["coal"]) - 0.10)
			city["treasury"] = maxf(0.0, float(city["treasury"]) - 0.05)
			city["electricity"] = minf(100.0, float(city.get("electricity", 0.0)) + 0.8 + float(workshops) * 0.08 + float(commercial) * 0.05)
		elif _world_year() < 1880:
			city["electricity"] = 0.0
		else:
			city["electricity"] = maxf(0.0, float(city.get("electricity", 0.0)) - 0.18)

		var hub: Node3D = city.get("internet_hub") as Node3D
		if _world_year() >= 2000 and is_instance_valid(hub) and float(city.get("electricity", 0.0)) >= 12.0 and float(city.get("copper", 0.0)) >= 0.02 and float(city["treasury"]) >= 0.03:
			city["copper"] = maxf(0.0, float(city["copper"]) - 0.02)
			city["treasury"] = maxf(0.0, float(city["treasury"]) - 0.03)
			city["internet"] = minf(100.0, float(city.get("internet", 0.0)) + 0.9 + float(commercial) * 0.12)
		elif _world_year() < 2000:
			city["internet"] = 0.0
		else:
			city["internet"] = maxf(0.0, float(city.get("internet", 0.0)) - 0.12)
		city["wealth"] = minf(100.0, float(city["wealth"]) + float(city.get("electricity", 0.0)) * 0.0007 + float(city.get("internet", 0.0)) * 0.001)
		cities[city_id] = city
		_apply_building_era_appearance(city_id, _world_year())
		_ensure_city_infrastructure(city_id, _world_year())


func _city_relation_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


func _city_relation(a: int, b: int) -> float:
	if a == b:
		return 100.0
	if _same_faction(a, b):
		return maxf(25.0, float(city_relations.get(_city_relation_key(a, b), 0.0)))
	return float(city_relations.get(_city_relation_key(a, b), 0.0))


func _adjust_city_relation(a: int, b: int, amount: float) -> void:
	if a < 0 or b < 0 or a >= cities.size() or b >= cities.size() or a == b:
		return
	var key: String = _city_relation_key(a, b)
	city_relations[key] = clampf(float(city_relations.get(key, 0.0)) + amount, -100.0, 100.0)


func _city_relationship_summary(city_id: int) -> String:
	if city_id < 0 or city_id >= cities.size():
		return "RELATIONS: unknown"
	var wars_with: Array[String] = []
	var allies_with: Array[String] = []
	var trade_partners: int = 0
	var friendly: int = 0
	var city: Dictionary = cities[city_id]
	for other_id in range(cities.size()):
		if other_id == city_id:
			continue
		if _are_at_war(city_id, other_id):
			wars_with.append(str(cities[other_id]["name"]))
		else:
			if _are_allied(city_id, other_id):
				allies_with.append(str(cities[other_id]["name"]))
			if _city_relation(city_id, other_id) >= 20.0:
				friendly += 1
			if _city_relation(city_id, other_id) > -35.0:
				trade_partners += 1
	var polity_status: String = "CAPITAL"
	if not bool(city.get("is_capital", true)):
		var parent_id: int = clampi(int(city.get("capital_id", city_id)), 0, cities.size() - 1)
		polity_status = "SATELLITE OF %s · LOYALTY %.0f%%" % [cities[parent_id]["name"], float(city.get("loyalty", 70.0))]
	var summary: String = "%s · FRIENDS %d · TRADE %d" % [polity_status, friendly, trade_partners]
	if not allies_with.is_empty():
		summary += " · ALLIANCES %s" % ", ".join(allies_with.slice(0, 2))
	if not wars_with.is_empty():
		summary += " · WAR WITH %s" % ", ".join(wars_with.slice(0, 2))
	return summary


func _update_city_trade() -> void:
	if cities.size() < 2:
		return
	for source_id in range(cities.size()):
		var source: Dictionary = cities[source_id]
		if _city_population(source_id) <= 0 or bool(source.get("ruined", false)):
			continue
		for target_id in range(source_id + 1, cities.size()):
			if _are_at_war(source_id, target_id):
				continue # War immediately blocks all trade between these city-states.
			if _city_relation(source_id, target_id) < -35.0:
				continue
			var target: Dictionary = cities[target_id]
			if _city_population(target_id) <= 0 or bool(target.get("ruined", false)):
				continue
			var distance: float = Vector2(source["pos"].x - target["pos"].x, source["pos"].z - target["pos"].z).length()
			var traded: bool = false
			for good in TRADE_GOODS:
				if _trade_city_good(source_id, target_id, good, distance) or _trade_city_good(target_id, source_id, good, distance):
					traded = true
					break
			if traded:
				_adjust_city_relation(source_id, target_id, 0.35)
				trade_events_total += 1
				if trade_events_total == 1 or trade_events_total % 5 == 0:
					_log("TRADE: %s and %s exchanged supplies. Peaceful relations are improving." % [cities[source_id]["name"], cities[target_id]["name"]])


func _trade_city_good(seller_id: int, buyer_id: int, good: String, distance: float) -> bool:
	if seller_id < 0 or buyer_id < 0 or seller_id >= cities.size() or buyer_id >= cities.size():
		return false
	if _are_at_war(seller_id, buyer_id) or _city_relation(seller_id, buyer_id) < -35.0:
		return false
	var seller: Dictionary = cities[seller_id]
	var buyer: Dictionary = cities[buyer_id]
	var reserve: float = 1.0
	var target_stock: float = 6.0
	var price: float = 1.0
	match good:
		"food":
			reserve = 5.0
			target_stock = 15.0
			price = 0.7
		"wood":
			reserve = 3.0
			target_stock = 9.0
			price = 0.9
		"stone":
			reserve = 2.0
			target_stock = 7.0
			price = 1.1
		"iron":
			reserve = 1.5
			target_stock = 7.0
			price = 1.8
		"copper":
			reserve = 1.0
			target_stock = 5.0
			price = 2.0
		"coal":
			reserve = 1.5
			target_stock = 6.0
			price = 1.2
		"gold":
			reserve = 0.2
			target_stock = 2.0
			price = 3.0
	var available: float = float(seller.get(good, 0.0)) - reserve
	var wanted: float = target_stock - float(buyer.get(good, 0.0))
	if available <= 0.15 or wanted <= 0.15:
		return false
	var amount: float = minf(2.4, minf(available, wanted))
	if distance > 100.0:
		amount *= 0.75
	if amount * price > float(buyer.get("treasury", 0.0)):
		amount = minf(amount, float(buyer.get("treasury", 0.0)) / price)
	if amount < 0.20:
		return false
	seller[good] = maxf(0.0, float(seller.get(good, 0.0)) - amount)
	buyer[good] = float(buyer.get(good, 0.0)) + amount
	buyer["treasury"] = maxf(0.0, float(buyer.get("treasury", 0.0)) - amount * price)
	seller["treasury"] = minf(5000.0, float(seller.get("treasury", 0.0)) + amount * price)
	seller["trade_volume"] = float(seller.get("trade_volume", 0.0)) + amount
	buyer["trade_volume"] = float(buyer.get("trade_volume", 0.0)) + amount
	cities[seller_id] = seller
	cities[buyer_id] = buyer
	return true

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
			if int(resource.get("amount", 0)) <= 0 or not bool(resource.get("alive", true)):
				continue
			var resource_pos: Vector3 = resource["pos"]
			var city_pos: Vector3 = city["pos"]
			var distance: float = Vector2(resource_pos.x - city_pos.x, resource_pos.z - city_pos.z).length()
			if distance > 15.0:
				continue
			var kind: String = str(resource.get("type", ""))
			var inventory_key: String = ""
			var gathered: float = 1.0
			var capacity: float = 30.0
			match kind:
				"food":
					inventory_key = "food"
					gathered = 2.0
					capacity = 60.0
				"tree":
					inventory_key = "wood"
					gathered = 1.6
					capacity = 45.0
				"stone":
					inventory_key = "stone"
					gathered = 1.3
					capacity = 35.0
				"iron_ore":
					inventory_key = "iron"
					gathered = 1.1
					capacity = 30.0
				"copper_ore":
					inventory_key = "copper"
					gathered = 0.9
					capacity = 25.0
				"coal":
					inventory_key = "coal"
					gathered = 1.1
					capacity = 35.0
				"gold_ore":
					inventory_key = "gold"
					gathered = 0.45
					capacity = 15.0
			if inventory_key.is_empty():
				continue
			var stock: float = float(city.get(inventory_key, 0.0))
			if stock >= capacity:
				continue
			city[inventory_key] = minf(capacity, stock + gathered)
			resource["amount"] = int(resource["amount"]) - 1
			if int(resource["amount"]) <= 0:
				resource["alive"] = false
				if is_instance_valid(resource.get("node")):
					(resource["node"] as Node3D).visible = false
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
			var parent_capital: int = -1
			var parent_distance: float = TERRAIN_SIZE * 0.34
			for existing_city_id in range(new_city_id):
				var existing_city: Dictionary = cities[existing_city_id]
				var candidate_capital: int = int(existing_city.get("capital_id", existing_city_id))
				if candidate_capital < 0 or candidate_capital >= cities.size():
					candidate_capital = existing_city_id
				if not bool(cities[candidate_capital].get("is_capital", true)):
					continue
				var existing_position: Vector3 = existing_city["pos"]
				var distance_to_city: float = Vector2(existing_position.x - center_x, existing_position.z - center_z).length()
				if distance_to_city < parent_distance:
					parent_distance = distance_to_city
					parent_capital = candidate_capital
			if parent_capital >= 0:
				cities[new_city_id]["owner"] = int(cities[parent_capital]["owner"])
				cities[new_city_id]["capital_id"] = parent_capital
				cities[new_city_id]["is_capital"] = false
				cities[new_city_id]["loyalty"] = randf_range(65.0, 82.0)
				cities[new_city_id]["autonomy"] = 100.0 - float(cities[new_city_id]["loyalty"])
				city_relations[_city_relation_key(new_city_id, parent_capital)] = 45.0
			for member_id in members:
				people[member_id]["city_id"] = new_city_id
				var member: Dictionary = people[member_id]
				var city_position: Vector3 = cities[new_city_id]["pos"]
				member["home_offset"] = Vector2(member["pos"].x - city_position.x, member["pos"].z - city_position.z)
				people[member_id] = member
			_refresh_city_development(new_city_id)
			_schedule_city_territory_refresh()
			_seed_resources_around(cities[new_city_id]["pos"])
			if parent_capital >= 0:
				_log("SETTLEMENT FOUNDED: %s was founded by %d settlers under the capital of %s. Loyalty and local stability will determine future independence." % [new_name, members.size(), cities[parent_capital]["name"]])
			else:
				cities[new_city_id]["is_capital"] = true
				cities[new_city_id]["capital_id"] = new_city_id
				cities[new_city_id]["owner"] = new_city_id
				_log("NEW CAPITAL: %s was founded by %d settlers beyond the reach of existing polities." % [new_name, members.size()])
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
	if game_clock < float(city.get("next_city_event_time", 0.0)):
		return false
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


func _pick_city_event_location(city_id: int) -> Vector3:
	if city_id < 0 or city_id >= cities.size():
		return Vector3.ZERO
	var city: Dictionary = cities[city_id]
	var city_position: Vector3 = city["pos"]
	var min_x: float = float(city.get("road_grid_min_x", -7.5))
	var max_x: float = float(city.get("road_grid_max_x", 7.5))
	var min_z: float = float(city.get("road_grid_min_z", -7.5))
	var max_z: float = float(city.get("road_grid_max_z", 7.5))
	for attempt in range(16):
		var local_x: float = roundf(randf_range(min_x, max_x) / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
		var local_z: float = roundf(randf_range(min_z, max_z) / ROAD_GRID_SIZE) * ROAD_GRID_SIZE
		var world_x: float = clampf(city_position.x + local_x, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
		var world_z: float = clampf(city_position.z + local_z, -TERRAIN_SIZE * 0.47, TERRAIN_SIZE * 0.47)
		if _height_at(world_x, world_z) > WATER_LEVEL + 0.2:
			return _surface_position(world_x, world_z)
	return city_position


func _record_city_event(city_id: int, event_name: String, event_color: Color) -> void:
	city_events_total += 1
	if reset_speed_on_city_event:
		sim_speed = 1.0
		if is_instance_valid(speed_button):
			speed_button.text = "Simulation Speed: 1×"
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var event_position: Vector3 = _pick_city_event_location(city_id)
	var marker: Label3D = city["event_marker"]
	if is_instance_valid(marker):
		marker.text = event_name
		marker.modulate = event_color
		marker.position = event_position - city["pos"] + Vector3(0.0, 9.0, 0.0)
		marker.visible = true
	city["event_timer"] = 12.0
	var cooldown_min: float = 10.0
	var cooldown_max: float = 18.0
	match event_name:
		"ATTACK", "REBELLION":
			cooldown_min = 28.0
			cooldown_max = 42.0
		"BANK ROBBERY":
			cooldown_min = 20.0
			cooldown_max = 32.0
		"PROTEST", "FOOD PROTEST", "FOOD RIOT", "STRIKE":
			cooldown_min = 16.0
			cooldown_max = 26.0
		"FESTIVAL":
			cooldown_min = 12.0
			cooldown_max = 22.0
	city["next_city_event_time"] = game_clock + randf_range(cooldown_min, cooldown_max)
	cities[city_id] = city
	_spawn_city_event_visual(city_id, event_name, event_position)


func _spawn_city_event_visual(city_id: int, event_name: String, event_position: Vector3) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	var centre: Vector3 = event_position
	if event_name == "PLANE CRASH":
		var crash_root := Node3D.new()
		crash_root.name = "PlaneCrashSite"
		crash_root.position = centre
		add_child(crash_root)
		_add_mesh(crash_root, _cached_box_mesh(Vector3(0.8, 0.5, 4.3)), _material(Color(0.28, 0.31, 0.32)), Vector3.ZERO)
		_add_mesh(crash_root, _cached_box_mesh(Vector3(3.4, 0.12, 0.7)), _material(Color(0.35, 0.37, 0.37)), Vector3(0.0, 0.15, 0.15))
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 1.3
		flame_mesh.height = 2.6
		flame.mesh = flame_mesh
		flame.material_override = _material(Color(1.0, 0.28, 0.04, 0.82))
		flame.position = Vector3(0.0, 1.2, 0.2)
		crash_root.add_child(flame)
		var smoke := MeshInstance3D.new()
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 1.3
		smoke_mesh.height = 2.6
		smoke.mesh = smoke_mesh
		var smoke_material := _material(Color(0.18, 0.18, 0.17, 0.65))
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke.material_override = smoke_material
		smoke.position = Vector3(0.0, 2.0, 0.0)
		crash_root.add_child(smoke)
		city_event_scenes.append({"node": crash_root, "kind": "crash", "flame": flame, "smoke": smoke, "age": 0.0, "duration": 9.0})
		return
	if event_name == "AIR HIJACK":
		var hijack_root := Node3D.new()
		hijack_root.name = "AircraftHijackingIncident"
		hijack_root.position = centre
		add_child(hijack_root)
		var signal_label := Label3D.new()
		signal_label.text = "AIR HIJACK"
		signal_label.font_size = 42
		signal_label.pixel_size = 0.012
		signal_label.outline_size = 9
		signal_label.modulate = Color(1.0, 0.18, 0.12)
		signal_label.position = Vector3(0.0, 8.0, 0.0)
		hijack_root.add_child(signal_label)
		city_event_scenes.append({"node": hijack_root, "kind": "hijack", "label": signal_label, "age": 0.0, "duration": 7.0})
		return
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
		elif kind == "crash":
			var flame: MeshInstance3D = scene.get("flame") as MeshInstance3D
			var smoke: MeshInstance3D = scene.get("smoke") as MeshInstance3D
			if is_instance_valid(flame):
				flame.scale = Vector3.ONE * maxf(0.25, 1.0 + sin(age * 8.0) * 0.22)
				flame.visible = age < 6.0
			if is_instance_valid(smoke):
				smoke.scale = Vector3.ONE * (0.45 + age * 0.16)
				smoke.position.y = 2.0 + age * 0.55
		elif kind == "hijack":
			var hijack_label: Label3D = scene.get("label") as Label3D
			if is_instance_valid(hijack_label):
				hijack_label.position.y = 8.0 + sin(age * 4.0) * 0.7
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
			marker.position = Vector3(3.2, 9.0, 0.0)
		cities[city_id] = city


func _try_start_ai_war() -> void:
	if cities.size() < 2:
		return
	var best_source: int = -1
	var best_target: int = -1
	var best_tension: float = -INF
	for source in range(cities.size()):
		for target in range(source + 1, cities.size()):
			if _same_faction(source, target) or _are_at_war(source, target) or _are_allied(source, target):
				continue
			var relation: float = _city_relation(source, target)
			var tension: float = -relation + randf_range(-10.0, 10.0)
			for rig in oil_rigs:
				if int(rig.get("owner_city", -1)) == source or int(rig.get("owner_city", -1)) == target:
					tension += 12.0
			if tension > best_tension:
				best_tension = tension
				best_source = source
				best_target = target
	if best_source < 0:
		return
	var source_id: int = best_source
	var target_id: int = best_target
	var relation_score: float = _city_relation(source_id, target_id)
	var conflict_chance: float = 0.20
	if relation_score < -20.0:
		conflict_chance += 0.25
	if relation_score < -55.0:
		conflict_chance += 0.20
	for rig in oil_rigs:
		if int(rig.get("owner_city", -1)) == source_id or int(rig.get("owner_city", -1)) == target_id:
			conflict_chance += 0.08
	if randf() < minf(0.82, conflict_chance):
		_launch_army(source_id, target_id, true)
	else:
		_adjust_city_relation(source_id, target_id, -randf_range(1.5, 5.0))
		_log("DIPLOMATIC CRISIS: %s and %s are disputing resources and border influence." % [cities[source_id]["name"], cities[target_id]["name"]])


func _are_allied(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= cities.size() or b >= cities.size() or a == b:
		return false
	return bool(alliances.get(_city_relation_key(a, b), false))


func _update_diplomacy() -> void:
	# Satellites pay a small levy and build loyalty when the capital is stable;
	# shortages and unrest make a breakaway more likely over time.
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		if bool(city.get("is_capital", true)):
			continue
		var capital_id: int = int(city.get("capital_id", -1))
		if capital_id < 0 or capital_id >= cities.size() or capital_id == city_id:
			city["capital_id"] = city_id
			city["is_capital"] = true
			city["owner"] = city_id
			cities[city_id] = city
			continue
		if not _same_faction(city_id, capital_id):
			continue
		var loyalty: float = float(city.get("loyalty", 70.0))
		if float(city.get("food", 0.0)) < 2.0 or float(city.get("stability", 72.0)) < 38.0:
			loyalty -= randf_range(1.1, 2.8)
		else:
			loyalty += randf_range(0.15, 0.65)
		var capital: Dictionary = cities[capital_id]
		var tribute: float = minf(0.45, maxf(0.0, float(city.get("treasury", 0.0)) - 8.0) * 0.02)
		if tribute > 0.0 and float(capital.get("treasury", 0.0)) < 5000.0:
			city["treasury"] = maxf(0.0, float(city.get("treasury", 0.0)) - tribute)
			capital["treasury"] = minf(5000.0, float(capital.get("treasury", 0.0)) + tribute)
			cities[capital_id] = capital
			loyalty += 0.12
		city["loyalty"] = clampf(loyalty, 0.0, 100.0)
		city["autonomy"] = clampf(100.0 - float(city["loyalty"]), 0.0, 90.0)
		cities[city_id] = city
		if float(city["loyalty"]) < 24.0 and float(city.get("stability", 72.0)) < 52.0 and randf() < 0.22:
			_declare_city_independence(city_id, capital_id)

	# Wars can exhaust treasuries or be settled through hostage negotiations.
	var current_wars: Array = wars.duplicate()
	for war in current_wars:
		var a: int = int(war.get("a", -1))
		var b: int = int(war.get("b", -1))
		if a < 0 or b < 0 or a >= cities.size() or b >= cities.size():
			continue
		var started_at: float = float(war.get("started_at", game_clock))
		if game_clock - started_at < 42.0:
			continue
		var hostages_held: int = 0
		for person in people:
			if str(person.get("activity", "")) == "hostage" and int(person.get("hostage_captor", -1)) in [a, b]:
				hostages_held += 1
		var peace_chance: float = 0.075
		if hostages_held > 0:
			peace_chance = 0.20
		if float(cities[a].get("treasury", 0.0)) < 12.0 or float(cities[b].get("treasury", 0.0)) < 12.0:
			peace_chance += 0.08
		if randf() < peace_chance:
			_make_peace(a, b)
			_log("WAR EXHAUSTION: %s and %s accepted a ceasefire after prolonged fighting." % [cities[a]["name"], cities[b]["name"]])

	# A long run of mutually beneficial trade can create alliances, while
	# deteriorating relations can dissolve them without player intervention.
	for a in range(cities.size()):
		for b in range(a + 1, cities.size()):
			if _same_faction(a, b) or _are_at_war(a, b):
				continue
			var key: String = _city_relation_key(a, b)
			var relation: float = _city_relation(a, b)
			if _are_allied(a, b):
				if relation < 8.0:
					alliances.erase(key)
					_log("ALLIANCE DISSOLVED: %s and %s no longer trust one another." % [cities[a]["name"], cities[b]["name"]])
			elif relation >= 62.0 and randf() < 0.10:
				alliances[key] = true
				_log("ALLIANCE: %s and %s signed a mutual-aid pact." % [cities[a]["name"], cities[b]["name"]])


func _declare_city_independence(city_id: int, former_capital_id: int) -> void:
	if city_id < 0 or city_id >= cities.size() or former_capital_id < 0 or former_capital_id >= cities.size():
		return
	if bool(cities[city_id].get("is_capital", true)) or not _same_faction(city_id, former_capital_id):
		return
	var city: Dictionary = cities[city_id]
	city["owner"] = city_id
	city["capital_id"] = city_id
	city["is_capital"] = true
	city["loyalty"] = 100.0
	city["autonomy"] = 100.0
	city["stability"] = maxf(25.0, float(city.get("stability", 50.0)) - 8.0)
	cities[city_id] = city
	var key: String = _city_relation_key(city_id, former_capital_id)
	alliances.erase(key)
	city_relations[key] = minf(-55.0, float(city_relations.get(key, -20.0)))
	_log("INDEPENDENCE: %s broke away from %s and established a new capital." % [city["name"], cities[former_capital_id]["name"]])
	if randf() < 0.38:
		_declare_war(city_id, former_capital_id)


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
		var relation_key: String = _city_relation_key(a, b)
		alliances.erase(relation_key)
		wars.append({"a": a, "b": b, "started_at": game_clock, "battles": 0})
		city_relations[relation_key] = -100.0
		_log("WAR: %s vs %s. Trade is embargoed and forces are mobilising." % [cities[a]["name"], cities[b]["name"]])


func _make_peace(a: int, b: int) -> void:
	var remaining: Array = []
	for war in wars:
		if not ((int(war["a"]) == a and int(war["b"]) == b) or (int(war["a"]) == b and int(war["b"]) == a)):
			remaining.append(war)
	wars = remaining
	var relation_key: String = _city_relation_key(a, b)
	city_relations[relation_key] = maxf(-25.0, float(city_relations.get(relation_key, -25.0)))
	alliances.erase(relation_key)
	for person_index in range(people.size()):
		var person: Dictionary = people[person_index]
		if str(person.get("activity", "")) != "hostage":
			continue
		var captor: int = int(person.get("hostage_captor", -1))
		var home_city: int = int(person.get("hostage_home_city", person.get("city_id", -1)))
		if captor in [a, b] and home_city in [a, b]:
			person["activity"] = "wandering"
			person["hostage_timer"] = 0.0
			person["hostage_captor"] = -1
			person["walk_timer"] = 0.0
			people[person_index] = person
	_log("A ceasefire was declared between %s and %s. Remaining hostages were released and trade may resume." % [cities[a]["name"], cities[b]["name"]])


func _launch_army(source_id: int, target_id: int, automatic: bool) -> void:
	if source_id == target_id or source_id < 0 or target_id < 0 or source_id >= cities.size() or target_id >= cities.size():
		return
	if _same_faction(source_id, target_id):
		_log("Those cities already belong to the same faction.")
		return
	_declare_war(source_id, target_id)
	var population: int = _city_population(source_id)
	var strength: int = clampi(1 + int(population / 4), 1, 5)
	if automatic:
		strength = clampi(strength, 1, 3)
	else:
		_log("%s is marching on %s with %d infantry units." % [cities[source_id]["name"], cities[target_id]["name"], strength])

	# Armies evolve with the world era. Infantry remains the backbone; tanks,
	# aircraft and helicopters are separate visible units with their own speed,
	# durability and attack power, rather than decorative upgrades to soldiers.
	var unit_types: Array[String] = []
	for unit_index in range(strength):
		unit_types.append("infantry")
	var year: int = _world_year()
	if year >= 1916:
		unit_types.append("tank")
		if year >= 1940 and strength >= 3:
			unit_types.append("tank")
	if year >= 1850 and strength >= 2:
		unit_types.append("artillery")
	var source_has_airfield: bool = is_instance_valid(cities[source_id].get("airport"))
	var target_has_airfield: bool = is_instance_valid(cities[target_id].get("airport"))
	if year >= 1945 and source_has_airfield and target_has_airfield:
		unit_types.append("aircraft")
	if year >= 1970 and source_has_airfield and target_has_airfield:
		unit_types.append("helicopter")
	if year >= 2000 and strength >= 4:
		unit_types.append("apc")

	var source_position: Vector3 = cities[source_id]["pos"]
	var total_units: int = unit_types.size()
	for unit_index in range(total_units):
		var angle: float = float(unit_index) * TAU / float(maxi(1, total_units))
		var spawn_position: Vector3 = _surface_position(source_position.x + cos(angle) * (2.3 + float(unit_index % 2) * 0.8), source_position.z + sin(angle) * (2.3 + float(unit_index % 2) * 0.8))
		var unit_type: String = unit_types[unit_index]
		var unit_node: Node3D = _create_military_unit_node(unit_type, cities[source_id]["color"])
		add_child(unit_node)
		if unit_type == "aircraft" or unit_type == "helicopter":
			spawn_position.y += 8.0 if unit_type == "aircraft" else 4.5
		unit_node.position = spawn_position
		armies.append({
			"node": unit_node,
			"pos": spawn_position,
			"source": source_id,
			"target": target_id,
			"unit_type": unit_type,
			"hp": _military_unit_health(unit_type),
			"attack_power": _military_unit_attack(unit_type),
			"attack_range": _military_unit_range(unit_type),
			"attack_timer": randf_range(0.0, 2.0),
			"alive": true
		})
	if not automatic:
		_log("%s deploys %d units including %s toward %s." % [cities[source_id]["name"], total_units, _military_unit_roster(unit_types), cities[target_id]["name"]])
		if year < 1916:
			_log("This era's armies use infantry only. Tanks unlock in 1916, aircraft in 1945 and attack helicopters in 1970.")


func _military_unit_roster(unit_types: Array[String]) -> String:
	var counts: Dictionary = {}
	for unit_type in unit_types:
		counts[unit_type] = int(counts.get(unit_type, 0)) + 1
	var labels: Array[String] = []
	for unit_type in ["infantry", "tank", "artillery", "apc", "aircraft", "helicopter"]:
		if int(counts.get(unit_type, 0)) > 0:
			labels.append("%d %s" % [int(counts[unit_type]), unit_type])
	return ", ".join(labels)


func _military_unit_health(unit_type: String) -> float:
	match unit_type:
		"tank":
			return 5.0
		"artillery":
			return 3.2
		"apc":
			return 3.5
		"aircraft":
			return 2.8
		"helicopter":
			return 3.2
		_:
			return 1.0


func _military_unit_attack(unit_type: String) -> float:
	match unit_type:
		"tank":
			return 3.0
		"artillery":
			return 2.7
		"apc":
			return 1.5
		"aircraft":
			return 3.5
		"helicopter":
			return 2.8
		_:
			return 1.0


func _military_unit_range(unit_type: String) -> float:
	match unit_type:
		"tank":
			return 5.5
		"artillery":
			return 15.0
		"apc":
			return 3.0
		"aircraft":
			return 10.0
		"helicopter":
			return 7.0
		_:
			return 1.5


func _create_military_unit_node(unit_type: String, faction_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Military_" + unit_type.capitalize()
	var uniform_color: Color = faction_color.darkened(0.14)
	match unit_type:
		"tank":
			_add_mesh(root, _cached_box_mesh(Vector3(1.65, 0.52, 2.25)), _material(Color(0.28, 0.34, 0.25)), Vector3(0.0, 0.62, 0.0))
			_add_mesh(root, _cached_box_mesh(Vector3(0.92, 0.36, 0.95)), _material(Color(0.34, 0.39, 0.29)), Vector3(0.0, 1.02, -0.12))
			_add_mesh(root, _cached_box_mesh(Vector3(0.16, 0.16, 1.28)), _material(Color(0.20, 0.23, 0.19)), Vector3(0.0, 1.07, -0.88))
			for side in [-1.0, 1.0]:
				_add_mesh(root, _cached_box_mesh(Vector3(0.28, 0.42, 2.0)), _material(Color(0.16, 0.18, 0.16)), Vector3(side * 0.88, 0.45, 0.0))
		"apc":
			_add_mesh(root, _cached_box_mesh(Vector3(1.2, 0.72, 2.0)), _material(Color(0.34, 0.39, 0.29)), Vector3(0.0, 0.58, 0.0))
			_add_mesh(root, _cached_box_mesh(Vector3(0.52, 0.25, 0.58)), _material(Color(0.23, 0.27, 0.22)), Vector3(0.0, 1.04, -0.15))
			for side in [-1.0, 1.0]:
				for axle in [-0.65, 0.0, 0.65]:
					_add_mesh(root, _cached_box_mesh(Vector3(0.22, 0.30, 0.30)), _material(Color(0.12, 0.13, 0.12)), Vector3(side * 0.66, 0.30, axle))
		"artillery":
			_add_mesh(root, _cached_box_mesh(Vector3(1.65, 0.48, 2.0)), _material(Color(0.34, 0.37, 0.28)), Vector3(0.0, 0.45, 0.0))
			for side in [-1.0, 1.0]:
				_add_mesh(root, _cached_box_mesh(Vector3(0.24, 0.38, 2.0)), _material(Color(0.15, 0.17, 0.15)), Vector3(side * 0.89, 0.36, 0.0))
			_add_mesh(root, _cached_box_mesh(Vector3(0.55, 0.28, 0.65)), _material(Color(0.42, 0.43, 0.34)), Vector3(0.0, 0.78, -0.05))
			_add_mesh(root, _cached_box_mesh(Vector3(0.14, 0.16, 2.3)), _material(Color(0.22, 0.24, 0.21)), Vector3(0.0, 0.90, -1.15))
		"aircraft":
			_add_mesh(root, _cached_box_mesh(Vector3(0.32, 0.28, 2.1)), _material(Color(0.48, 0.51, 0.48)), Vector3(0.0, 0.0, 0.0))
			_add_mesh(root, _cached_box_mesh(Vector3(2.65, 0.12, 0.62)), _material(Color(0.40, 0.44, 0.41)), Vector3(0.0, -0.04, -0.12))
			_add_mesh(root, _cached_box_mesh(Vector3(0.92, 0.10, 0.38)), _material(Color(0.38, 0.42, 0.39)), Vector3(0.0, 0.12, 0.77))
		"helicopter":
			_add_mesh(root, _cached_box_mesh(Vector3(0.72, 0.48, 1.38)), _material(Color(0.31, 0.37, 0.27)), Vector3(0.0, 0.0, 0.0))
			_add_mesh(root, _cached_box_mesh(Vector3(0.12, 0.12, 1.25)), _material(Color(0.27, 0.31, 0.24)), Vector3(0.0, -0.04, -1.02))
			_add_mesh(root, _cached_box_mesh(Vector3(2.35, 0.06, 0.12)), _material(Color(0.20, 0.23, 0.19)), Vector3(0.0, 0.38, 0.0))
			_add_mesh(root, _cached_box_mesh(Vector3(0.42, 0.06, 0.08)), _material(Color(0.20, 0.23, 0.19)), Vector3(0.0, 0.38, -1.56))
		_:
			_add_mesh(root, _cached_box_mesh(Vector3(0.42, 0.78, 0.32)), _material(uniform_color), Vector3(0.0, 0.60, 0.0))
			var helmet := SphereMesh.new()
			helmet.radius = 0.23
			helmet.height = 0.38
			_add_mesh(root, helmet, _material(Color(0.26, 0.28, 0.27)), Vector3(0.0, 1.14, 0.0))
	return root

func _spawn_defenders(defending_city_id: int, aggressor_city_id: int) -> void:
	if defending_city_id < 0 or aggressor_city_id < 0 or defending_city_id >= cities.size() or aggressor_city_id >= cities.size():
		return
	# A defensive force now reflects the era and the specialist bases that the
	# city has actually built, instead of every city spawning identical soldiers.
	var year: int = _world_year()
	var population: int = _city_population(defending_city_id)
	var unit_types: Array[String] = []
	var infantry_count: int = clampi(1 + int(population / 10), 1, 4)
	for index in range(infantry_count):
		unit_types.append("infantry")
	if year >= 1850 and population >= 18:
		unit_types.append("artillery")
	if year >= 1916 and population >= 14:
		unit_types.append("tank")
	if year >= 2000 and population >= 28:
		unit_types.append("apc")
	var city: Dictionary = cities[defending_city_id]
	var has_airbase: bool = is_instance_valid(city.get("airport"))
	if year >= 1945 and has_airbase and is_instance_valid(cities[aggressor_city_id].get("airport")):
		unit_types.append("aircraft")
	if year >= 1970 and has_airbase and is_instance_valid(cities[aggressor_city_id].get("airport")):
		unit_types.append("helicopter")
	var city_position: Vector3 = city["pos"]
	var total_units: int = unit_types.size()
	for index in range(total_units):
		var unit_type: String = unit_types[index]
		var angle: float = float(index) * TAU / float(maxi(1, total_units))
		var radius: float = 3.0 + float(index % 2) * 1.4
		var spawn: Vector3 = _surface_position(city_position.x + cos(angle) * radius, city_position.z + sin(angle) * radius)
		var soldier: Node3D = _create_military_unit_node(unit_type, city["color"])
		add_child(soldier)
		if unit_type == "aircraft":
			spawn.y += 8.0
		elif unit_type == "helicopter":
			spawn.y += 4.5
		soldier.position = spawn
		armies.append({
			"node": soldier, "pos": spawn, "source": defending_city_id, "target": aggressor_city_id,
			"attack_timer": randf_range(0.0, 0.8), "idle_timer": 0.0, "home_city": defending_city_id,
			"unit_type": unit_type, "hp": _military_unit_health(unit_type),
			"attack_power": _military_unit_attack(unit_type), "attack_range": _military_unit_range(unit_type),
			"is_defender": true, "alive": true
		})
	_log("%s mobilised %d defenders: %s." % [city["name"], total_units, _military_unit_roster(unit_types)])


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
		var unit_type: String = str(army.get("unit_type", "infantry"))
		var distance: float = Vector2(position.x - destination.x, position.z - destination.z).length()
		var attack_range: float = float(army.get("attack_range", _military_unit_range(unit_type)))
		var move_speed: float = 2.8
		match unit_type:
			"tank":
				move_speed = 3.5
			"artillery":
				move_speed = 1.8
			"apc":
				move_speed = 4.0
			"aircraft":
				move_speed = 9.0
			"helicopter":
				move_speed = 5.5
		var in_range: bool = distance <= attack_range
		if not in_range:
			var direction := Vector3(destination.x - position.x, 0.0, destination.z - position.z).normalized()
			position.x += direction.x * delta * move_speed
			position.z += direction.z * delta * move_speed
			if unit_type == "aircraft":
				position.y = _height_at(position.x, position.z) + 8.0
			elif unit_type == "helicopter":
				position.y = _height_at(position.x, position.z) + 4.5
			else:
				position.y = _height_at(position.x, position.z)
			army["attack_timer"] = float(army["attack_timer"]) + delta
		else:
			army["attack_timer"] = float(army["attack_timer"]) + delta
			var attack_interval: float = 3.2
			if unit_type == "tank" or unit_type == "aircraft":
				attack_interval = 2.0
			elif unit_type == "helicopter":
				attack_interval = 1.7
			elif unit_type == "apc":
				attack_interval = 2.5
			elif unit_type == "artillery":
				attack_interval = 4.2
			if float(army["attack_timer"]) >= attack_interval:
				army["attack_timer"] = 0.0
				var damage: float = float(army.get("attack_power", 1.0))
				_damage_city(target_id, maxi(1, int(ceil(damage))), "army")
				# Ground forces can seize civilians as bargaining chips once they
				# reach city streets. Captives remain visible beside their escort.
				if unit_type in ["infantry", "tank", "apc"] and randf() < 0.35:
					_capture_city_hostages(target_id, source_id, 1)
				# Artillery shells and occasional airstrikes damage actual roadside
				# infrastructure and trigger the existing building-collapse system.
				var bombard: bool = unit_type == "artillery"
				if unit_type in ["aircraft", "helicopter"] and randf() < 0.22:
					bombard = true
				if bombard:
					var city_houses: Array = cities[target_id]["houses"]
					var bombard_target: Node3D = null
					for house in city_houses:
						if is_instance_valid(house) and not bool(house.get_meta("is_collapsing", false)):
							bombard_target = house
							break
					var impact_position: Vector3 = bombard_target.global_position if is_instance_valid(bombard_target) else cities[target_id]["pos"]
					var impact_radius: float = 4.8 if unit_type == "artillery" else 7.0
					_spawn_god_effect(impact_position, Color(1.0, 0.30, 0.08), 2.6 if unit_type == "artillery" else 3.6, 0.8, "impact")
					_damage_roads_at_position(impact_position, impact_radius, false)
					if is_instance_valid(bombard_target):
						_collapse_specific_building(target_id, bombard_target, true, false, 0, 0.62)
					_queue_city_roads_rebuild(target_id)
					if unit_type == "artillery":
						_log("ARTILLERY BOMBARDMENT: %s batteries are shelling roads and buildings in %s." % [cities[source_id]["name"], cities[target_id]["name"]])
					else:
						_log("AIRSTRIKE: %s aircraft attacked infrastructure in %s." % [cities[source_id]["name"], cities[target_id]["name"]])
				if _city_population(target_id) <= 0:
					_capture_city(target_id, source_id)
				# Combat losses are less frequent for armoured units; aircraft can
				# still be lost over a defended target.
				var loss_chance: float = 0.10
				if unit_type == "tank":
					loss_chance = 0.035
				elif unit_type == "apc":
					loss_chance = 0.055
				elif unit_type == "aircraft":
					loss_chance = 0.12
				elif unit_type == "helicopter":
					loss_chance = 0.09
				if randf() < loss_chance:
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
	var defender_type: String = str(defender.get("unit_type", "infantry"))
	var defender_range: float = float(defender.get("attack_range", _military_unit_range(defender_type)))
	var threat_index: int = -1
	var threat_distance_squared: float = 58.0 * 58.0
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
		var threat: Dictionary = armies[threat_index]
		var threat_position: Vector3 = threat["pos"]
		var distance: float = Vector2(position.x - threat_position.x, position.z - threat_position.z).length()
		if distance > defender_range:
			var direction := Vector3(threat_position.x - position.x, 0.0, threat_position.z - position.z).normalized()
			var move_speed: float = 3.6
			if defender_type == "artillery":
				move_speed = 1.8
			elif defender_type == "tank":
				move_speed = 3.5
			elif defender_type == "aircraft":
				move_speed = 9.0
			elif defender_type == "helicopter":
				move_speed = 5.5
			elif defender_type == "apc":
				move_speed = 4.0
			position.x += direction.x * delta * move_speed
			position.z += direction.z * delta * move_speed
			position.y = _height_at(position.x, position.z)
			if defender_type == "aircraft":
				position.y += 8.0
			elif defender_type == "helicopter":
				position.y += 4.5
		else:
			defender["attack_timer"] = float(defender.get("attack_timer", 0.0)) + delta
			var attack_interval: float = 1.25
			if defender_type == "artillery":
				attack_interval = 3.8
			elif defender_type == "tank" or defender_type == "aircraft":
				attack_interval = 2.1
			elif defender_type == "helicopter":
				attack_interval = 1.8
			elif defender_type == "apc":
				attack_interval = 2.5
			if float(defender.get("attack_timer", 0.0)) >= attack_interval:
				defender["attack_timer"] = 0.0
				threat["hp"] = float(threat.get("hp", 1.0)) - float(defender.get("attack_power", 1.0))
				if float(threat["hp"]) <= 0.0:
					threat["alive"] = false
					if is_instance_valid(threat.get("node")):
						threat["node"].queue_free()
					_log("CITY DEFENCE: %s %s destroyed an invading %s." % [cities[home_city]["name"], defender_type, str(threat.get("unit_type", "unit"))])
				armies[threat_index] = threat
				if randf() < (0.05 if defender_type in ["tank", "apc", "aircraft", "helicopter"] else 0.16):
					defender["hp"] = float(defender.get("hp", 1.0)) - 1.0
					if float(defender["hp"]) <= 0.0:
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
	blast_mesh.radius = 1.7
	blast_mesh.height = 3.4
	blast_mesh.radial_segments = 16
	blast.mesh = blast_mesh
	var blast_material := StandardMaterial3D.new()
	blast_material.albedo_color = Color(1.0, 0.30, 0.025, 0.82)
	blast_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blast_material.emission_enabled = true
	blast_material.emission = Color(1.0, 0.12, 0.005)
	blast_material.emission_energy_multiplier = 3.4
	blast.material_override = blast_material
	blast.position = position + Vector3(0.0, 1.0, 0.0)
	add_child(blast)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.31, 0.08)
	light.light_energy = 9.0
	light.omni_range = 34.0
	blast.add_child(light)
	explosions.append({"node": blast, "material": blast_material, "light": light, "t": 0.0, "duration": 1.5, "max_scale": 7.6, "light_energy": 9.0})
	_spawn_ground_shockwave(position)
	_spawn_missile_mushroom_cloud(position)

	var blast_radius: float = 14.0
	_destroy_cars_in_radius(position, blast_radius)
	var blast_radius_squared: float = blast_radius * blast_radius
	var road_affected_city_ids: Array[int] = _damage_roads_at_position(position, blast_radius * 0.92, false)
	var damaged_city_names: Array[String] = []
	for city_id in range(cities.size()):
		var city: Dictionary = cities[city_id]
		var city_position: Vector3 = city["pos"]
		var city_dx: float = city_position.x - position.x
		var city_dz: float = city_position.z - position.z
		var city_distance_squared: float = city_dx * city_dx + city_dz * city_dz
		var houses: Array = city["houses"]
		var targets: Array[Node3D] = []
		for house in houses:
			if not is_instance_valid(house):
				continue
			var offset := Vector2(house.global_position.x - position.x, house.global_position.z - position.z)
			if offset.length_squared() <= blast_radius_squared:
				targets.append(house)
		var city_changed: bool = false
		for house in targets:
			var distance: float = Vector2(house.global_position.x - position.x, house.global_position.z - position.z).length()
			var impact_strength: float = clampf(0.42 - distance / blast_radius * 0.18, 0.22, 0.42)
			if _collapse_specific_building(city_id, house, true, false, 0, impact_strength):
				city_changed = true
		if city_changed or road_affected_city_ids.has(city_id):
			_rebuild_city_roads(city_id)
		if city_changed:
			_schedule_city_territory_refresh()
		var population_losses: int = 0
		for person_index in range(people.size() - 1, -1, -1):
			var person: Dictionary = people[person_index]
			var activity: String = str(person.get("activity", ""))
			if activity == "riding":
				continue
			var person_position: Vector3 = person["pos"]
			var dx: float = person_position.x - position.x
			var dz: float = person_position.z - position.z
			if dx * dx + dz * dz > blast_radius_squared:
				continue
			if activity == "indoors":
				var indoor_house: Variant = person.get("indoor_house", null)
				if indoor_house is Node3D and is_instance_valid(indoor_house) and indoor_house.global_position.distance_to(position) > 2.0:
					continue
			if is_instance_valid(person.get("node")):
				person["node"].queue_free()
			people.remove_at(person_index)
			population_losses += 1
		if population_losses > 0 or city_changed:
			city["stability"] = maxf(0.0, float(city.get("stability", 72.0)) - 22.0)
			city["security"] = maxf(0.0, float(city.get("security", 44.0)) - 28.0)
			city["wealth"] = maxf(0.0, float(city.get("wealth", 12.0)) - 16.0)
			cities[city_id] = city
			_refresh_city_development(city_id)
			damaged_city_names.append(str(city["name"]))
		elif city_distance_squared <= blast_radius_squared and target_id == city_id:
			city["stability"] = maxf(0.0, float(city.get("stability", 72.0)) - 12.0)
			cities[city_id] = city
			damaged_city_names.append(str(city["name"]))
	for resource in resources:
		var resource_pos: Vector3 = resource["pos"]
		var dx: float = resource_pos.x - position.x
		var dz: float = resource_pos.z - position.z
		if dx * dx + dz * dz <= blast_radius_squared:
			resource["amount"] = 0
			resource["alive"] = false
			if is_instance_valid(resource["node"]):
				resource["node"].visible = false
	if damaged_city_names.is_empty():
		_log("MISSILE DETONATION: Massive blast on open ground.")
	else:
		_log("MISSILE DETONATION: Strategic strike devastates %s." % ", ".join(damaged_city_names))


func _spawn_ground_shockwave(position: Vector3) -> void:
	var wave := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 1.0
	disk.bottom_radius = 1.0
	disk.height = 0.10
	disk.radial_segments = 32
	wave.mesh = disk
	var wave_material := StandardMaterial3D.new()
	wave_material.albedo_color = Color(1.0, 0.58, 0.20, 0.66)
	wave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave.material_override = wave_material
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.position = _surface_position(position.x, position.z) + Vector3(0.0, 0.18, 0.0)
	wave.scale = Vector3(0.2, 1.0, 0.2)
	add_child(wave)
	var wave_tween := create_tween()
	wave_tween.set_parallel(true)
	wave_tween.tween_property(wave, "scale", Vector3(16.0, 1.0, 16.0), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wave_tween.tween_property(wave_material, "albedo_color:a", 0.0, 2.0)
	wave_tween.chain().tween_callback(wave.queue_free)


func _spawn_missile_mushroom_cloud(position: Vector3) -> void:
	var cloud := Node3D.new()
	cloud.name = "MissileMushroomCloud"
	cloud.position = _surface_position(position.x, position.z)
	add_child(cloud)
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.8
	stem_mesh.bottom_radius = 1.65
	stem_mesh.height = 13.0
	stem_mesh.radial_segments = 14
	var stem_material := StandardMaterial3D.new()
	stem_material.albedo_color = Color(0.27, 0.27, 0.26, 0.76)
	stem_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stem_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stem_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var stem := MeshInstance3D.new()
	stem.mesh = stem_mesh
	stem.material_override = stem_material
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stem.position = Vector3(0.0, 6.5, 0.0)
	stem.scale = Vector3(0.35, 0.6, 0.35)
	cloud.add_child(stem)
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 2.1
	cap_mesh.height = 4.2
	cap_mesh.radial_segments = 14
	cap_mesh.rings = 8
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color(0.36, 0.35, 0.33, 0.78)
	cap_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cap_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var cap := MeshInstance3D.new()
	cap.mesh = cap_mesh
	cap.material_override = cap_material
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.position = Vector3(0.0, 12.0, 0.0)
	cap.scale = Vector3(0.3, 0.24, 0.3)
	cloud.add_child(cap)
	for puff_index in range(12):
		var angle: float = TAU * float(puff_index) / 12.0
		var puff := MeshInstance3D.new()
		var puff_mesh := SphereMesh.new()
		puff_mesh.radius = 1.3
		puff_mesh.height = 2.6
		puff_mesh.radial_segments = 8
		puff.mesh = puff_mesh
		var puff_material := StandardMaterial3D.new()
		puff_material.albedo_color = Color(0.34, 0.34, 0.32, 0.60)
		puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		puff.material_override = puff_material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3(cos(angle) * 1.4, 11.5 + sin(angle * 2.0) * 0.35, sin(angle) * 1.4)
		puff.scale = Vector3(0.28, 0.24, 0.28)
		cloud.add_child(puff)
		var puff_tween := create_tween()
		puff_tween.set_parallel(true)
		puff_tween.tween_property(puff, "scale", Vector3.ONE * randf_range(1.05, 1.8), 4.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		puff_tween.tween_property(puff_material, "albedo_color:a", 0.0, 7.2)
	var cloud_tween := create_tween()
	cloud_tween.set_parallel(true)
	cloud_tween.tween_property(cloud, "position", cloud.position + Vector3(0.0, 14.0, 0.0), 7.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cloud_tween.tween_property(stem, "scale", Vector3(1.2, 1.2, 1.2), 4.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cloud_tween.tween_property(cap, "scale", Vector3(4.9, 2.3, 4.9), 4.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cloud_tween.tween_property(stem_material, "albedo_color:a", 0.0, 7.8)
	cloud_tween.tween_property(cap_material, "albedo_color:a", 0.0, 7.8)
	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(8.0)
	cleanup_tween.tween_callback(cloud.queue_free)


func _update_explosions(delta: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var explosion: Dictionary = explosions[i]
		explosion["t"] = float(explosion["t"]) + delta
		var t: float = clamp(float(explosion["t"]) / float(explosion["duration"]), 0.0, 1.0)
		if is_instance_valid(explosion["node"]):
			explosion["node"].scale = Vector3.ONE * lerpf(0.18, float(explosion.get("max_scale", 7.6)), t)
		var mat: StandardMaterial3D = explosion["material"]
		var c: Color = mat.albedo_color
		c.a = 0.82 * (1.0 - t)
		mat.albedo_color = c
		if is_instance_valid(explosion["light"]):
			explosion["light"].light_energy = float(explosion.get("light_energy", 9.0)) * (1.0 - t)
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


func _collapse_specific_building(city_id: int, house: Node3D, allow_chain: bool = true, rebuild_roads: bool = true, chain_depth: int = 0, impact_strength: float = 0.22) -> bool:
	if city_id < 0 or city_id >= cities.size() or not is_instance_valid(house):
		return false
	var city: Dictionary = cities[city_id]
	var houses: Array = city["houses"]
	var house_index: int = houses.find(house)
	if house_index < 0 or bool(house.get_meta("is_collapsing", false)):
		return false
	var impact_position: Vector3 = house.global_position
	var local_position: Vector3 = house.position
	var building_height: float = float(house.get_meta("building_height", 2.0 * house.scale.y))
	var tall_building: bool = building_height >= 5.0 or bool(house.get_meta("is_skyscraper", false))
	var fall_angle: float = randf() * TAU
	var fall_direction := Vector2(cos(fall_angle), sin(fall_angle))
	var fall_reach: float = clampf(building_height * 0.42, 1.8, 12.0)
	var fall_half_width: float = clampf(building_height * 0.11 + 1.3, 1.7, 4.5)
	house.set_meta("is_collapsing", true)
	if bool(house.get_meta("is_construction_site", false)):
		_cancel_construction_site(house)
	_recover_citizens_from_collapsing_house(house)
	var contact_delay: float = lerpf(1.55, 0.65, clampf(impact_strength, 0.08, 1.0)) if tall_building else lerpf(1.15, 0.45, clampf(impact_strength, 0.08, 1.0))
	var damage_tween := create_tween()
	damage_tween.tween_interval(contact_delay)
	damage_tween.tween_callback(_kill_people_in_fall_corridor.bind(impact_position, fall_direction, fall_reach, fall_half_width, house))
	damage_tween.tween_callback(_destroy_cars_in_fall_corridor.bind(impact_position, fall_direction, fall_reach, fall_half_width + 0.8))
	if allow_chain and chain_depth < 3:
		damage_tween.tween_callback(_resolve_falling_building_collisions.bind(city_id, house, impact_position, fall_direction, building_height, fall_reach, fall_half_width, chain_depth, impact_strength))
	_spawn_building_collapse_smoke(impact_position + Vector3(0.0, minf(building_height * 0.3, 7.0), 0.0), building_height, tall_building)
	if tall_building or randf() < 0.24:
		var road_impact_position: Vector3 = impact_position + Vector3(fall_direction.x * fall_reach, 0.0, fall_direction.y * fall_reach)
		_damage_city_roads(city_id, road_impact_position, clampf(fall_half_width + 1.1, 2.8, 5.6), false)
	_animate_building_fall(house, tall_building, city["color"], fall_direction, impact_strength)
	houses.remove_at(house_index)
	city["houses"] = houses
	city["destroyed_building_debt"] = int(city.get("destroyed_building_debt", 0)) + 1
	cities[city_id] = city
	last_detail_signature = ""


	if rebuild_roads and city_id < cities.size():
		_queue_city_roads_rebuild(city_id)
		_schedule_city_territory_refresh()
	return true


func _resolve_falling_building_collisions(source_city_id: int, source_house: Node3D, source_position: Vector3, fall_direction: Vector2, source_height: float, original_fall_reach: float, source_half_width: float, chain_depth: int, impact_strength: float) -> void:
	if chain_depth >= 3 or not is_instance_valid(source_house):
		return
	if source_city_id < 0 or source_city_id >= cities.size():
		return
	var direction: Vector2 = fall_direction.normalized()
	if direction.length_squared() < 0.01:
		return
	var source_width: float = maxf(1.0, float(source_house.get_meta("building_width", 3.0)) * source_house.scale.x)
	var collision_reach: float = maxf(original_fall_reach, clampf(source_height * 0.78, 2.5, 18.0))
	var candidates: Array[Dictionary] = []
	for target_city_id in range(cities.size()):
		var target_city: Dictionary = cities[target_city_id]
		if bool(target_city.get("ruined", false)):
			continue
		for target_house in target_city["houses"]:
			if not is_instance_valid(target_house) or target_house == source_house or bool(target_house.get_meta("is_collapsing", false)) or bool(target_house.get_meta("is_targeted_by_collapse", false)):
				continue
			var target_position: Vector3 = target_house.global_position
			var offset := Vector2(target_position.x - source_position.x, target_position.z - source_position.z)
			var forward: float = offset.dot(direction)
			if forward <= 0.55:
				continue
			var target_width: float = maxf(float(target_house.get_meta("building_width", 2.8)), float(target_house.get_meta("building_depth", 2.6))) * maxf(target_house.scale.x, target_house.scale.z)
			var target_radius: float = maxf(0.8, target_width * 0.48)
			var max_forward: float = minf(collision_reach + target_radius, source_height * 0.96 + target_radius)
			if forward > max_forward:
				continue
			var lateral: float = absf(offset.x * direction.y - offset.y * direction.x)
			var lateral_limit: float = source_width * 0.46 + target_radius + 0.35
			if lateral > lateral_limit:
				continue
			var target_height: float = float(target_house.get_meta("building_height", 2.5)) * target_house.scale.y
			if target_height > source_height * 1.35:
				continue
			var score: float = forward + lateral * 1.8 - minf(target_height, source_height) * 0.025
			candidates.append({
				"city_id": target_city_id,
				"house": target_house,
				"score": score,
				"distance": offset.length(),
				"position": target_position
			})
	candidates.sort_custom(_fall_collision_candidate_nearer)
	var max_hits: int = 2 if source_height >= 6.0 else 1
	var hit_count: int = 0
	var source_color: Color = cities[source_city_id]["color"]
	for candidate in candidates:
		if hit_count >= max_hits:
			break
		var target_house: Node3D = candidate["house"] as Node3D
		var target_city_id: int = int(candidate["city_id"])
		if not is_instance_valid(target_house) or target_city_id < 0 or target_city_id >= cities.size():
			continue
		if bool(target_house.get_meta("is_collapsing", false)) or not (cities[target_city_id]["houses"] as Array).has(target_house):
			continue
		var distance: float = float(candidate["distance"])
		var transferred_energy: float = clampf(impact_strength * (0.95 - distance / maxf(1.0, collision_reach) * 0.38), 0.22, 0.88)
		target_house.set_meta("is_targeted_by_collapse", true)
		_log("COLLISION: A falling building in %s struck a structure in %s." % [cities[source_city_id]["name"], cities[target_city_id]["name"]])
		_spawn_building_collapse_smoke(target_house.global_position + Vector3(0.0, 0.8, 0.0), float(target_house.get_meta("building_height", 2.0)), false, true)
		_throw_debris_at_building(target_city_id, source_position, target_house, source_color, chain_depth + 1, transferred_energy, source_height)
		hit_count += 1


func _fall_collision_candidate_nearer(a: Dictionary, b: Dictionary) -> bool:
	return float(a["score"]) < float(b["score"])


func _recover_citizens_from_collapsing_house(house: Node3D) -> void:
	if not is_instance_valid(house):
		return
	var house_position: Vector3 = house.global_position
	for person_index in range(people.size()):
		var person: Dictionary = people[person_index]
		if not bool(person.get("alive", true)):
			continue
		var activity: String = str(person.get("activity", "wandering"))
		var indoor_house: Variant = person.get("indoor_house", null)
		var is_indoor_resident: bool = indoor_house == house and (activity == "indoors" or activity == "entering")
		var target: Vector3 = person.get("target", person.get("pos", Vector3.ZERO))
		var near_door: bool = activity == "entering" and Vector2(target.x - house_position.x, target.z - house_position.z).length() <= 2.8
		if not is_indoor_resident and not near_door:
			continue
		var position: Vector3 = _surface_position(float(person["pos"].x), float(person["pos"].z))
		var city_id: int = int(person.get("city_id", -1))
		person["pos"] = position
		person["target"] = _choose_citizen_street_target(city_id, position, 10.0)
		person["activity"] = "wandering"
		person["activity_timer"] = 0.0
		person["walk_timer"] = 0.0
		person["indoor_house"] = null
		person["stuck_timer"] = 0.0
		people[person_index] = person
		var person_node: Node3D = person.get("node") as Node3D
		if is_instance_valid(person_node):
			person_node.position = position
			person_node.visible = true


func _throw_debris_at_building(city_id: int, source_position: Vector3, target_house: Node3D, building_color: Color, chain_depth: int, impact_strength: float, source_height: float) -> void:
	if not is_instance_valid(target_house):
		return
	var direction := Vector2(target_house.global_position.x - source_position.x, target_house.global_position.z - source_position.z).normalized()
	var debris := MeshInstance3D.new()
	debris.name = "ChainCollapseDebris"
	debris.mesh = _cached_box_mesh(Vector3(0.72, 0.58, 0.78))
	debris.material_override = _material(building_color.darkened(0.40))
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(debris)
	var start_position: Vector3 = source_position + Vector3(direction.x * 1.2, maxf(1.8, source_height * 0.62), direction.y * 1.2)
	var target_height: float = float(target_house.get_meta("building_height", 2.0 * target_house.scale.y))
	var finish_position: Vector3 = target_house.global_position + Vector3(0.0, maxf(0.7, target_height * 0.45), 0.0)
	debris.global_position = start_position
	var distance: float = start_position.distance_to(finish_position)
	var flight_time: float = clampf(distance / lerpf(19.0, 10.0, 1.0 - impact_strength), 0.42, 1.65)
	var travel_tween := create_tween()
	travel_tween.tween_interval(0.24)
	travel_tween.tween_property(debris, "global_position", finish_position, flight_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel_tween.tween_callback(_on_building_debris_impact.bind(city_id, target_house, building_color, chain_depth, impact_strength))
	travel_tween.tween_callback(debris.queue_free)


func _on_building_debris_impact(city_id: int, target_house: Node3D, building_color: Color, chain_depth: int, impact_strength: float) -> void:
	if not is_instance_valid(target_house):
		return
	target_house.set_meta("is_targeted_by_collapse", false)
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	if not (city["houses"] as Array).has(target_house):
		return
	_spawn_building_collapse_smoke(target_house.global_position + Vector3(0.0, 1.0, 0.0), float(target_house.get_meta("building_height", 2.0)), false, true)
	_collapse_specific_building(city_id, target_house, true, true, chain_depth, impact_strength)


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


func _animate_building_fall(house: Node3D, tall_building: bool, building_color: Color, fall_direction: Vector2 = Vector2.ZERO, impact_strength: float = 0.22) -> void:
	if not is_instance_valid(house):
		return
	if fall_direction.length_squared() < 0.01:
		var random_angle: float = randf() * TAU
		fall_direction = Vector2(cos(random_angle), sin(random_angle))
	fall_direction = fall_direction.normalized()
	var strength: float = clampf(impact_strength, 0.08, 1.0)
	# The first unsupported structure slowly loses stability. A stronger debris
	# impact transfers more energy, so the struck structure falls faster.
	var duration: float = lerpf(4.2, 1.55, strength) if tall_building else lerpf(3.1, 1.15, strength)
	var fall_angle: float = deg_to_rad(randf_range(72.0, 88.0) if tall_building else randf_range(58.0, 78.0))
	var z_fall: float = -fall_direction.x * fall_angle
	var x_fall: float = fall_direction.y * fall_angle
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(house, "rotation:z", house.rotation.z + z_fall, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(house, "rotation:x", house.rotation.x + x_fall, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(house, "scale:y", house.scale.y * 0.93, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish_building_collapse.bind(house, tall_building, building_color, fall_direction))


func _finish_building_collapse(house: Node3D, tall_building: bool, building_color: Color, fall_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(house):
		return
	var building_height: float = float(house.get_meta("building_height", 2.0 * house.scale.y))
	var rubble_reach: float = clampf(building_height * 0.42, 1.8, 12.0)
	var rubble_position: Vector3 = house.global_position + Vector3(fall_direction.x * rubble_reach, 0.0, fall_direction.y * rubble_reach)
	_spawn_persistent_rubble(rubble_position, tall_building, building_color)
	_spawn_building_collapse_smoke(rubble_position + Vector3(0.0, 0.6, 0.0), building_height, tall_building, true)
	house.queue_free()


func _spawn_building_collapse_smoke(center: Vector3, building_height: float, tall_building: bool, impact_burst: bool = false) -> void:
	# Smoke is cosmetic. Keep the silhouette and drift, but avoid hundreds of
	# independent meshes/materials/tweens when a whole district collapses at once.
	var puff_count: int = 8 if tall_building else 5
	if impact_burst:
		puff_count = 3 if tall_building else 2
	puff_count = mini(puff_count, maxi(0, MAX_ACTIVE_BUILDING_SMOKE_PUFFS - active_building_smoke_puffs))
	for puff_index in range(puff_count):
		var puff := MeshInstance3D.new()
		var puff_mesh := SphereMesh.new()
		puff_mesh.radius = randf_range(0.62, 1.05)
		puff_mesh.height = puff_mesh.radius * 2.0
		puff_mesh.radial_segments = 8
		puff_mesh.rings = 4
		puff.mesh = puff_mesh
		var smoke_material := StandardMaterial3D.new()
		smoke_material.albedo_color = Color(randf_range(0.17, 0.29), randf_range(0.18, 0.30), randf_range(0.19, 0.31), randf_range(0.48, 0.70))
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		smoke_material.roughness = 1.0
		puff.material_override = smoke_material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var drift := Vector3(randf_range(-2.2, 2.2), randf_range(0.4, maxf(2.0, building_height * 0.36)), randf_range(-2.2, 2.2))
		puff.global_position = center + Vector3(randf_range(-1.8, 1.8), randf_range(0.0, 1.3), randf_range(-1.8, 1.8))
		var scale_start: float = randf_range(0.4, 0.9)
		puff.scale = Vector3.ONE * scale_start
		add_child(puff)
		active_building_smoke_puffs += 1
		var lifetime: float = randf_range(2.5, 4.2) if tall_building else randf_range(1.8, 3.0)
		if impact_burst:
			lifetime *= 0.75
		var smoke_tween := create_tween()
		smoke_tween.set_parallel(true)
		smoke_tween.tween_property(puff, "global_position", puff.global_position + drift, lifetime).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		smoke_tween.tween_property(puff, "scale", Vector3.ONE * randf_range(2.1, 3.8), lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		smoke_tween.tween_property(smoke_material, "albedo_color:a", 0.0, lifetime)
		smoke_tween.chain().tween_callback(_release_building_smoke_puff.bind(puff))


func _release_building_smoke_puff(puff: Node3D) -> void:
	active_building_smoke_puffs = maxi(0, active_building_smoke_puffs - 1)
	if is_instance_valid(puff):
		puff.queue_free()


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
	rubble.name = "BuildingRubble" if rubble_kind == "building" else ("RoadRubble" if rubble_kind == "road" else "VehicleWreck")
	rubble.position = debris_position
	rubble.set_meta("rubble_id", resolved_id)
	rubble.set_meta("rubble_kind", rubble_kind)
	if rubble_kind == "road":
		for road_city_id in range(cities.size()):
			for road_damage in cities[road_city_id].get("road_damage", []):
				if int(road_damage.get("id", -1)) == resolved_id:
					rubble.set_meta("road_city_id", road_city_id)
					rubble.set_meta("road_damage_id", resolved_id)
					break
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
		piece.material_override = _material(Color(0.20, 0.21, 0.22) if rubble_kind == "vehicle" else (Color(0.15, 0.16, 0.17) if rubble_kind == "road" else Color(0.34, 0.32, 0.29).lerp(building_color, 0.18)))
		var landing_position := Vector3(randf_range(-2.3, 2.3), piece_mesh.size.y * 0.5, randf_range(-2.3, 2.3))
		piece.position = Vector3(randf_range(-0.5, 0.5), randf_range(0.8, 3.0 if tall_building else 1.4), randf_range(-0.5, 0.5))
		piece.rotation = Vector3(randf_range(-0.75, 0.75), randf() * TAU, randf_range(-0.75, 0.75))
		rubble.add_child(piece)
		var fall_tween := create_tween()
		fall_tween.set_parallel(true)
		fall_tween.tween_property(piece, "position", landing_position, randf_range(0.28, 0.82)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(piece, "rotation", Vector3(randf_range(-0.9, 0.9), randf() * TAU, randf_range(-0.9, 0.9)), randf_range(0.25, 0.65)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rubble_nodes.append({"id": resolved_id, "node": rubble, "position": debris_position, "kind": rubble_kind, "reserved": false, "age": 0.0, "decaying": false})
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
	var road_city_to_rebuild: int = -1
	for index in range(rubble_nodes.size() - 1, -1, -1):
		var entry: Dictionary = rubble_nodes[index]
		if int(entry.get("id", -1)) != rubble_id:
			continue
		var node: Node3D = entry.get("node") as Node3D
		if is_instance_valid(node):
			if node.has_meta("road_city_id"):
				road_city_to_rebuild = int(node.get_meta("road_city_id", -1))
				var damage_id: int = int(node.get_meta("road_damage_id", rubble_id))
				if road_city_to_rebuild >= 0 and road_city_to_rebuild < cities.size():
					var city: Dictionary = cities[road_city_to_rebuild]
					var remaining_damage: Array = []
					for damage in city.get("road_damage", []):
						if int(damage.get("id", -1)) != damage_id:
							remaining_damage.append(damage)
					city["road_damage"] = remaining_damage
					cities[road_city_to_rebuild] = city
			node.queue_free()
		rubble_nodes.remove_at(index)
		break
	for record_index in range(rubble_records.size() - 1, -1, -1):
		if int(rubble_records[record_index].get("id", -2)) == rubble_id:
			rubble_records.remove_at(record_index)
			break
	if road_city_to_rebuild >= 0 and road_city_to_rebuild < cities.size():
		_rebuild_city_roads(road_city_to_rebuild)
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


func _power_damage(center: Vector3, radius: float, people_limit: int, resource_chance: float, house_damage: int, refresh_ui: bool = true) -> void:
	var power_damage_started_usec: int = Time.get_ticks_usec()
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
	var road_affected_city_ids: Array[int] = _damage_roads_at_position(center, maxf(2.5, radius * 0.78), false)
	# Rebuild every road mesh touched by the impact, even if the impact is far
	# from the city anchor. The old code gated this inside the city-centre damage
	# radius, leaving edge streets recorded as damaged but still visible intact.
	var road_rebuild_city_ids: Dictionary = {}
	for road_city_id in road_affected_city_ids:
		road_rebuild_city_ids[road_city_id] = true
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
				road_rebuild_city_ids[city_id] = true
		if city_distance_squared <= radius * radius * 2.25:
			cities[city_id]["food"] = max(0.0, float(cities[city_id]["food"]) - float(removed) * 0.25)
	for road_city_id in road_rebuild_city_ids.keys():
		var affected_city_id: int = int(road_city_id)
		if affected_city_id >= 0 and affected_city_id < cities.size():
			_queue_city_roads_rebuild(affected_city_id)
	if refresh_ui:
		_refresh_ui()
	_trace_slow_operation("power-damage", power_damage_started_usec)


func _god_lightning(position: Vector3) -> void:
	_spawn_god_effect(position, Color(0.30, 0.82, 1.0), 2.7, 0.45, "lightning")
	_power_damage(position, 3.0, MAX_PEOPLE, 0.30, 1, false)
	_log("Lightning tears into the ground. Nature has submitted a strongly worded complaint.")
	_refresh_ui()


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
			_power_damage(fire["pos"], float(fire["radius"]), 2, 0.22, 1, false)
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
	var terrain_impacts: Array[Vector3] = []
	var impacts_processed: int = 0
	var impact_batch_started_usec: int = Time.get_ticks_usec()
	for i in range(falling_meteors.size() - 1, -1, -1):
		var meteor: Dictionary = falling_meteors[i]
		meteor["age"] = float(meteor["age"]) + delta
		var progress: float = clampf(float(meteor["age"]) / float(meteor["duration"]), 0.0, 1.0)
		var node: Node3D = meteor["node"]
		var start_position: Vector3 = meteor["start"]
		var target_position: Vector3 = meteor["target"]
		if is_instance_valid(node):
			node.position = start_position.lerp(target_position + Vector3(0.0, 0.8, 0.0), progress)
			node.rotate_y(delta * 5.0)
		if progress >= 1.0 and impacts_processed >= MAX_METEOR_IMPACTS_PER_FRAME:
			# Keep excess impacts queued at the target. Handling a full meteor volley
			# synchronously means several city scans, rubble bursts and collapse
			# animations can all land in one frame. Resolve the remainder next frame.
			falling_meteors[i] = meteor
			continue
		if progress >= 1.0:
			impacts_processed += 1
			if is_instance_valid(node):
				node.queue_free()
			_spawn_god_effect(target_position, Color(1.0, 0.28, 0.035), maxf(4.0, brush_radius * 1.4), 0.75)
			_power_damage(target_position, maxf(4.0, brush_radius * 1.25), MAX_PEOPLE, 1.0, 3, false)
			_sculpt_terrain(target_position, -1.1, false)
			terrain_impacts.append(target_position)
			falling_meteors.remove_at(i)
		else:
			falling_meteors[i] = meteor

	if not terrain_impacts.is_empty():
		# Each crater queues its height edit. The terrain flush merges the crater
		# areas, then meters the mesh rebuild to two chunks per frame.
		_log("Terrain lowered by %d meteor impact(s)." % terrain_impacts.size())
	_trace_slow_operation("meteor-impact-batch", impact_batch_started_usec)


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
	var earthquake_started_usec: int = Time.get_ticks_usec()
	_spawn_god_effect(position, Color(0.77, 0.54, 0.28), max(4.0, brush_radius * 1.4), 0.8)
	_power_damage(position, maxf(4.0, brush_radius * 1.3), MAX_PEOPLE, 0.8, 3, false)
	_sculpt_terrain(position, -0.8)
	_log("Earthquake! The terrain shifts and nearby settlements take damage.")
	_refresh_ui()
	_trace_slow_operation("earthquake-total", earthquake_started_usec)


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
	if people.is_empty():
		return
	var spreader_indices: Array[int] = []
	var expired_indices: Array[int] = []
	var expired_lookup: Dictionary = {}
	for i in range(people.size() - 1, -1, -1):
		var person: Dictionary = people[i]
		if not bool(person.get("infected", false)):
			continue
		person["infection_time"] = float(person["infection_time"]) + delta
		person["spread_timer"] = float(person["spread_timer"]) + delta
		if float(person["spread_timer"]) >= 1.25:
			person["spread_timer"] = 0.0
			spreader_indices.append(i)
		people[i] = person
		if float(person["infection_time"]) >= 12.0:
			if is_instance_valid(person.get("node") as Node3D):
				(person["node"] as Node3D).queue_free()
			expired_indices.append(i)
			expired_lookup[i] = true

	# If no infected citizen is due to spread this frame, don't build a spatial index.
	# Timer/death handling above is all the work needed until the next spread pulse.
	if spreader_indices.is_empty():
		for expired_index in expired_indices:
			people.remove_at(expired_index)
		return

	# People only need to be compared with residents in neighbouring 2.25-unit
	# cells. This turns a crowded plague update from O(infected * population) into
	# a small local-neighbour query while retaining the same infection radius.
	var infection_radius: float = 2.25
	var cell_size: float = infection_radius
	var cells: Dictionary = {}
	for person_index in range(people.size()):
		if expired_lookup.has(person_index):
			continue
		var person_position: Vector3 = people[person_index]["pos"]
		var cell := Vector2i(floori(person_position.x / cell_size), floori(person_position.z / cell_size))
		var bucket: Array = cells.get(cell, [])
		bucket.append(person_index)
		cells[cell] = bucket

	var infection_radius_squared: float = infection_radius * infection_radius
	for spreader_index in spreader_indices:
		# A resident whose infection timer expired this update must not transmit
		# during the same tick merely because their spread timer also elapsed.
		if expired_lookup.has(spreader_index):
			continue
		var infected_position: Vector3 = people[spreader_index]["pos"]
		var source_cell := Vector2i(floori(infected_position.x / cell_size), floori(infected_position.z / cell_size))
		for cell_x_offset in range(-1, 2):
			for cell_z_offset in range(-1, 2):
				var nearby_cell: Vector2i = source_cell + Vector2i(cell_x_offset, cell_z_offset)
				var bucket: Array = cells.get(nearby_cell, [])
				for neighbour_index in bucket:
					if neighbour_index == spreader_index:
						continue
					var neighbour: Dictionary = people[neighbour_index]
					if bool(neighbour.get("infected", false)):
						continue
					var neighbour_position: Vector3 = neighbour["pos"]
					var dx: float = neighbour_position.x - infected_position.x
					var dz: float = neighbour_position.z - infected_position.z
					if dx * dx + dz * dz > infection_radius_squared or randf() >= 0.24:
						continue
					neighbour["infected"] = true
					neighbour["infection_time"] = 0.0
					neighbour["spread_timer"] = randf_range(0.3, 1.0)
					var neighbour_marker: MeshInstance3D = neighbour.get("infection_marker") as MeshInstance3D
					if is_instance_valid(neighbour_marker):
						neighbour_marker.visible = true
					people[neighbour_index] = neighbour

	# Defer removals until all spatial queries are complete, then remove in descending
	# index order so the cell-index references remain valid throughout this update.
	for expired_index in expired_indices:
		people.remove_at(expired_index)


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
			_power_damage(position, 2.8, 2, 0.25, 1, false)
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


func _build_people_lod_proxy() -> void:
	var citizen_mesh := BoxMesh.new()
	citizen_mesh.size = Vector3(0.22, 0.48, 0.22)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = citizen_mesh
	multimesh.instance_count = MAX_PEOPLE
	multimesh.visible_instance_count = 0
	people_lod_proxy = MultiMeshInstance3D.new()
	people_lod_proxy.name = "CitizenDistanceLOD"
	people_lod_proxy.multimesh = multimesh
	var proxy_material := StandardMaterial3D.new()
	proxy_material.vertex_color_use_as_albedo = true
	proxy_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	proxy_material.roughness = 1.0
	people_lod_proxy.material_override = proxy_material
	people_lod_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	people_lod_proxy.visible = false
	add_child(people_lod_proxy)


func _is_point_in_camera_view(world_position: Vector3, margin: float = 36.0) -> bool:
	if not is_instance_valid(camera):
		return true
	if camera.is_position_behind(world_position):
		return false
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var projected: Vector2 = camera.unproject_position(world_position)
	return projected.x >= viewport_rect.position.x - margin and projected.x <= viewport_rect.end.x + margin and projected.y >= viewport_rect.position.y - margin and projected.y <= viewport_rect.end.y + margin


func _project_world_position_fast(world_position: Vector3, view_inverse: Transform3D, viewport_rect: Rect2, focal_pixels: float) -> Vector3:
	# Returns screen x/y plus camera-space depth in one cached-transform operation.
	var view_position: Vector3 = view_inverse * world_position
	var depth: float = -view_position.z
	if depth <= 0.1:
		return Vector3(-INF, -INF, depth)
	var viewport_center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	return Vector3(
		viewport_center.x + view_position.x * focal_pixels / depth,
		viewport_center.y - view_position.y * focal_pixels / depth,
		depth
	)


func _is_point_in_camera_view_fast(world_position: Vector3, margin: float, view_inverse: Transform3D, viewport_rect: Rect2, focal_pixels: float) -> bool:
	# Camera3D.unproject_position() is convenient, but hundreds of calls during a
	# visibility refresh dominate CPU time on large worlds. Use the single cached
	# camera transform instead; these checks use the same perspective projection.
	var projected: Vector3 = _project_world_position_fast(world_position, view_inverse, viewport_rect, focal_pixels)
	return projected.z > 0.1 and projected.x >= viewport_rect.position.x - margin and projected.x <= viewport_rect.end.x + margin and projected.y >= viewport_rect.position.y - margin and projected.y <= viewport_rect.end.y + margin


func _refresh_people_lod_proxy(show_proxy: bool) -> void:
	if not is_instance_valid(people_lod_proxy) or people_lod_proxy.multimesh == null or not is_instance_valid(camera):
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var view_inverse: Transform3D = camera.global_transform.affine_inverse()
	var focal_pixels: float = viewport_rect.size.y * 0.5 / maxf(0.1, tan(deg_to_rad(camera.fov * 0.5)))
	var multimesh: MultiMesh = people_lod_proxy.multimesh
	var instance_index: int = 0
	var proxy_range: float = clampf(camera_distance * 0.92, 85.0, TERRAIN_SIZE * 0.78)
	var range_squared: float = proxy_range * proxy_range
	for person in people:
		if not bool(person.get("alive", true)):
			continue
		var activity: String = str(person.get("activity", ""))
		if activity in ["indoors", "riding", "boarding"]:
			continue
		var position: Vector3 = person["pos"]
		var dx: float = position.x - camera_target.x
		var dz: float = position.z - camera_target.z
		if dx * dx + dz * dz > range_squared or not _is_point_in_camera_view_fast(position + Vector3(0.0, 0.65, 0.0), 28.0, view_inverse, viewport_rect, focal_pixels):
			continue
		if instance_index >= MAX_PEOPLE:
			break
		var proxy_scale: float = 1.0 if camera_distance > 180.0 else 0.82
		multimesh.set_instance_transform(instance_index, Transform3D(Basis().scaled(Vector3.ONE * proxy_scale), position + Vector3(0.0, 0.24, 0.0)))
		var city_id: int = int(person.get("city_id", -1))
		var person_color: Color = cities[city_id]["color"].lightened(0.10) if city_id >= 0 and city_id < cities.size() else Color(0.75, 0.78, 0.76)
		multimesh.set_instance_color(instance_index, person_color)
		instance_index += 1
	multimesh.visible_instance_count = instance_index
	people_lod_proxy.visible = show_proxy and instance_index > 0


func _building_candidate_nearer(a: Dictionary, b: Dictionary) -> bool:
	return float(a["distance"]) < float(b["distance"])


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

	# Right-side dropdown keeps the world map unobstructed when the chronicle is closed.
	chronicle_button = _make_button("WORLD CHRONICLE  ▼", _toggle_chronicle, Color(0.025, 0.040, 0.060))
	chronicle_button.anchor_left = 1.0
	chronicle_button.anchor_right = 1.0
	chronicle_button.anchor_top = 0.0
	chronicle_button.anchor_bottom = 0.0
	chronicle_button.offset_left = -292.0
	chronicle_button.offset_right = -12.0
	chronicle_button.offset_top = 88.0
	chronicle_button.offset_bottom = 124.0
	chronicle_button.z_index = 8
	chronicle_button.add_theme_stylebox_override("normal", _button_style(Color(0.025, 0.040, 0.060, 0.94)))
	chronicle_button.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.13, 0.17, 0.98)))
	ui_root.add_child(chronicle_button)

	chronicle_panel = PanelContainer.new()
	chronicle_panel.anchor_left = 1.0
	chronicle_panel.anchor_right = 1.0
	chronicle_panel.anchor_top = 0.0
	chronicle_panel.anchor_bottom = 0.0
	chronicle_panel.offset_left = -292.0
	chronicle_panel.offset_right = -12.0
	chronicle_panel.offset_top = 128.0
	chronicle_panel.offset_bottom = 342.0
	chronicle_panel.z_index = 8
	chronicle_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.040, 0.060, 0.96)))
	ui_root.add_child(chronicle_panel)
	var chronicle_margin := MarginContainer.new()
	chronicle_margin.add_theme_constant_override("margin_left", 10)
	chronicle_margin.add_theme_constant_override("margin_right", 10)
	chronicle_margin.add_theme_constant_override("margin_top", 8)
	chronicle_margin.add_theme_constant_override("margin_bottom", 8)
	chronicle_panel.add_child(chronicle_margin)
	var chronicle_content := VBoxContainer.new()
	chronicle_content.add_theme_constant_override("separation", 5)
	chronicle_margin.add_child(chronicle_content)
	chronicle_content.add_child(_make_label("WORLD CHRONICLE · RECENT EVENTS", 11, Color(0.46, 0.86, 0.98)))
	var chronicle_scroll := ScrollContainer.new()
	chronicle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chronicle_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chronicle_content.add_child(chronicle_scroll)
	log_label = _make_label("Waiting for history to happen...", 10, Color(0.76, 0.83, 0.86))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(246.0, 0.0)
	chronicle_scroll.add_child(log_label)
	chronicle_panel.visible = false
	chronicle_expanded = false

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
	city_context_panel.z_index = 2
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
	city_info_label.custom_minimum_size = Vector2(0.0, 150.0)
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


func _toggle_chronicle() -> void:
	chronicle_expanded = not chronicle_expanded
	if is_instance_valid(chronicle_panel):
		chronicle_panel.visible = chronicle_expanded
	if is_instance_valid(chronicle_button):
		chronicle_button.text = "WORLD CHRONICLE  %s" % ("▲" if chronicle_expanded else "▼")
	if is_instance_valid(city_context_panel):
		city_context_panel.visible = selected_city >= 0 and selected_city < cities.size() and not chronicle_expanded


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
		city_context_panel.visible = selected_city >= 0 and selected_city < cities.size() and not chronicle_expanded
	if is_instance_valid(chronicle_panel):
		chronicle_panel.visible = chronicle_expanded
	if is_instance_valid(chronicle_button):
		chronicle_button.text = "WORLD CHRONICLE  %s" % ("▲" if chronicle_expanded else "▼")
	if is_instance_valid(city_info_label):
		if selected_city >= 0 and selected_city < cities.size():
			var city: Dictionary = cities[selected_city]
			var owner_id: int = int(city["owner"])
			var owner_name: String = cities[owner_id]["name"] if owner_id >= 0 and owner_id < cities.size() else city["name"]
			city_info_label.text = "%s\n%s · POP %d · TERR %d\nSTAB %.0f%% · SEC %.0f%% · WEALTH %d\nFUNDS %d · FOOD %d · WOOD %d · STONE %d\nIRON %d · COPPER %d · COAL %d · GOLD %d\nPOWER %d%% · INTERNET %d%%\nOWNER %s · %s" % [city["name"], _city_stage_name(int(city.get("stage", 0))), _city_population(selected_city), (city.get("territory_cells", {}) as Dictionary).size(), float(city.get("stability", 72.0)), float(city.get("security", 44.0)), int(city.get("wealth", 12.0)), int(city.get("treasury", 0.0)), int(city["food"]), int(city["wood"]), int(city["stone"]), int(city.get("iron", 0.0)), int(city.get("copper", 0.0)), int(city.get("coal", 0.0)), int(city.get("gold", 0.0)), int(city.get("electricity", 0.0)), int(city.get("internet", 0.0)), owner_name, _city_relationship_summary(selected_city)]
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


func _cull_buildings_behind_nearby_structures() -> void:
	if not is_instance_valid(camera):
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var focal_pixels: float = viewport_rect.size.y * 0.5 / maxf(0.1, tan(deg_to_rad(camera.fov * 0.5)))
	var view_inverse: Transform3D = camera.global_transform.affine_inverse()
	const CELL_SIZE: float = 64.0
	var candidates: Array[Dictionary] = []
	for city in cities:
		if bool(city.get("ruined", false)):
			continue
		for house in city["houses"]:
			if not is_instance_valid(house) or not house.visible:
				continue
			var height: float = float(house.get_meta("building_height", 3.0))
			var width: float = float(house.get_meta("building_width", 2.8))
			var house_position: Vector3 = house.global_position
			var center_world: Vector3 = house_position + Vector3(0.0, height * 0.5, 0.0)
			var center_projection: Vector3 = _project_world_position_fast(center_world, view_inverse, viewport_rect, focal_pixels)
			if center_projection.z <= 0.1:
				continue
			var depth: float = camera.global_position.distance_to(center_world)
			var top_projection: Vector3 = _project_world_position_fast(house_position + Vector3(0.0, height, 0.0), view_inverse, viewport_rect, focal_pixels)
			var bottom_projection: Vector3 = _project_world_position_fast(house_position, view_inverse, viewport_rect, focal_pixels)
			if top_projection.z <= 0.1 or bottom_projection.z <= 0.1:
				continue
			var top_screen := Vector2(top_projection.x, top_projection.y)
			var bottom_screen := Vector2(bottom_projection.x, bottom_projection.y)
			var center_screen := Vector2(center_projection.x, center_projection.y)
			var projected_width: float = clampf(focal_pixels * width / depth, 4.0, 320.0)
			var projected_height: float = clampf(absf(bottom_screen.y - top_screen.y), 8.0, 640.0)
			var bounds := Rect2(Vector2(center_screen.x - projected_width * 0.5, minf(top_screen.y, bottom_screen.y)), Vector2(projected_width, projected_height))
			candidates.append({"node": house, "distance": depth, "height": height, "center": center_screen, "bounds": bounds})
	candidates.sort_custom(_building_candidate_nearer)
	# Check only occluders in the screen-space cells overlapping each candidate's
	# centre. This avoids a quadratic scan through every high-rise in the city.
	var occluder_cells: Dictionary = {}
	for candidate in candidates:
		var building: Node3D = candidate["node"]
		var building_height: float = float(candidate["height"])
		var depth: float = float(candidate["distance"])
		var center: Vector2 = candidate["center"]
		var cell := Vector2i(floori(center.x / CELL_SIZE), floori(center.y / CELL_SIZE))
		var nearby_occluders: Array = occluder_cells.get(cell, [])
		var occluded: bool = false
		for occluder in nearby_occluders:
			if float(occluder["distance"]) + 0.8 >= depth:
				continue
			if float(occluder["height"]) < building_height * 0.78:
				continue
			var occluder_bounds: Rect2 = occluder["bounds"]
			if occluder_bounds.has_point(center):
				occluded = true
				break
		building.set_meta("lod_occluded", occluded)
		building.visible = not occluded
		if not occluded and building_height >= 6.0:
			var record := {"distance": depth, "height": building_height, "bounds": candidate["bounds"]}
			var bounds: Rect2 = candidate["bounds"]
			var min_cell_x: int = floori(bounds.position.x / CELL_SIZE)
			var max_cell_x: int = floori(bounds.end.x / CELL_SIZE)
			var min_cell_y: int = floori(bounds.position.y / CELL_SIZE)
			var max_cell_y: int = floori(bounds.end.y / CELL_SIZE)
			# Projected bounds are clamped by the candidate margins/size, so this
			# stays bounded even for very tall buildings near the camera.
			for cell_y in range(min_cell_y, max_cell_y + 1):
				for cell_x in range(min_cell_x, max_cell_x + 1):
					var key := Vector2i(cell_x, cell_y)
					var bucket: Array = occluder_cells.get(key, [])
					bucket.append(record)
					occluder_cells[key] = bucket


func _update_world_detail_levels() -> void:
	var active_lod: int = _terrain_lod_index_for_distance(camera_distance)
	if active_lod < terrain_lod_dirty.size() and terrain_lod_dirty[active_lod]:
		_build_terrain_lod(active_lod)
	if active_lod != last_road_terrain_lod:
		last_road_terrain_lod = active_lod
		for city_id in range(cities.size()):
			_queue_city_roads_rebuild(city_id)
	_set_active_terrain_lod_visibility(active_lod)
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
	var detail_signature: String = "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		active_lod, int(show_city_models), int(show_neighbourhoods), int(show_resources),
		int(show_people), int(show_city_labels), int(show_far_markers), cities.size(),
		building_count, people.size(), resources.size(), cars.size() + rubble_records.size(),
		focus_cell_x, focus_cell_z, int(camera_yaw * 10.0), int(camera_pitch * 10.0),
		int(camera_distance * 0.5), int(camera_target.y)
	]
	# Citizen movement changes constantly. Refresh the distance proxy on a wall-clock
	# cadence, but do not rerun the expensive whole-city occlusion pass for every
	# citizen entering/leaving a building.
	if show_people:
		if is_instance_valid(people_lod_proxy):
			people_lod_proxy.visible = false
	elif people_lod_refresh_cooldown <= 0.0:
		_refresh_people_lod_proxy(true)
		people_lod_refresh_cooldown = 0.75
	if detail_signature == last_detail_signature:
		return
	if detail_refresh_cooldown > 0.0:
		return
	last_detail_signature = detail_signature
	detail_refresh_cooldown = 0.45
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var view_inverse: Transform3D = camera.global_transform.affine_inverse()
	var focal_pixels: float = viewport_rect.size.y * 0.5 / maxf(0.1, tan(deg_to_rad(camera.fov * 0.5)))
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
		for utility_key in ["power_plant", "internet_hub"]:
			var utility_node: Node3D = city.get(utility_key) as Node3D
			if is_instance_valid(utility_node):
				utility_node.visible = show_neighbourhoods and not ruined
		var city_label: Label3D = city["label"]
		if is_instance_valid(city_label):
			city_label.visible = show_city_labels
		var roads: MeshInstance3D = city["roads"]
		if is_instance_valid(roads):
			roads.visible = show_neighbourhoods and not ruined
		var sidewalks: MeshInstance3D = city.get("sidewalks") as MeshInstance3D
		if is_instance_valid(sidewalks):
			sidewalks.visible = show_neighbourhoods and not ruined
		var crosswalks: MeshInstance3D = city.get("crosswalks") as MeshInstance3D
		if is_instance_valid(crosswalks):
			crosswalks.visible = show_neighbourhoods and not ruined
		var islands: MeshInstance3D = city.get("islands") as MeshInstance3D
		if is_instance_valid(islands):
			islands.visible = show_neighbourhoods and not ruined
		for house in city["houses"]:
			if not is_instance_valid(house):
				continue
			var building_height: float = float(house.get_meta("building_height", 3.0))
			var building_width: float = float(house.get_meta("building_width", 2.8))
			var view_point: Vector3 = house.global_position + Vector3(0.0, building_height * 0.5, 0.0)
			var top_point: Vector3 = house.global_position + Vector3(0.0, building_height, 0.0)
			var in_frustum: bool = _is_point_in_camera_view_fast(view_point, 54.0, view_inverse, viewport_rect, focal_pixels) or _is_point_in_camera_view_fast(top_point, 54.0, view_inverse, viewport_rect, focal_pixels)
			var distance_squared: float = house.global_position.distance_squared_to(camera.global_position)
			var base_visible: bool = show_neighbourhoods and not ruined and distance_squared <= 220.0 * 220.0 and in_frustum
			if building_occlusion_refresh_cooldown > 0.0:
				house.visible = base_visible and not bool(house.get_meta("lod_occluded", false))
			else:
				house.visible = base_visible
	if building_occlusion_refresh_cooldown <= 0.0:
		var occlusion_started_usec: int = Time.get_ticks_usec()
		_cull_buildings_behind_nearby_structures()
		_trace_slow_operation("building-occlusion-culling", occlusion_started_usec)
		building_occlusion_refresh_cooldown = 0.85
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
		person_node.visible = show_people and not indoors and bool(person.get("alive", true)) and dx * dx + dz * dz <= person_range_squared and _is_point_in_camera_view_fast(position + Vector3(0.0, 0.65, 0.0), 28.0, view_inverse, viewport_rect, focal_pixels)
	for car in cars:
		var car_node: Node3D = car["node"]
		if not is_instance_valid(car_node):
			continue
		var car_position: Vector3 = car["pos"]
		var dx: float = car_position.x - camera_target.x
		var dz: float = car_position.z - camera_target.z
		var render_range: float = maxf(42.0, camera_distance * 0.68)
		car_node.visible = show_neighbourhoods and dx * dx + dz * dz <= render_range * render_range and _is_point_in_camera_view_fast(car_position + Vector3(0.0, 0.5, 0.0), 32.0, view_inverse, viewport_rect, focal_pixels)
	for resource in resources:
		var resource_node: Node3D = resource["node"]
		if is_instance_valid(resource_node):
			resource_node.visible = show_resources and bool(resource.get("alive", true)) and int(resource.get("amount", 1)) > 0 and _is_point_in_camera_view_fast(resource.get("pos", Vector3.ZERO) + Vector3(0.0, 0.4, 0.0), 22.0, view_inverse, viewport_rect, focal_pixels)


func _run_save_load_smoke_test() -> void:
	# The persistence regression includes electricity and internet, so test in a
	# period where those utilities legitimately exist instead of injecting them
	# into a medieval save that should remove anachronistic services on load.
	game_clock = float(2026 - STARTING_YEAR) * SECONDS_PER_YEAR
	last_architecture_era = -1
	_update_historical_era(true)
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
	cities[0]["treasury"] = 321.5
	cities[0]["iron"] = 6.5
	cities[0]["copper"] = 3.25
	cities[0]["coal"] = 4.5
	cities[0]["gold"] = 1.25
	cities[0]["electricity"] = 42.0
	cities[0]["internet"] = 19.0
	city_relations[_city_relation_key(0, 1)] = 0.0
	_declare_war(0, 1)
	var expected_treasury: float = float(cities[0]["treasury"])
	var expected_iron: float = float(cities[0]["iron"])
	var expected_copper: float = float(cities[0]["copper"])
	var expected_coal: float = float(cities[0]["coal"])
	var expected_gold: float = float(cities[0]["gold"])
	var expected_electricity: float = float(cities[0]["electricity"])
	var expected_internet: float = float(cities[0]["internet"])
	cities[0]["destroyed_building_debt"] = int(cities[0].get("destroyed_building_debt", 0)) + 1
	cities[0]["next_plot_index"] = maxi(int(cities[0].get("next_plot_index", 0)), 9)
	var expected_destroyed_debt: int = int(cities[0]["destroyed_building_debt"])
	var expected_next_plot_index: int = int(cities[0]["next_plot_index"])
	var expected_initial_road_damage_count: int = (cities[0].get("road_damage", []) as Array).size()
	_damage_city_roads(0, cities[0]["pos"], 3.4, true)
	var expected_road_damage_count: int = (cities[0].get("road_damage", []) as Array).size()
	if expected_road_damage_count <= expected_initial_road_damage_count:
		push_error("SAVE_LOAD_TEST_FAILED: A road impact did not create a damaged-road record.")
		get_tree().quit(1)
		return
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
	for stock_check in [
		{"key": "treasury", "expected": expected_treasury},
		{"key": "iron", "expected": expected_iron},
		{"key": "copper", "expected": expected_copper},
		{"key": "coal", "expected": expected_coal},
		{"key": "gold", "expected": expected_gold},
		{"key": "electricity", "expected": expected_electricity},
		{"key": "internet", "expected": expected_internet}
	]:
		if absf(float(cities[0].get(str(stock_check["key"]), 0.0)) - float(stock_check["expected"])) > 0.001:
			push_error("SAVE_LOAD_TEST_FAILED: %s was not restored." % str(stock_check["key"]))
			get_tree().quit(1)
			return
	if not _are_at_war(0, 1) or absf(_city_relation(0, 1) + 100.0) > 0.001:
		push_error("SAVE_LOAD_TEST_FAILED: War state or trade embargo relation was not restored.")
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
	if (cities[0].get("road_damage", []) as Array).size() != expected_road_damage_count:
		push_error("SAVE_LOAD_TEST_FAILED: Damaged road sections were not restored.")
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
			"plot_index": int(house.get_meta("plot_index", 0)),
			"large_plot": bool(house.get_meta("large_plot", false)),
			"plot_footprint": float(house.get_meta("plot_footprint", 3.6)),
			"construction": bool(house.get_meta("is_construction_site", false)),
			"construction_progress": float(house.get_meta("construction_progress", 0.0)),
			"terrain_terraced": bool(house.get_meta("terrain_terraced", false)),
			"plot_grade_radius": float(house.get_meta("plot_grade_radius", 2.25)),
			"refurbishment": bool(house.get_meta("is_refurbishment_site", false))
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
			"capital_id": int(city.get("capital_id", city["owner"])),
			"is_capital": bool(city.get("is_capital", true)),
			"loyalty": float(city.get("loyalty", 100.0)),
			"autonomy": float(city.get("autonomy", 0.0)),
			"hostage_count": int(city.get("hostage_count", 0)),
			"hostage_cooldown": float(city.get("hostage_cooldown", 0.0)),
			"food": float(city["food"]),
			"wood": float(city["wood"]),
			"stone": float(city["stone"]),
			"iron": float(city.get("iron", 0.0)),
			"copper": float(city.get("copper", 0.0)),
			"coal": float(city.get("coal", 0.0)),
			"gold": float(city.get("gold", 0.0)),
			"treasury": float(city.get("treasury", 85.0)),
			"electricity": float(city.get("electricity", 0.0)),
			"internet": float(city.get("internet", 0.0)),
			"trade_volume": float(city.get("trade_volume", 0.0)),
			"stability": float(city.get("stability", 72.0)),
			"security": float(city.get("security", 44.0)),
			"next_city_event_time": float(city.get("next_city_event_time", 0.0)),
			"wealth": float(city.get("wealth", 12.0)),
			"stage": int(city.get("stage", 0)),
			"abandoned": bool(city.get("abandoned", false)),
			"abandoned_age": float(city.get("abandoned_age", 0.0)),
			"abandoned_decay_timer": float(city.get("abandoned_decay_timer", 8.0)),
			"ruined": bool(city.get("ruined", false)),
			"buildings": _serialize_city_buildings(city),
			"destroyed_building_debt": int(city.get("destroyed_building_debt", 0)),
			"next_plot_index": int(city.get("next_plot_index", 0)),
			"road_damage": city.get("road_damage", [])
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
			"walk_timer": float(person.get("walk_timer", 1.0)),
			"activity": str(person.get("activity", "wandering")),
			"hostage_home_city": int(person.get("hostage_home_city", -1)),
			"hostage_captor": int(person.get("hostage_captor", -1)),
			"hostage_timer": float(person.get("hostage_timer", 0.0))
		})

	var saved_oil_rigs: Array = []
	for rig in oil_rigs:
		saved_oil_rigs.append({
			"pos": _vector3_to_array(rig["pos"]),
			"owner_city": int(rig.get("owner_city", -1)),
			"reserves": float(rig.get("reserves", 0.0)),
			"production": float(rig.get("production", 0.0)),
			"health": float(rig.get("health", 100.0))
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
		"city_relations": city_relations,
		"alliances": alliances,
		"wars": wars,
		"oil_rigs": saved_oil_rigs,
		"trade_timer": trade_timer,
		"trade_events_total": trade_events_total,
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
	var saved_oil_rigs: Variant = save_data.get("oil_rigs", [])
	var saved_rubble: Variant = save_data.get("rubble", [])
	if typeof(saved_cities) != TYPE_ARRAY or typeof(saved_people) != TYPE_ARRAY or typeof(saved_resources) != TYPE_ARRAY or typeof(saved_rubble) != TYPE_ARRAY:
		_log("LOAD FAILED: The save is missing world data.")
		return
	if saved_cities.is_empty():
		_log("LOAD FAILED: The save does not contain any cities.")
		return

	_clear_loaded_world()
	is_loading_world = true
	world_seed = int(save_data.get("world_seed", 14029))
	seed(world_seed)
	_generate_terrain_heights() # Refresh climate noise from the saved seed.
	terrain_heights = _adapt_saved_heightmap(restored_heights, saved_terrain_size)
	_rebuild_terrain()
	game_clock = float(save_data.get("game_clock", 0.0))
	city_events_total = int(save_data.get("city_events_total", 0))
	var saved_relations: Variant = save_data.get("city_relations", {})
	city_relations = saved_relations if typeof(saved_relations) == TYPE_DICTIONARY else {}
	var saved_alliances: Variant = save_data.get("alliances", {})
	alliances = saved_alliances if typeof(saved_alliances) == TYPE_DICTIONARY else {}
	var saved_wars: Variant = save_data.get("wars", [])
	trade_timer = maxf(0.0, float(save_data.get("trade_timer", 0.0)))
	trade_events_total = maxi(0, int(save_data.get("trade_events_total", 0)))
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
		city["capital_id"] = clampi(int(city_data.get("capital_id", city_id)), 0, maxi(0, saved_cities.size() - 1))
		city["is_capital"] = bool(city_data.get("is_capital", int(city_data.get("owner", city_id)) == city_id))
		city["loyalty"] = clampf(float(city_data.get("loyalty", 100.0)), 0.0, 100.0)
		city["autonomy"] = clampf(float(city_data.get("autonomy", 0.0)), 0.0, 100.0)
		city["hostage_count"] = maxi(0, int(city_data.get("hostage_count", 0)))
		city["hostage_cooldown"] = maxf(0.0, float(city_data.get("hostage_cooldown", 0.0)))
		city["airport_attempted"] = false
		city["seaport_attempted"] = false
		city["food"] = float(city_data.get("food", 8.0))
		city["wood"] = float(city_data.get("wood", 5.0))
		city["stone"] = float(city_data.get("stone", 3.0))
		city["iron"] = float(city_data.get("iron", 0.0))
		city["copper"] = float(city_data.get("copper", 0.0))
		city["coal"] = float(city_data.get("coal", 0.0))
		city["gold"] = float(city_data.get("gold", 0.0))
		city["treasury"] = float(city_data.get("treasury", 85.0))
		city["electricity"] = float(city_data.get("electricity", 0.0))
		city["internet"] = float(city_data.get("internet", 0.0))
		city["trade_volume"] = float(city_data.get("trade_volume", 0.0))
		city["stability"] = float(city_data.get("stability", 72.0))
		city["security"] = float(city_data.get("security", 44.0))
		city["next_city_event_time"] = maxf(0.0, float(city_data.get("next_city_event_time", 0.0)))
		city["wealth"] = float(city_data.get("wealth", 12.0))
		city["stage"] = clampi(int(city_data.get("stage", 0)), 0, 4)
		city["abandoned"] = bool(city_data.get("abandoned", false))
		city["abandoned_age"] = maxf(0.0, float(city_data.get("abandoned_age", 0.0)))
		city["abandoned_decay_timer"] = maxf(0.0, float(city_data.get("abandoned_decay_timer", 8.0)))
		city["ruined"] = bool(city_data.get("ruined", false))
		city["destroyed_building_debt"] = maxi(0, int(city_data.get("destroyed_building_debt", 0)))
		city["next_plot_index"] = maxi(0, int(city_data.get("next_plot_index", 0)))
		var saved_road_damage: Variant = city_data.get("road_damage", [])
		city["road_damage"] = saved_road_damage if typeof(saved_road_damage) == TYPE_ARRAY else []
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
				house.set_meta("large_plot", bool(building_data.get("large_plot", false)))
				house.set_meta("plot_footprint", float(building_data.get("plot_footprint", 3.6)))
				house.set_meta("is_construction_site", bool(building_data.get("construction", false)))
				house.set_meta("construction_progress", float(building_data.get("construction_progress", 0.0)))
				house.set_meta("terrain_terraced", bool(building_data.get("terrain_terraced", false)))
				house.set_meta("plot_grade_radius", float(building_data.get("plot_grade_radius", 2.25)))
				house.set_meta("is_refurbishment_site", bool(building_data.get("refurbishment", false)))
				city["houses"].append(house)
		cities[city_id] = city

	# Restore oil fields after city IDs exist, preserving their current owners.
	if typeof(saved_oil_rigs) == TYPE_ARRAY:
		for saved_rig in saved_oil_rigs:
			if typeof(saved_rig) != TYPE_DICTIONARY:
				continue
			var rig_data: Dictionary = saved_rig
			var rig_position: Vector3 = _array_to_vector3(rig_data.get("pos", []), Vector3(0.0, WATER_LEVEL, 0.0))
			var rig_owner: int = int(rig_data.get("owner_city", -1))
			if rig_owner < -1 or rig_owner >= cities.size():
				rig_owner = -1
			var rig_node: Node3D = _create_oil_rig_visual(rig_position)
			oil_rigs.append({"node": rig_node, "pos": rig_position, "owner_city": rig_owner, "reserves": maxf(0.0, float(rig_data.get("reserves", 800.0))), "production": maxf(0.05, float(rig_data.get("production", 0.5))), "health": clampf(float(rig_data.get("health", 100.0)), 0.0, 100.0)})
	# Restore diplomatic wars only after the city index table has been rebuilt.
	if typeof(saved_wars) == TYPE_ARRAY:
		for saved_war in saved_wars:
			if typeof(saved_war) != TYPE_DICTIONARY:
				continue
			var war_a: int = int(saved_war.get("a", -1))
			var war_b: int = int(saved_war.get("b", -1))
			if war_a < 0 or war_b < 0 or war_a >= cities.size() or war_b >= cities.size() or war_a == war_b:
				continue
			if not _are_at_war(war_a, war_b):
				wars.append({"a": war_a, "b": war_b})

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
		person["activity"] = str(person_data.get("activity", "wandering"))
		person["hostage_home_city"] = int(person_data.get("hostage_home_city", -1))
		person["hostage_captor"] = int(person_data.get("hostage_captor", -1))
		person["hostage_timer"] = maxf(0.0, float(person_data.get("hostage_timer", 0.0)))
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
		if kind not in ["tree", "stone", "food", "iron_ore", "copper_ore", "coal", "gold_ore"]:
			continue
		_spawn_resource(resource_position, kind, maxi(1, int(resource_data.get("amount", 1))))

	# Rebuild homes and territory after all people and cities exist, so borders
	# are calculated against the final city population and neighbouring zones.
	for city_id in range(cities.size()):
		for saved_house in cities[city_id]["houses"]:
			if is_instance_valid(saved_house) and bool(saved_house.get_meta("is_construction_site", false)):
				_setup_construction_site(saved_house, city_id, int(saved_house.get_meta("base_building_type", 0)), int(saved_house.get_meta("plot_index", 0)), float(saved_house.get_meta("construction_progress", 0.0)), bool(saved_house.get_meta("is_refurbishment_site", false)))
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
				house.scale = Vector3.ONE * (1.0 + float(cities[city_id].get("stage", 0)) * (0.04 if bool(house.get_meta("large_plot", false)) else 0.07))
		_apply_building_era_appearance(city_id, _world_year(), -1, true)
	_refresh_city_territory(0)
	for city_id in range(cities.size()):
		_rebuild_city_roads(city_id)
		_ensure_city_infrastructure(city_id, _world_year())

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
	camera_distance = clampf(float(save_data.get("camera_distance", 230.0)), 24.0, TERRAIN_SIZE * 1.75)
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
	is_loading_world = false
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
	pending_city_development.clear()
	pending_city_development_set.clear()
	pending_city_road_rebuilds.clear()
	pending_city_road_rebuild_set.clear()
	next_city_road_rebuild_usec = 0
	next_building_visual_mutation_usec = 0
	building_visual_mutation_consumed_this_frame = false
	building_start_budget_remaining = 0
	in_simulation_frame = false
	is_loading_world = false
	for existing_child in get_children():
		if existing_child is Node3D and existing_child.name in ["BuildingRubble", "VehicleWreck"]:
			existing_child.queue_free()
	rubble_records.clear()
	rubble_nodes.clear()
	rubble_id_sequence = 1
	construction_sites.clear()
	construction_id_sequence = 1
	construction_site_update_cursor = 0
	construction_simulation_clock = 0.0
	for city in cities:
		for key in ["node", "zone_fill", "zone_border"]:
			if city.has(key) and city[key] is Node and is_instance_valid(city[key]):
				(city[key] as Node).queue_free()
	_queue_nodes_from_entries(people)
	_queue_nodes_from_entries(cars)
	_queue_nodes_from_entries(resources)
	_queue_nodes_from_entries(transports)
	_queue_nodes_from_entries(oil_rigs)
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
	transports.clear()
	oil_rigs.clear()
	alliances.clear()
	transport_timer = 0.0
	oil_update_timer = 0.0
	diplomacy_timer = 0.0
	last_detail_signature = ""
	armies.clear()
	missiles.clear()
	explosions.clear()
	god_effects.clear()
	fire_zones.clear()
	falling_meteors.clear()
	tornadoes.clear()
	wars.clear()
	city_relations.clear()
	trade_timer = 0.0
	trade_events_total = 0
	selected_city = -1
	controlled_city = -1


func _find_city_utility_site(city_id: int, inner_radius: float, outer_radius: float) -> Vector3:
	if city_id < 0 or city_id >= cities.size():
		return Vector3.ZERO
	var city: Dictionary = cities[city_id]
	var city_pos: Vector3 = city["pos"]
	for ring_index in range(32):
		var radius: float = lerpf(inner_radius, outer_radius, float(ring_index) / 31.0)
		for spoke in range(8):
			var angle: float = float(spoke) * TAU / 8.0 + float(city_id) * 0.41 + float(ring_index) * 0.17
			var world_x: float = city_pos.x + cos(angle) * radius
			var world_z: float = city_pos.z + sin(angle) * radius
			if absf(world_x) >= TERRAIN_SIZE * 0.46 or absf(world_z) >= TERRAIN_SIZE * 0.46 or _height_at(world_x, world_z) <= WATER_LEVEL + 0.25:
				continue
			var clear: bool = true
			for house in city["houses"]:
				if not is_instance_valid(house):
					continue
				var existing_width: float = float(house.get_meta("plot_footprint", 3.6))
				if Vector2(house.global_position.x - world_x, house.global_position.z - world_z).length() < existing_width * 0.55 + 3.6:
					clear = false
					break
			if not clear:
				continue
			for utility_key in ["power_plant", "internet_hub"]:
				var existing_utility: Node3D = city.get(utility_key) as Node3D
				if is_instance_valid(existing_utility) and Vector2(existing_utility.global_position.x - world_x, existing_utility.global_position.z - world_z).length() < 7.0:
					clear = false
					break
			if clear:
				return Vector3(world_x - city_pos.x, _height_at(world_x, world_z) - city_pos.y, world_z - city_pos.z)
	return Vector3(inner_radius, 0.0, inner_radius)


func _create_city_power_plant(city_id: int) -> void:
	var city: Dictionary = cities[city_id]
	var plant := Node3D.new()
	plant.name = "CoalPowerStation"
	plant.position = _find_city_utility_site(city_id, 24.0, 42.0)
	city["node"].add_child(plant)
	var foundation := BoxMesh.new()
	foundation.size = Vector3(6.8, 0.32, 5.2)
	_add_mesh(plant, foundation, _material(Color(0.31, 0.33, 0.33)), Vector3(0.0, 0.16, 0.0))
	var generator_hall := BoxMesh.new()
	generator_hall.size = Vector3(4.0, 2.7, 3.1)
	_add_mesh(plant, generator_hall, _material(Color(0.43, 0.46, 0.45)), Vector3(0.0, 1.65, 0.0))
	var roof := BoxMesh.new()
	roof.size = Vector3(4.25, 0.22, 3.35)
	_add_mesh(plant, roof, _material(Color(0.24, 0.27, 0.28)), Vector3(0.0, 3.1, 0.0))
	for stack_index in range(2):
		var stack := CylinderMesh.new()
		stack.top_radius = 0.30
		stack.bottom_radius = 0.43
		stack.height = 3.1
		stack.radial_segments = 8
		_add_mesh(plant, stack, _material(Color(0.33, 0.31, 0.29)), Vector3((float(stack_index) - 0.5) * 2.25, 4.45, -0.75))
	city["power_plant"] = plant
	cities[city_id] = city
	_log("%s built a coal-fired power station. Electricity now depends on fuel and upkeep." % city["name"])


func _create_city_internet_hub(city_id: int) -> void:
	var city: Dictionary = cities[city_id]
	var hub := Node3D.new()
	hub.name = "TelecommunicationsExchange"
	hub.position = _find_city_utility_site(city_id, 20.0, 38.0)
	city["node"].add_child(hub)
	var base := BoxMesh.new()
	base.size = Vector3(4.6, 1.5, 3.8)
	_add_mesh(hub, base, _material(Color(0.49, 0.53, 0.55)), Vector3(0.0, 0.75, 0.0))
	var roof := BoxMesh.new()
	roof.size = Vector3(4.9, 0.18, 4.1)
	_add_mesh(hub, roof, _material(Color(0.24, 0.32, 0.37)), Vector3(0.0, 1.58, 0.0))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.055
	mast.bottom_radius = 0.09
	mast.height = 7.0
	_add_mesh(hub, mast, _material(Color(0.48, 0.52, 0.52)), Vector3(0.65, 5.0, 0.0))
	for antenna_index in range(3):
		var antenna := BoxMesh.new()
		antenna.size = Vector3(1.3, 0.08, 0.10)
		_add_mesh(hub, antenna, _material(Color(0.61, 0.72, 0.76)), Vector3(0.65, 4.0 + float(antenna_index) * 0.85, 0.0))
	city["internet_hub"] = hub
	cities[city_id] = city
	_log("%s established a telecommunications exchange. Internet service is now available." % city["name"])


func _ensure_city_infrastructure(city_id: int, year: int) -> void:
	if city_id < 0 or city_id >= cities.size():
		return
	var city: Dictionary = cities[city_id]
	if year >= 1880:
		if not is_instance_valid(city.get("power_plant")):
			_create_city_power_plant(city_id)
	else:
		var obsolete_plant: Node3D = city.get("power_plant") as Node3D
		if is_instance_valid(obsolete_plant):
			obsolete_plant.queue_free()
		city["power_plant"] = null
		city["electricity"] = 0.0
	if year >= 2000:
		if not is_instance_valid(city.get("internet_hub")):
			_create_city_internet_hub(city_id)
	else:
		var obsolete_hub: Node3D = city.get("internet_hub") as Node3D
		if is_instance_valid(obsolete_hub):
			obsolete_hub.queue_free()
		city["internet_hub"] = null
		city["internet"] = 0.0
	cities[city_id] = city
	var population: int = _city_population(city_id)
	if not bool(city.get("ruined", false)) and year >= 1450 and population >= 16 and not bool(city.get("seaport_attempted", false)):
		city["seaport_attempted"] = true
		cities[city_id] = city
		_create_city_seaport(city_id)
	city = cities[city_id]
	if not bool(city.get("ruined", false)) and year >= 1945 and population >= 24 and not bool(city.get("airport_attempted", false)):
		city["airport_attempted"] = true
		cities[city_id] = city
		_create_city_airport(city_id)

func _find_city_waterfront_site(city_id: int) -> Vector3:
	if city_id < 0 or city_id >= cities.size():
		return Vector3(0.0, -999.0, 0.0)
	var city_position: Vector3 = cities[city_id]["pos"]
	for ring_index in range(22):
		var radius: float = 32.0 + float(ring_index) * 8.0
		for spoke in range(16):
			var angle: float = float(spoke) * TAU / 16.0 + float(city_id) * 0.29
			var world_x: float = city_position.x + cos(angle) * radius
			var world_z: float = city_position.z + sin(angle) * radius
			if absf(world_x) >= TERRAIN_SIZE * 0.46 or absf(world_z) >= TERRAIN_SIZE * 0.46:
				continue
			if _height_at(world_x, world_z) <= WATER_LEVEL + 0.20:
				continue
			var water_x: float = world_x + cos(angle) * 8.0
			var water_z: float = world_z + sin(angle) * 8.0
			if _height_at(water_x, water_z) > WATER_LEVEL - 0.10:
				continue
			var clear: bool = true
			for house in cities[city_id]["houses"]:
				if is_instance_valid(house) and Vector2(house.global_position.x - world_x, house.global_position.z - world_z).length() < 5.5:
					clear = false
					break
			if clear:
				return _surface_position(world_x, world_z) - city_position
	return Vector3(0.0, -999.0, 0.0)


func _create_city_airport(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size() or is_instance_valid(cities[city_id].get("airport")):
		return
	var city: Dictionary = cities[city_id]
	var airport := Node3D.new()
	airport.name = "AirportAuthority"
	airport.position = _find_city_utility_site(city_id, 46.0, 88.0)
	cities[city_id]["node"].add_child(airport)
	var concrete := _material(Color(0.35, 0.37, 0.37))
	var tarmac := BoxMesh.new()
	tarmac.size = Vector3(8.5, 0.14, 46.0)
	_add_mesh(airport, tarmac, concrete, Vector3(0.0, 0.08, 0.0))
	var runway_mark := BoxMesh.new()
	runway_mark.size = Vector3(0.18, 0.025, 37.0)
	_add_mesh(airport, runway_mark, _material(Color(0.88, 0.88, 0.78)), Vector3(0.0, 0.17, 0.0))
	var terminal := BoxMesh.new()
	terminal.size = Vector3(8.2, 3.0, 5.0)
	_add_mesh(airport, terminal, _material(Color(0.49, 0.54, 0.55)), Vector3(0.0, 1.60, -7.5))
	var roof := BoxMesh.new()
	roof.size = Vector3(8.8, 0.25, 5.5)
	_add_mesh(airport, roof, _material(Color(0.23, 0.29, 0.32)), Vector3(0.0, 3.25, -7.5))
	var tower := BoxMesh.new()
	tower.size = Vector3(1.5, 5.0, 1.5)
	_add_mesh(airport, tower, _material(Color(0.52, 0.58, 0.60)), Vector3(5.5, 2.7, -11.0))
	var glass := BoxMesh.new()
	glass.size = Vector3(1.7, 0.35, 1.7)
	_add_mesh(airport, glass, _material(Color(0.16, 0.47, 0.61)), Vector3(5.5, 5.2, -11.0))
	city = cities[city_id]
	city["airport"] = airport
	city["treasury"] = maxf(0.0, float(city.get("treasury", 0.0)) - 30.0)
	city["iron"] = maxf(0.0, float(city.get("iron", 0.0)) - 3.0)
	cities[city_id] = city
	_log("AIRPORT BUILT: %s can now operate passenger and cargo aircraft." % city["name"])


func _create_city_seaport(city_id: int) -> void:
	if city_id < 0 or city_id >= cities.size() or is_instance_valid(cities[city_id].get("seaport")):
		return
	var city: Dictionary = cities[city_id]
	var site: Vector3 = _find_city_waterfront_site(city_id)
	if site.y < -100.0:
		city["seaport_attempted"] = true
		cities[city_id] = city
		return
	var port := Node3D.new()
	port.name = "SeaportAuthority"
	port.position = site
	var facing: Vector2 = Vector2(site.x, site.z).normalized()
	port.rotation.y = atan2(facing.x, facing.y)
	cities[city_id]["node"].add_child(port)
	var pier := BoxMesh.new()
	pier.size = Vector3(3.0, 0.35, 12.0)
	_add_mesh(port, pier, _material(Color(0.38, 0.34, 0.28)), Vector3(0.0, 0.25, 5.0))
	var quay := BoxMesh.new()
	quay.size = Vector3(10.0, 0.35, 6.0)
	_add_mesh(port, quay, _material(Color(0.47, 0.48, 0.45)), Vector3(0.0, 0.22, -1.5))
	for container_index in range(3):
		var container := BoxMesh.new()
		container.size = Vector3(1.8, 1.3, 2.8)
		var container_color: Color = [Color(0.68, 0.26, 0.15), Color(0.15, 0.37, 0.58), Color(0.71, 0.60, 0.22)][container_index]
		_add_mesh(port, container, _material(container_color), Vector3(float(container_index - 1) * 2.2, 1.05, -2.0))
	var crane := BoxMesh.new()
	crane.size = Vector3(0.24, 5.0, 0.24)
	_add_mesh(port, crane, _material(Color(0.80, 0.66, 0.23)), Vector3(4.1, 2.6, -2.0))
	var boom := BoxMesh.new()
	boom.size = Vector3(4.8, 0.22, 0.22)
	_add_mesh(port, boom, _material(Color(0.80, 0.66, 0.23)), Vector3(2.1, 4.9, -2.0))
	city = cities[city_id]
	city["seaport"] = port
	city["treasury"] = maxf(0.0, float(city.get("treasury", 0.0)) - 18.0)
	cities[city_id] = city
	_log("SEAPORT BUILT: %s can now operate coastal passenger and cargo shipping." % city["name"])


func _create_oil_rig_visual(position: Vector3) -> Node3D:
	var rig := Node3D.new()
	rig.name = "OffshoreOilRig"
	rig.position = Vector3(position.x, WATER_LEVEL, position.z)
	add_child(rig)
	var platform := BoxMesh.new()
	platform.size = Vector3(7.2, 0.55, 7.2)
	_add_mesh(rig, platform, _material(Color(0.35, 0.39, 0.38)), Vector3(0.0, 0.5, 0.0))
	for leg_x in [-2.7, 2.7]:
		for leg_z in [-2.7, 2.7]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.34, 3.4, 0.34)
			_add_mesh(rig, leg, _material(Color(0.24, 0.29, 0.29)), Vector3(leg_x, -1.2, leg_z))
	var derrick_base := BoxMesh.new()
	derrick_base.size = Vector3(2.8, 0.4, 2.8)
	_add_mesh(rig, derrick_base, _material(Color(0.48, 0.50, 0.46)), Vector3(0.0, 1.0, 0.0))
	var tower := BoxMesh.new()
	tower.size = Vector3(0.28, 4.3, 0.28)
	_add_mesh(rig, tower, _material(Color(0.83, 0.59, 0.18)), Vector3(0.0, 3.25, 0.0))
	for brace_index in range(3):
		var brace := BoxMesh.new()
		brace.size = Vector3(2.5 - float(brace_index) * 0.55, 0.14, 0.14)
		_add_mesh(rig, brace, _material(Color(0.81, 0.60, 0.22)), Vector3(0.0, 2.0 + float(brace_index) * 1.1, 0.0))
	var cab := BoxMesh.new()
	cab.size = Vector3(1.7, 1.25, 1.4)
	_add_mesh(rig, cab, _material(Color(0.18, 0.31, 0.39)), Vector3(-1.7, 1.25, -0.3))
	var sign := Label3D.new()
	sign.text = "OIL"
	sign.font_size = 30
	sign.pixel_size = 0.018
	sign.outline_size = 5
	sign.position = Vector3(0.0, 5.9, 0.0)
	sign.modulate = Color(1.0, 0.78, 0.28)
	rig.add_child(sign)
	return rig


func _seed_oil_rigs() -> void:
	if not oil_rigs.is_empty():
		return
	var created: int = 0
	for rig_index in range(MAX_OIL_RIGS):
		var site_found: bool = false
		var chosen_position: Vector3 = Vector3.ZERO
		for attempt in range(90):
			var land_x: float = randf_range(-TERRAIN_SIZE * 0.43, TERRAIN_SIZE * 0.43)
			var land_z: float = randf_range(-TERRAIN_SIZE * 0.43, TERRAIN_SIZE * 0.43)
			if _height_at(land_x, land_z) <= WATER_LEVEL + 0.35:
				continue
			var angle: float = randf() * TAU
			for step_index in range(1, 36):
				var distance: float = float(step_index) * 6.0
				var candidate_x: float = land_x + cos(angle) * distance
				var candidate_z: float = land_z + sin(angle) * distance
				if absf(candidate_x) >= TERRAIN_SIZE * 0.46 or absf(candidate_z) >= TERRAIN_SIZE * 0.46:
					break
				if _height_at(candidate_x, candidate_z) > WATER_LEVEL - 0.1:
					continue
				candidate_x += cos(angle) * 6.0
				candidate_z += sin(angle) * 6.0
				var clear: bool = true
				for existing_rig in oil_rigs:
					var existing_position: Vector3 = existing_rig["pos"]
					if Vector2(existing_position.x - candidate_x, existing_position.z - candidate_z).length() < 32.0:
						clear = false
						break
				if clear:
					chosen_position = Vector3(candidate_x, WATER_LEVEL, candidate_z)
					site_found = true
					break
			if site_found:
				break
		if not site_found:
			continue
		var owner_city: int = -1
		var nearest_distance: float = INF
		for city_id in range(cities.size()):
			var city_position: Vector3 = cities[city_id]["pos"]
			var distance_to_city: float = Vector2(city_position.x - chosen_position.x, city_position.z - chosen_position.z).length()
			if distance_to_city < nearest_distance:
				nearest_distance = distance_to_city
				owner_city = city_id
		var node: Node3D = _create_oil_rig_visual(chosen_position)
		oil_rigs.append({"node": node, "pos": chosen_position, "owner_city": owner_city, "reserves": randf_range(800.0, 1800.0), "production": randf_range(0.28, 0.72), "health": 100.0})
		created += 1
	_log("OIL DISCOVERY: %d offshore oil rigs were placed in navigable waters. Control brings revenue; wars can change ownership." % created)


func _update_oil_rigs() -> void:
	for rig_index in range(oil_rigs.size()):
		var rig: Dictionary = oil_rigs[rig_index]
		if float(rig.get("reserves", 0.0)) <= 0.0 or float(rig.get("health", 100.0)) <= 0.0:
			continue
		var owner_city: int = int(rig.get("owner_city", -1))
		var rig_position: Vector3 = rig["pos"]
		var hostile_source: int = -1
		var hostile_distance_squared: float = 15.0 * 15.0
		for army in armies:
			if not bool(army.get("alive", true)) or bool(army.get("is_defender", false)):
				continue
			var source_id: int = int(army.get("source", -1))
			if source_id < 0 or source_id >= cities.size() or owner_city < 0 or owner_city >= cities.size():
				continue
			if _same_faction(source_id, owner_city) or not _are_at_war(source_id, owner_city):
				continue
			var unit_position: Vector3 = army["pos"]
			var dx: float = unit_position.x - rig_position.x
			var dz: float = unit_position.z - rig_position.z
			var distance_squared: float = dx * dx + dz * dz
			if distance_squared < hostile_distance_squared:
				hostile_distance_squared = distance_squared
				hostile_source = source_id
		if hostile_source >= 0:
			rig["owner_city"] = hostile_source
			rig["health"] = maxf(25.0, float(rig.get("health", 100.0)) - 18.0)
			if owner_city >= 0 and owner_city < cities.size():
				_adjust_city_relation(owner_city, hostile_source, -18.0)
				_log("OIL RIG SEIZED: %s forces captured an offshore platform from %s. Production and its revenue have changed hands." % [cities[hostile_source]["name"], cities[owner_city]["name"]])
		owner_city = int(rig.get("owner_city", -1))
		if owner_city >= 0 and owner_city < cities.size() and float(rig.get("reserves", 0.0)) > 0.0 and float(rig.get("health", 100.0)) > 0.0:
			var income: float = float(rig.get("production", 0.5))
			if _city_population(owner_city) > 0 and not bool(cities[owner_city].get("ruined", false)):
				cities[owner_city]["treasury"] = minf(5000.0, float(cities[owner_city].get("treasury", 0.0)) + income)
			rig["reserves"] = maxf(0.0, float(rig.get("reserves", 0.0)) - income * 0.7)
		oil_rigs[rig_index] = rig


func _spawn_transport_wave() -> void:
	if transports.size() >= MAX_TRANSPORTS or cities.size() < 2:
		return
	var kind: String = "air" if randf() < 0.62 else "sea"
	var eligible: Array[int] = []
	for city_id in range(cities.size()):
		if kind == "air" and _world_year() >= 1945 and is_instance_valid(cities[city_id].get("airport")):
			eligible.append(city_id)
		elif kind == "sea" and _world_year() >= 1450 and is_instance_valid(cities[city_id].get("seaport")):
			eligible.append(city_id)
	if eligible.size() < 2:
		# Try the other transport mode before giving up this spawn cycle.
		kind = "sea" if kind == "air" else "air"
		eligible.clear()
		for city_id in range(cities.size()):
			if kind == "air" and _world_year() >= 1945 and is_instance_valid(cities[city_id].get("airport")):
				eligible.append(city_id)
			elif kind == "sea" and _world_year() >= 1450 and is_instance_valid(cities[city_id].get("seaport")):
				eligible.append(city_id)
	if eligible.size() < 2:
		return
	var source_id: int = eligible[randi_range(0, eligible.size() - 1)]
	var target_id: int = -1
	var target_distance: float = INF
	for candidate_id in eligible:
		if candidate_id == source_id or _are_at_war(source_id, candidate_id):
			continue
		var a: Vector3 = cities[source_id]["pos"]
		var b: Vector3 = cities[candidate_id]["pos"]
		var distance: float = Vector2(a.x - b.x, a.z - b.z).length()
		if distance < target_distance:
			target_distance = distance
			target_id = candidate_id
	if target_id >= 0:
		_spawn_transport(source_id, target_id, kind)


func _create_transport_node(kind: String) -> Node3D:
	var vehicle := Node3D.new()
	vehicle.name = "Airliner" if kind == "air" else "CargoShip"
	if kind == "air":
		_add_mesh(vehicle, _cached_box_mesh(Vector3(0.78, 0.48, 4.4)), _material(Color(0.80, 0.83, 0.82)), Vector3.ZERO)
		_add_mesh(vehicle, _cached_box_mesh(Vector3(5.0, 0.14, 0.82)), _material(Color(0.77, 0.79, 0.76)), Vector3(0.0, -0.02, 0.1))
		_add_mesh(vehicle, _cached_box_mesh(Vector3(1.8, 0.12, 0.48)), _material(Color(0.70, 0.73, 0.71)), Vector3(0.0, 0.08, -1.72))
		_add_mesh(vehicle, _cached_box_mesh(Vector3(0.16, 0.68, 0.5)), _material(Color(0.21, 0.37, 0.51)), Vector3(0.0, 0.38, -1.80))
		_add_mesh(vehicle, _cached_box_mesh(Vector3(0.08, 0.10, 0.25)), _material(Color(0.19, 0.50, 0.74)), Vector3(0.0, -0.03, -0.4))
	else:
		_add_mesh(vehicle, _cached_box_mesh(Vector3(2.9, 0.72, 6.2)), _material(Color(0.18, 0.27, 0.34)), Vector3(0.0, 0.1, 0.0))
		_add_mesh(vehicle, _cached_box_mesh(Vector3(2.2, 0.85, 3.6)), _material(Color(0.74, 0.76, 0.71)), Vector3(0.0, 0.78, -0.4))
		for container_index in range(3):
			var container := BoxMesh.new()
			container.size = Vector3(0.68, 0.8, 1.45)
			var container_color: Color = [Color(0.74, 0.25, 0.16), Color(0.17, 0.40, 0.62), Color(0.81, 0.66, 0.22)][container_index]
			_add_mesh(vehicle, container, _material(container_color), Vector3((float(container_index) - 1.0) * 0.75, 1.55, 1.05))
	return vehicle


func _spawn_transport(source_id: int, target_id: int, kind: String) -> void:
	if source_id < 0 or target_id < 0 or source_id >= cities.size() or target_id >= cities.size() or transports.size() >= MAX_TRANSPORTS:
		return
	var source_facility: Node3D = cities[source_id].get("airport" if kind == "air" else "seaport") as Node3D
	var target_facility: Node3D = cities[target_id].get("airport" if kind == "air" else "seaport") as Node3D
	if not is_instance_valid(source_facility) or not is_instance_valid(target_facility):
		return
	var start: Vector3 = source_facility.global_position
	var finish: Vector3 = target_facility.global_position
	if kind == "air":
		start.y += 2.0
		finish.y += 2.0
	else:
		start += source_facility.global_transform.basis.z.normalized() * 9.0 + Vector3(0.0, 0.7, 0.0)
		finish += target_facility.global_transform.basis.z.normalized() * 9.0 + Vector3(0.0, 0.7, 0.0)
	var vehicle: Node3D = _create_transport_node(kind)
	vehicle.position = start
	add_child(vehicle)
	var incident: String = "none"
	if kind == "air":
		var roll: float = randf()
		if roll < 0.018:
			incident = "crash"
		elif roll < 0.036:
			incident = "hijack"
	transports.append({"node": vehicle, "kind": kind, "from": source_id, "to": target_id, "start": start, "finish": finish, "pos": start, "progress": 0.0, "duration": clampf(Vector2(start.x - finish.x, start.z - finish.z).length() / (24.0 if kind == "air" else 7.0), 12.0, 45.0), "incident": incident})


func _update_transports(delta: float) -> void:
	for transport_index in range(transports.size() - 1, -1, -1):
		var transport: Dictionary = transports[transport_index]
		var node: Node3D = transport.get("node") as Node3D
		if not is_instance_valid(node):
			transports.remove_at(transport_index)
			continue
		var progress: float = clampf(float(transport.get("progress", 0.0)) + delta / float(transport.get("duration", 20.0)), 0.0, 1.0)
		var start: Vector3 = transport["start"]
		var finish: Vector3 = transport["finish"]
		var kind: String = str(transport.get("kind", "air"))
		var position: Vector3 = start.lerp(finish, progress)
		if kind == "air":
			position.y += sin(progress * PI) * 18.0
		else:
			position.y = WATER_LEVEL + 0.65
		var direction: Vector3 = finish - start
		if direction.length_squared() > 0.1:
			node.look_at(position + direction.normalized(), Vector3.UP)
		node.position = position
		node.visible = camera_distance < 570.0 or Vector2(position.x - camera_target.x, position.z - camera_target.z).length() < camera_distance * 0.85
		transport["progress"] = progress
		transport["pos"] = position
		if progress >= 1.0:
			var source_id: int = int(transport.get("from", -1))
			var target_id: int = int(transport.get("to", -1))
			var incident: String = str(transport.get("incident", "none"))
			if kind == "air" and target_id >= 0 and target_id < cities.size() and incident == "crash":
				_log("AIR DISASTER: A civilian aircraft crashed near %s. Emergency services are responding." % cities[target_id]["name"])
				_record_city_event(target_id, "PLANE CRASH", Color(1.0, 0.28, 0.12))
				_power_damage(position, 5.2, 4, 0.15, 1, false)
			elif kind == "air" and target_id >= 0 and target_id < cities.size() and incident == "hijack":
				cities[target_id]["stability"] = maxf(0.0, float(cities[target_id].get("stability", 72.0)) - 8.0)
				cities[target_id]["security"] = maxf(0.0, float(cities[target_id].get("security", 44.0)) - 12.0)
				cities[target_id]["treasury"] = maxf(0.0, float(cities[target_id].get("treasury", 0.0)) - 5.0)
				_log("AIR HIJACKING: An aircraft bound for %s was seized. Security is tightened and negotiators are involved." % cities[target_id]["name"])
				_record_city_event(target_id, "AIR HIJACK", Color(1.0, 0.18, 0.12))
			elif kind == "sea" and source_id >= 0 and target_id >= 0 and _are_at_war(source_id, target_id):
				_log("BLOCKADE: A cargo ship travelling between %s and %s was intercepted by the wartime blockade." % [cities[source_id]["name"], cities[target_id]["name"]])
				_adjust_city_relation(source_id, target_id, -2.5)
			if kind == "air" and incident == "crash" and target_id >= 0 and target_id < cities.size():
				pass
			if is_instance_valid(node):
				node.queue_free()
			transports.remove_at(transport_index)
		else:
			transports[transport_index] = transport


func _capture_city_hostages(city_id: int, captor_city_id: int, maximum: int = 2) -> int:
	if city_id < 0 or captor_city_id < 0 or city_id >= cities.size() or captor_city_id >= cities.size() or maximum <= 0:
		return 0
	var city: Dictionary = cities[city_id]
	if float(city.get("hostage_cooldown", 0.0)) > 0.0:
		return 0
	var already_held: int = int(city.get("hostage_count", 0))
	var available: int = mini(maximum, maxi(0, 4 - already_held))
	if available <= 0:
		return 0
	var taken: int = 0
	var city_position: Vector3 = city["pos"]
	for person_index in range(people.size()):
		if taken >= available:
			break
		var person: Dictionary = people[person_index]
		if int(person.get("city_id", -1)) != city_id or str(person.get("activity", "wandering")) in ["hostage", "indoors", "riding", "boarding"]:
			continue
		var person_position: Vector3 = person["pos"]
		if Vector2(person_position.x - city_position.x, person_position.z - city_position.z).length() > 42.0:
			continue
		person["activity"] = "hostage"
		person["hostage_home_city"] = city_id
		person["hostage_captor"] = captor_city_id
		person["hostage_timer"] = randf_range(18.0, 34.0)
		person["hostage_offset"] = Vector3(randf_range(1.0, 2.6), 0.0, randf_range(1.0, 2.7))
		person["pos"] = person_position
		people[person_index] = person
		taken += 1
	if taken > 0:
		city["hostage_count"] = already_held + taken
		city["hostage_cooldown"] = 20.0
		city["stability"] = maxf(0.0, float(city.get("stability", 72.0)) - float(taken) * 2.8)
		cities[city_id] = city
		_adjust_city_relation(city_id, captor_city_id, -float(taken) * 5.0)
		_log("HOSTAGES: %s forces seized %d civilian(s) in %s to pressure its leadership." % [cities[captor_city_id]["name"], taken, city["name"]])
	return taken


func _update_hostages(delta: float) -> void:
	for person_index in range(people.size()):
		var person: Dictionary = people[person_index]
		if str(person.get("activity", "")) != "hostage":
			continue
		var home_city: int = int(person.get("hostage_home_city", person.get("city_id", -1)))
		var captor_city: int = int(person.get("hostage_captor", -1))
		var timer: float = float(person.get("hostage_timer", 0.0)) - delta
		var escort_index: int = -1
		var nearest_distance_squared: float = 65.0 * 65.0
		for army_index in range(armies.size()):
			var army: Dictionary = armies[army_index]
			if not bool(army.get("alive", true)) or bool(army.get("is_defender", false)):
				continue
			if int(army.get("source", -1)) != captor_city or int(army.get("target", -1)) != home_city:
				continue
			if str(army.get("unit_type", "infantry")) not in ["infantry", "tank", "apc"]:
				continue
			var army_pos: Vector3 = army["pos"]
			var person_pos: Vector3 = person["pos"]
			var dx: float = army_pos.x - person_pos.x
			var dz: float = army_pos.z - person_pos.z
			var distance_squared: float = dx * dx + dz * dz
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				escort_index = army_index
		var release: bool = timer <= 0.0 or home_city < 0 or home_city >= cities.size() or captor_city < 0 or captor_city >= cities.size() or not _are_at_war(home_city, captor_city)
		if escort_index < 0 and timer <= 8.0:
			release = true
		if release:
			if home_city >= 0 and home_city < cities.size():
				cities[home_city]["hostage_count"] = maxi(0, int(cities[home_city].get("hostage_count", 0)) - 1)
			var released_position: Vector3 = person["pos"]
			if home_city >= 0 and home_city < cities.size():
				released_position = _surface_position(cities[home_city]["pos"].x + randf_range(-7.0, 7.0), cities[home_city]["pos"].z + randf_range(-7.0, 7.0))
			person["activity"] = "wandering"
			person["hostage_timer"] = 0.0
			person["hostage_captor"] = -1
			person["pos"] = released_position
			person["target"] = released_position
			person["walk_timer"] = 0.0
			if is_instance_valid(person.get("node") as Node3D):
				(person["node"] as Node3D).position = released_position
				(person["node"] as Node3D).visible = true
		else:
			person["hostage_timer"] = timer
			var army: Dictionary = armies[escort_index]
			var escort_position: Vector3 = army["pos"]
			var offset: Vector3 = person.get("hostage_offset", Vector3(1.5, 0.0, 1.8))
			var hostage_position: Vector3 = escort_position + offset
			hostage_position.y = _height_at(hostage_position.x, hostage_position.z)
			person["pos"] = hostage_position
			if is_instance_valid(person.get("node") as Node3D):
				(person["node"] as Node3D).position = hostage_position
				(person["node"] as Node3D).visible = true
		people[person_index] = person
	for city_id in range(cities.size()):
		cities[city_id]["hostage_cooldown"] = maxf(0.0, float(cities[city_id].get("hostage_cooldown", 0.0)) - delta)

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
	var lights_available: bool = year >= 1900
	var lights_transitioned: bool = lights_available != traffic_lights_enabled
	if not force and era == last_architecture_era and not lights_transitioned:
		return
	var previous_era: int = last_architecture_era
	last_architecture_era = era
	traffic_lights_enabled = lights_available
	for city_id in range(cities.size()):
		_apply_building_era_appearance(city_id, year)
		_ensure_city_infrastructure(city_id, year)
		# The street plan evolves too: diagonal avenues and broad arterials appear
		# as the city enters later eras, rather than waiting for its next house.
		if lights_transitioned or force or era != previous_era:
			if in_simulation_frame:
				_queue_city_roads_rebuild(city_id)
			else:
				_rebuild_city_roads(city_id)
	if previous_era >= 0 and era > previous_era:
		_log("HISTORICAL SHIFT: %s begins in year %d. Cities can now develop new architecture and social events." % [_historical_era_name(year), year])


func _format_time(seconds: float) -> String:
	var total_seconds: int = int(seconds)
	var minutes: int = int(total_seconds / 60)
	var remainder: int = total_seconds % 60
	return "%02d:%02d" % [minutes, remainder]
