extends Node
## Lecture audio : pool de lecteurs 3D + lecteurs 2D dédiés aux boucles.

const DIR := "res://assets/audio/"
const POOL_3D := 24
const POOL_ECHO := 8

## Volume de l'écho aux deux bouts de l'échelle de NoiseBus.portee().
const ECHO_DB_MIN := -28.0
const ECHO_DB_MAX := -7.0

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _echo: Array[AudioStreamPlayer3D] = []
var _next_echo := 0

## Dernier son non positionné joué. Sert au test de lisibilité : vérifier
## qu'une transition d'état émet bien son signal demande de pouvoir l'observer,
## et un signal muet est précisément le défaut qu'on cherche à empêcher.
var dernier_sting := ""


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
	for i in POOL_ECHO:
		var e := AudioStreamPlayer3D.new()
		e.bus = "Empreinte"
		# l'écho porte plus loin que la source : c'est tout l'intérêt
		e.max_distance = 45.0
		e.unit_size = 5.0
		e.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(e)
		_echo.append(e)


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
	dernier_sting = name
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
	dernier_sting = name
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


## Traduit un rayon sonore (mètres) en volume d'écho (dB).
## Renvoie -INF sous le seuil : il n'y a alors rien à jouer.
func echo_db(radius: float) -> float:
	var t := NoiseBus.portee(radius)
	if t <= 0.0:
		return -INF
	return lerpf(ECHO_DB_MIN, ECHO_DB_MAX, t)


## Renvoie au joueur le bruit qu'il vient de faire, tel que la pièce le renvoie.
##
## C'est le seul retour que le jeu donne sur sa mécanique centrale, et il est
## entièrement diégétique : pas de jauge, pas de chiffre. Le couloir répond
## d'autant plus fort que le bruit porte loin, donc le joueur apprend la table
## des rayons en la vivant — accroupi l'asile se tait, en courant il aboie.
func play_echo(name: String, pos: Vector3, radius: float, pitch := 1.0) -> void:
	var db := echo_db(radius)
	if db == -INF:
		return
	var s := stream(name)
	if s == null:
		return
	var p := _echo[_next_echo]
	_next_echo = (_next_echo + 1) % POOL_ECHO
	p.stream = s
	p.global_position = pos
	p.volume_db = db
	# l'écho est plus grave que la source : les aigus meurent dans les couloirs
	p.pitch_scale = pitch * 0.94
	p.play()


## Émet un bruit du monde : la perception de la Veilleuse, le son direct et
## l'écho de la pièce, tous trois dérivés du MÊME rayon.
##
## Regrouper les trois est délibéré. Tant qu'ils étaient appelés séparément,
## rien n'empêchait l'écho d'annoncer au joueur un bruit discret pendant que
## l'entité en entendait un tonitruant — le retour aurait menti. Ici la
## divergence est structurellement impossible.
func noise_3d(sample: String, pos: Vector3, kind: String, db := 0.0,
		pitch := 1.0, scale := 1.0) -> void:
	NoiseBus.emit_kind(pos, kind, scale)
	play_3d(sample, pos, db, pitch)
	play_echo(sample, pos, NoiseBus.R.get(kind, 5.0) * scale, pitch)
