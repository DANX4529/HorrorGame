extends Node
## Réglages du joueur : sensibilité, volumes, luminosité, difficulté.
##
## Persistés dans user://respire.cfg. Sur la version navigateur, `user://`
## est stocké par le navigateur lui-même : les réglages survivent au
## rafraîchissement de la page.

signal changed

const FICHIER := "user://respire.cfg"

# --- difficultés -----------------------------------------------------------
# Chaque palier agit sur trois leviers : ce qu'elle entend, sa vitesse, et la
# vitesse à laquelle le souffle se vide. On ne touche PAS au nombre de
# fusibles : la structure de la partie doit rester la même.
enum Diff { VEILLEUR, PATIENT, PENSIONNAIRE }

const DIFF_NOMS := ["Veilleur", "Patient", "Pensionnaire"]
const DIFF_DESC := [
	"Elle entend moins loin et se déplace lentement. Le souffle dure longtemps.",
	"L'équilibre prévu. Elle entend ce que vous entendez.",
	"Une ouïe fine, une démarche rapide, et un souffle qui ne pardonne pas.",
]
const DIFF_OUIE := [0.72, 1.0, 1.24]        # multiplicateur des rayons sonores
const DIFF_VITESSE := [0.86, 1.0, 1.12]     # multiplicateur de sa vitesse
const DIFF_SOUFFLE := [0.78, 1.0, 1.26]     # multiplicateur de consommation
const DIFF_BATTERIE := [1.35, 1.0, 0.80]    # multiplicateur d'autonomie de lampe

# --- valeurs --------------------------------------------------------------
var sensibilite := 0.40        # 0..1
var inverser_y := false
var vol_general := 0.80        # 0..1
var vol_effets := 1.00
var vol_ambiance := 0.85
var vol_souffle := 1.00
var vol_musique := 0.85
var luminosite := 0.50         # 0..1, 0.5 = neutre
var difficulte := int(Diff.PATIENT)

const DEFAUTS := {
	"sensibilite": 0.40, "inverser_y": false, "vol_general": 0.80,
	"vol_effets": 1.00, "vol_ambiance": 0.85, "vol_souffle": 1.00,
	"vol_musique": 0.85, "luminosite": 0.50, "difficulte": 1,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	charger()
	appliquer()


# --------------------------------------------------------------------------
func sensibilite_rad() -> float:
	"""Sensibilité souris en radians par pixel."""
	return lerpf(0.0007, 0.0048, clampf(sensibilite, 0.0, 1.0))


func ouie() -> float:
	return DIFF_OUIE[difficulte]


func vitesse_entite() -> float:
	return DIFF_VITESSE[difficulte]


func drain_souffle() -> float:
	return DIFF_SOUFFLE[difficulte]


func autonomie_lampe() -> float:
	return DIFF_BATTERIE[difficulte]


func nom_difficulte() -> String:
	return DIFF_NOMS[difficulte]


# --------------------------------------------------------------------------
func appliquer() -> void:
	_bus("Master", vol_general)
	_bus("SFX", vol_effets)
	_bus("Ambiance", vol_ambiance)
	_bus("Souffle", vol_souffle)
	_bus("Musique", vol_musique)
	changed.emit()


func _bus(nom: String, v: float) -> void:
	var i := AudioServer.get_bus_index(nom)
	if i < 0:
		return
	# 0 coupe réellement le son ; au-dessus, courbe perceptive
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(v, 0.0001, 1.0)))


## Correction de luminosité appliquée par le nuanceur de post-traitement.
func gamma() -> float:
	return lerpf(0.70, 1.55, clampf(luminosite, 0.0, 1.0))


# --------------------------------------------------------------------------
func charger() -> void:
	var c := ConfigFile.new()
	if c.load(FICHIER) != OK:
		return
	for k in DEFAUTS:
		var v = c.get_value("respire", k, DEFAUTS[k])
		if typeof(v) == typeof(DEFAUTS[k]) or (DEFAUTS[k] is float and v is int):
			set(k, v)
	difficulte = clampi(difficulte, 0, DIFF_NOMS.size() - 1)


func sauver() -> void:
	var c := ConfigFile.new()
	for k in DEFAUTS:
		c.set_value("respire", k, get(k))
	c.save(FICHIER)


func remettre_defauts() -> void:
	for k in DEFAUTS:
		set(k, DEFAUTS[k])
	appliquer()
	sauver()
