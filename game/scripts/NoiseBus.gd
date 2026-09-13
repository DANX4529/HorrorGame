extends Node
## Bus sonore — la mécanique centrale de RESPIRE.
##
## Tout ce qui fait du bruit dans le jeu passe par ici. La Veilleuse est
## aveugle : ce bus est sa seule perception du monde. Le rayon exprime la
## distance à laquelle le bruit reste audible pour elle, en mètres.

signal noise(pos: Vector3, radius: float, kind: String)

## Rayons de référence (mètres). Ils sont la table d'équilibrage du jeu.
const R := {
	"pas_accroupi":     3.0,
	"pas_marche":       8.0,
	"pas_course":      18.0,
	"souffle_calme":    4.0,
	"souffle_essouffle": 11.0,
	"souffle_apnee":    0.8,
	"halètement":      22.0,
	"porte":           12.0,
	"casier":          10.0,
	"objet":           16.0,
	"lampe":            2.0,
	"fusible":          9.0,
	"courant":         40.0,
}

var last: Array = []            # historique court, utile au débogage / HUD


func emit_noise(pos: Vector3, radius: float, kind := "") -> void:
	if radius <= 0.0:
		return
	noise.emit(pos, radius, kind)
	last.append({"pos": pos, "r": radius, "kind": kind, "t": Time.get_ticks_msec()})
	if last.size() > 24:
		last.pop_front()


func emit_kind(pos: Vector3, kind: String, scale := 1.0) -> void:
	emit_noise(pos, R.get(kind, 5.0) * scale, kind)
