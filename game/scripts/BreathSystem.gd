class_name BreathSystem
extends RefCounted
## Le système de souffle : la ressource unique autour de laquelle tourne RESPIRE.
##
## Boucle de tension :
##   courir sauve l'instant présent mais laisse ESSOUFFLÉ (donc bruyant)
##   pendant plusieurs secondes ; l'apnée rend silencieux mais vide le souffle,
##   et un souffle à zéro déclenche un HALÈTEMENT — le bruit le plus fort du jeu.
##
## Boucle de peur (rétroaction négative volontaire) :
##   plus la Veilleuse est proche, plus le coeur s'emballe, plus l'apnée est
##   courte. Avoir peur rend objectivement le jeu plus difficile.

enum State { NORMAL, APNEE, ESSOUFFLE, HALETEMENT }

signal gasped                       ## le souffle est tombé à zéro en apnée
signal state_changed(s: State)

const REGEN_IMMOBILE := 0.30
const REGEN_MARCHE   := 0.20
const DRAIN_COURSE   := 0.235
const DRAIN_APNEE    := 0.330       ## +30 % au maximum de la peur
const SEUIL_ESSOUFFLE := 0.34       ## en dessous : on passe essoufflé
const SORTIE_ESSOUFFLE := 0.63      ## au-dessus : on récupère
const BLOCAGE_APRES_HALETEMENT := 4.0

var breath := 1.0                   ## 0..1
var heart := 0.0                    ## 0..1, monte avec la peur
var state: State = State.NORMAL
var hold_lock := 0.0                ## secondes restantes d'interdiction d'apnée
var _prev_state: State = State.NORMAL


func update(delta: float, wants_hold: bool, sprinting: bool, moving: bool,
		crouched: bool, fear_target: float) -> void:
	# --- rythme cardiaque : monte vite, redescend lentement ---
	var rise := 2.2 if fear_target > heart else 0.32
	heart = move_toward(heart, clampf(fear_target, 0.0, 1.0), delta * rise * 0.6)

	if hold_lock > 0.0:
		hold_lock = maxf(0.0, hold_lock - delta)

	var holding := wants_hold and hold_lock <= 0.0 and breath > 0.0

	if holding:
		breath -= delta * DRAIN_APNEE * (1.0 + heart * 0.30)
		if breath <= 0.0:
			breath = 0.14
			hold_lock = BLOCAGE_APRES_HALETEMENT
			_goto(State.HALETEMENT)
			gasped.emit()
	elif sprinting and moving:
		breath -= delta * DRAIN_COURSE * (1.0 + heart * 0.22)
	else:
		var regen := REGEN_IMMOBILE if (not moving or crouched) else REGEN_MARCHE
		# on récupère mal quand le coeur bat fort
		breath += delta * regen * (1.0 - heart * 0.35)

	breath = clampf(breath, 0.0, 1.0)

	# --- machine à états ---
	if state == State.HALETEMENT:
		if hold_lock <= BLOCAGE_APRES_HALETEMENT - 1.1:
			_goto(State.ESSOUFFLE)
	elif holding:
		_goto(State.APNEE)
	elif state == State.ESSOUFFLE:
		if breath >= SORTIE_ESSOUFFLE:
			_goto(State.NORMAL)
	elif breath <= SEUIL_ESSOUFFLE:
		_goto(State.ESSOUFFLE)
	else:
		_goto(State.NORMAL)


func _goto(s: State) -> void:
	if state != s:
		state = s
		state_changed.emit(s)


## Rayon audible de la respiration, en mètres — ce que la Veilleuse perçoit.
func noise_radius() -> float:
	match state:
		State.APNEE:
			return NoiseBus.R["souffle_apnee"]
		State.HALETEMENT:
			return NoiseBus.R["halètement"]
		State.ESSOUFFLE:
			return NoiseBus.R["souffle_essouffle"]
		_:
			# un souffle bas est déjà plus audible même hors état « essoufflé »
			return lerpf(NoiseBus.R["souffle_calme"], 7.0, 1.0 - breath)
	return 4.0


func can_hold() -> bool:
	return hold_lock <= 0.0 and breath > 0.02


func label() -> String:
	match state:
		State.APNEE: return "APNÉE"
		State.ESSOUFFLE: return "ESSOUFFLÉ"
		State.HALETEMENT: return "HALÈTEMENT"
		_: return ""
