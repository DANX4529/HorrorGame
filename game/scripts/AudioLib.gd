extends Node
## Lecture audio : pool de lecteurs 3D + lecteurs 2D dédiés aux boucles.

const DIR := "res://assets/audio/"
const POOL_3D := 24

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.max_distance = 30.0
		p.unit_size = 3.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool.append(p)


func stream(name: String, loop := false) -> AudioStream:
	var key := name + ("_l" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var s := load(DIR + name + ".wav") as AudioStreamWAV
	if s == null:
		push_warning("Son introuvable : " + name)
		return null
	if loop:
		# les .wav importés n'ont pas de boucle : on la pose ici, sur une copie
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = 0
	_cache[key] = s
	return s


## Son ponctuel positionné dans le monde.
func play_3d(name: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_3D
	p.stream = s
	p.global_position = pos
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## Son ponctuel non positionné (interface, respiration du joueur).
func play_2d(name: String, db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var s := stream(name)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Crée un lecteur bouclé persistant (ambiance, respiration, coeur).
func make_loop(name: String, db := -12.0, bus := "SFX") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = stream(name, true)
	p.volume_db = db
	add_child(p)
	return p
