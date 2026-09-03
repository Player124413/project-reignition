extends Node
## Auto-detects device performance and applies optimal settings.
##
## Runs at startup on Android. Uses CPU core count + RAM size to
## determine device tier (Low/Mid/High) and adjusts:
## - Render scale (resolution)
## - Shadow quality
## - Post-processing effects
## - Texture quality hint
## - Target FPS
## - Physics tickrate (on very low-end)

class_name MobilePerformanceManager

enum DeviceTier { LOW, MEDIUM, HIGH, FLAGSHIP }

var device_tier: DeviceTier = DeviceTier.MEDIUM
var is_initialized: bool = false

# Detection results
var cpu_cores: int = 0
var total_ram_mb: int = 0
var gpu_name: String = ""

# Applied settings (readable from anywhere)
var render_scale: float = 1.0
var shadow_quality: int = 1  # 0=low, 1=med, 2=high
var effects_quality: int = 1
var target_fps: int = 60

signal performance_profile_applied(tier: DeviceTier)

func _ready() -> void:
	if not OS.has_feature("android") and not OS.has_feature("mobile"):
		return
	
	process_mode = PROCESS_MODE_ALWAYS
	
	# Wait a frame so the engine is ready
	await get_tree().process_frame
	
	_detect_hardware()
	_determine_tier()
	_apply_settings()
	is_initialized = true

func _detect_hardware() -> void:
	# CPU cores (using available threads)
	cpu_cores = OS.get_processor_count()
	
	# RAM — try system info first, fallback to heuristics
	if OS.has_feature("android"):
		var proc_info := _read_proc_meminfo()
		if proc_info > 0:
			total_ram_mb = proc_info
		else:
			# Heuristic based on CPU cores + Android version
			total_ram_mb = _guess_ram()
	else:
		total_ram_mb = 2048  # Safe fallback
	
	# GPU — Godot doesn't expose GPU name easily, use features
	gpu_name = RenderingServer.get_video_adapter_name()
	if gpu_name.is_empty():
		gpu_name = "Unknown"

func _read_proc_meminfo() -> int:
	var file := FileAccess.open("/proc/meminfo", FileAccess.READ)
	if file == null:
		return 0
	
	var content := file.get_as_text()
	file.close()
	
	# Find MemTotal line
	for line in content.split("\n"):
		if line.begins_with("MemTotal:"):
			# Format: "MemTotal:        XX kB"
			var parts := line.split(" ", false)
			for p in parts:
				if p.is_valid_int():
					return int(p) / 1024  # kB → MB
	return 0

func _guess_ram() -> int:
	if cpu_cores >= 8:
		return 6144
	elif cpu_cores >= 6:
		return 4096
	elif cpu_cores >= 4:
		return 3072
	return 2048

func _determine_tier() -> void:
	var is_modern_gpu := gpu_name.contains("Mali-G") or gpu_name.contains("Adreno 6") or gpu_name.contains("Adreno 7") or gpu_name.contains("Adreno 8")
	var is_mid_gpu := gpu_name.contains("Adreno 5") or gpu_name.contains("Mali-T")
	var is_old_gpu := gpu_name.contains("PowerVR") or gpu_name.contains("Mali-4")
	
	# Flagship tier
	if cpu_cores >= 8 and total_ram_mb >= 6144 and is_modern_gpu:
		device_tier = DeviceTier.FLAGSHIP
	# High tier
	elif cpu_cores >= 6 and total_ram_mb >= 4096 and (is_modern_gpu or is_mid_gpu):
		device_tier = DeviceTier.HIGH
	# Medium tier
	elif cpu_cores >= 4 and total_ram_mb >= 2048:
		device_tier = DeviceTier.MEDIUM
	# Low tier
	else:
		device_tier = DeviceTier.LOW
	
	# Override: if GPU looks very old, drop one tier
	if is_old_gpu and device_tier > DeviceTier.LOW:
		device_tier = maxi(int(device_tier) - 1, int(DeviceTier.LOW))
	
	# Log result
	print("MobilePerformance: CPU=" + str(cpu_cores) + " RAM=" + str(total_ram_mb) + "MB GPU=" + gpu_name + " → Tier=" + _tier_name())

func _tier_name() -> String:
	match device_tier:
		DeviceTier.LOW: return "LOW"
		DeviceTier.MEDIUM: return "MEDIUM"
		DeviceTier.HIGH: return "HIGH"
		DeviceTier.FLAGSHIP: return "FLAGSHIP"
	return "UNKNOWN"

func _apply_settings() -> void:
	match device_tier:
		DeviceTier.LOW:
			render_scale = 0.65
			shadow_quality = 0
			effects_quality = 0
			target_fps = 30
			
		DeviceTier.MEDIUM:
			render_scale = 0.75
			shadow_quality = 1
			effects_quality = 1
			target_fps = 60
			
		DeviceTier.HIGH:
			render_scale = 0.85
			shadow_quality = 1
			effects_quality = 1
			target_fps = 60
			
		DeviceTier.FLAGSHIP:
			render_scale = 1.0
			shadow_quality = 2
			effects_quality = 2
			target_fps = 60
	
	_apply_render_scale()
	_apply_shadows()
	_apply_effects()
	_apply_fps()
	
	performance_profile_applied.emit(device_tier)

func _apply_render_scale() -> void:
	if render_scale < 1.0:
		# Use XR scaling for better performance
		var vp := get_viewport()
		if vp:
			vp.scaling_3d_scale = render_scale
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR  # Fastest
			# Enable FSR upscaling for quality
			if render_scale >= 0.6 and device_tier >= DeviceTier.MEDIUM:
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		print("MobilePerformance: Render scale set to " + str(render_scale))

func _apply_shadows() -> void:
	match shadow_quality:
		0:  # Low — minimal shadows
			RenderingServer.directional_shadow_atlas_set_size(512, false)
			RenderingServer.viewport_set_positional_shadow_atlas_size(get_viewport().get_viewport_rid(), 1024, false)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			
		1:  # Medium
			RenderingServer.directional_shadow_atlas_set_size(1024, false)
			RenderingServer.viewport_set_positional_shadow_atlas_size(get_viewport().get_viewport_rid(), 2048, false)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			
		2:  # High
			RenderingServer.directional_shadow_atlas_set_size(2048, false)
			RenderingServer.viewport_set_positional_shadow_atlas_size(get_viewport().get_viewport_rid(), 4096, false)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)

func _apply_effects() -> void:
	var vp_rid := get_viewport().get_viewport_rid()
	
	match effects_quality:
		0:  # Low — disable expensive effects
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, false, 0.25, 0, 8, 16)
			RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, false, 0.25, 0, 8, 16)
			# Disable glow/bllom entirely on very low
			var env: Environment = get_viewport().get_environment()
			if env:
				env.glow_enabled = false
			
		1:  # Medium
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_2X)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 0, 20, 50)
			RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 0, 20, 50)
			
		2:  # High
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_2X)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 1, 50, 100)
			RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 1, 50, 100)

func _apply_fps() -> void:
	Engine.max_fps = target_fps
	if target_fps <= 30:
		# On very low end, also reduce physics ticks slightly for CPU
		Engine.physics_ticks_per_second = 45
	print("MobilePerformance: Target FPS set to " + str(target_fps))

func get_tier_name() -> String:
	return _tier_name()

func is_low_end() -> bool:
	return device_tier <= DeviceTier.LOW

func is_medium_end() -> bool:
	return device_tier <= DeviceTier.MEDIUM

func get_render_quality_label() -> String:
	match device_tier:
		DeviceTier.LOW: return "Low"
		DeviceTier.MEDIUM: return "Medium"
		DeviceTier.HIGH: return "High"
		DeviceTier.FLAGSHIP: return "Ultra"
	return "Auto"