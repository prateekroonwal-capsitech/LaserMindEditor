extends RefCounted
class_name StageTransitioner

var is_transitioning: bool = false
var _cam_tween: Tween = null

func is_active() -> bool:
	return is_transitioning

func stop() -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	is_transitioning = false

func transition(
	host: Node,
	slide_dir: LaserStageData.TransitionDir,
	current_origin: Vector2,
	target_origin: Vector2,
	vp_size: Vector2,
	on_update_origin: Callable,
	on_midway: Callable,
	on_complete: Callable
) -> void:
	if is_transitioning:
		return

	stop()
	is_transitioning = true

	var offscreen_offset := get_offscreen_offset(slide_dir, vp_size)

	_cam_tween = host.create_tween()
	_cam_tween.set_ease(Tween.EASE_IN_OUT)
	_cam_tween.set_trans(Tween.TRANS_CUBIC)

	if slide_dir == LaserStageData.TransitionDir.NONE:
		_cam_tween.tween_method(on_update_origin, current_origin, target_origin, 0.55)
		_cam_tween.tween_callback(func():
			is_transitioning = false
			if on_complete.is_valid():
				on_complete.call()
		)
	else:
		var exit_target := current_origin - offscreen_offset
		_cam_tween.tween_method(on_update_origin, current_origin, exit_target, 0.3)

		_cam_tween.tween_callback(func():
			if on_midway.is_valid():
				on_midway.call()
			var enter_start := target_origin + offscreen_offset
			if on_update_origin.is_valid():
				on_update_origin.call(enter_start)
		)

		_cam_tween.tween_method(on_update_origin, target_origin + offscreen_offset, target_origin, 0.45)
		_cam_tween.tween_callback(func():
			is_transitioning = false
			if on_complete.is_valid():
				on_complete.call()
		)

static func get_offscreen_offset(dir: LaserStageData.TransitionDir, vp_size: Vector2) -> Vector2:
	match dir:
		LaserStageData.TransitionDir.LEFT:
			return Vector2(-vp_size.x * 1.1, 0)
		LaserStageData.TransitionDir.RIGHT:
			return Vector2(vp_size.x * 1.1, 0)
		LaserStageData.TransitionDir.UP:
			return Vector2(0, -vp_size.y * 1.1)
		LaserStageData.TransitionDir.DOWN:
			return Vector2(0, vp_size.y * 1.1)
		_:
			return Vector2.ZERO
