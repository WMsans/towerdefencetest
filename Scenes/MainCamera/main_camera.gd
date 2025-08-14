extends Camera2D

# -- Panning --
@export var drag_speed: float = 1.0

# -- Zooming --
@export var zoom_step: float = 0.15
@export_range(0.05, 8.0, 0.01) var min_zoom: float = 0.5
@export_range(0.05, 8.0, 0.01) var max_zoom: float = 4.0

# -- Zoom Smoothing --
@export_group("Zoom Smoothing", "zoom_")
@export var zoom_smoothing_speed: float = 8.0

# -- Inertia --
@export_group("Inertia", "inertia_")
@export var inertia_damping: float = 6.0
@export var inertia_max_throw_speed: float = 4000.0
@export var inertia_stop_speed: float = 5.0
@export var inertia_throw_window: float = 0.12


## --- PRIVATE VARIABLES ---
var _is_panning: bool = false
var _pan_velocity: Vector2 = Vector2.ZERO

var _prev_pos: Vector2 = Vector2.ZERO
var _smoothed_drag_vel: Vector2 = Vector2.ZERO
var _velocity_samples: Array = []

var _target_zoom: Vector2 = Vector2.ONE

# (NEW) Stores the camera position change caused by zoom adjustment in a single frame.
var _zoom_pos_adjustment: Vector2 = Vector2.ZERO


func _ready() -> void:
	_prev_pos = position
	_target_zoom = zoom


func _unhandled_input(event: InputEvent) -> void:
	# --- Right-Click Panning ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_is_panning = event.is_pressed()
		
		if _is_panning:
			_pan_velocity = Vector2.ZERO
			_smoothed_drag_vel = Vector2.ZERO
			_velocity_samples.clear()
		else:
			_pan_velocity = _average_recent_velocity()
			_pan_velocity = _pan_velocity.limit_length(inertia_max_throw_speed)
			_velocity_samples.clear()

	# --- Drag Motion ---
	if event is InputEventMouseMotion and _is_panning:
		position -= event.relative / zoom * drag_speed

	# --- Mouse Wheel Zooming ---
	if event is InputEventMouseButton and event.is_pressed():
		var zoom_factor = 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_factor = 1.0 - zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = 1.0 + zoom_step
		
		if zoom_factor != 1.0:
			var new_target = _target_zoom * zoom_factor
			_target_zoom = clamp(new_target, Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))


func _process(delta: float) -> void:
	var dt = max(delta, 1e-6)
	
	# (MODIFIED) The order of operations is now critical.
	
	# 1. Reset the zoom adjustment and run the zoom handler first. This updates
	#    the camera's zoom and position, and stores the position change.
	_zoom_pos_adjustment = Vector2.ZERO
	_handle_smooth_zoom(dt)

	# 2. Calculate total position change since the last frame.
	var current_pos = position
	var total_pos_delta = current_pos - _prev_pos
	
	# 3. Isolate the drag-related change by subtracting the zoom adjustment.
	#    This gives us a "pure" drag velocity, untainted by the zoom logic.
	var drag_pos_delta = total_pos_delta - _zoom_pos_adjustment
	var drag_velocity = drag_pos_delta / dt
	_prev_pos = current_pos

	# 4. Use the pure drag velocity for inertia calculations.
	if _is_panning:
		_smoothed_drag_vel += (drag_velocity - _smoothed_drag_vel) * 0.5
		_add_velocity_sample(_smoothed_drag_vel)
	else:
		# The inertial slide is applied on top of the zoom-adjusted position.
		if _pan_velocity.length() > inertia_stop_speed:
			var new_pos = position + _pan_velocity * dt
			
			var result = _apply_limit_aware_clamp(new_pos, _pan_velocity)
			position = result[0]
			_pan_velocity = result[1]
			
			_pan_velocity *= exp(-inertia_damping * dt)
			
			if _pan_velocity.length() <= inertia_stop_speed:
				_pan_velocity = Vector2.ZERO
		else:
			_pan_velocity = Vector2.ZERO


## --- HELPER FUNCTIONS ---

func _handle_smooth_zoom(delta: float) -> void:
	if not zoom.is_equal_approx(_target_zoom):
		var world_before_zoom = get_global_mouse_position()
		
		var lerp_weight = 1.0 - exp(-zoom_smoothing_speed * delta)
		zoom = zoom.lerp(_target_zoom, lerp_weight)

		if zoom.is_equal_approx(_target_zoom):
			zoom = _target_zoom
		
		var world_after_zoom = get_global_mouse_position()
		
		# (MODIFIED) Store the adjustment before applying it.
		var adjustment = world_before_zoom - world_after_zoom
		_zoom_pos_adjustment = adjustment
		position += adjustment


func _add_velocity_sample(velocity: Vector2) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	_velocity_samples.push_back({"v": velocity, "t": now})
	
	while not _velocity_samples.is_empty() and now - _velocity_samples.front().t > inertia_throw_window:
		_velocity_samples.pop_front()


func _average_recent_velocity() -> Vector2:
	if _velocity_samples.is_empty():
		return Vector2.ZERO
	
	var sum_of_velocities = Vector2.ZERO
	for sample in _velocity_samples:
		sum_of_velocities += sample.v
	
	return sum_of_velocities / _velocity_samples.size()


func _apply_limit_aware_clamp(new_pos: Vector2, vel: Vector2) -> Array:
	var modified_pos = new_pos
	var modified_vel = vel
	
	var use_x_limits = limit_right > limit_left
	var use_y_limits = limit_bottom > limit_top
	
	if use_x_limits:
		var clamped_x = clamp(modified_pos.x, limit_left, limit_right)
		if not is_equal_approx(clamped_x, modified_pos.x):
			modified_vel.x = 0.0
			modified_pos.x = clamped_x
	
	if use_y_limits:
		var clamped_y = clamp(modified_pos.y, limit_top, limit_bottom)
		if not is_equal_approx(clamped_y, modified_pos.y):
			modified_vel.y = 0.0
			modified_pos.y = clamped_y
			
	return [modified_pos, modified_vel]
