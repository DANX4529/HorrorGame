extends Node
## Clignotement de tube fluorescent fatigué : longues périodes stables
## coupées de rafales de coupures. Le silence visuel rend la rafale efficace.

var _light: Light3D
var _base := 1.0
var _t := 0.0
var _next := 0.0
var _burst := 0.0


func setup(l: Light3D, base_energy: float) -> void:
	_light = l
	_base = base_energy
	_next = randf_range(1.5, 7.0)


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	if _burst > 0.0:
		_burst -= delta
		var on := randf() > 0.42
		_light.light_energy = _base * (randf_range(0.75, 1.1) if on else randf_range(0.0, 0.12))
		if _burst <= 0.0:
			_light.light_energy = _base
	elif _t >= _next:
		_t = 0.0
		_next = randf_range(2.5, 11.0)
		_burst = randf_range(0.12, 0.75)
	else:
		# léger ronflement permanent, à peine perceptible
		_light.light_energy = _base * (0.96 + 0.04 * sin(_t * 31.0))
