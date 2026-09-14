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

## Seuil et plafond de lisibilité, en mètres. En dessous du seuil, un bruit est
## une affaire privée : ni l'écho ni l'image n'en rendent compte (un pas
## accroupi porte 3 m). Au plafond, tout le couloir est au courant.
const LISIBLE_SEUIL := 5.0
const LISIBLE_PLAFOND := 22.0

var last: Array = []            # historique court, utile au débogage / HUD


## Traduit un rayon en « à quel point ce bruit est gros », de 0 à 1.
##
## Une seule définition pour tout le jeu : l'écho de la pièce et l'ouverture du
## vignettage y puisent tous les deux. Deux barèmes séparés auraient fini par
## diverger, et le joueur aurait vu une chose pendant qu'il en entendait une
## autre — le pire retour possible sur une mécanique qu'il doit apprendre.
##
## La courbe est accélérée : l'écart entre marcher et courir doit sauter aux
## sens, pas se diluer dans une rampe linéaire.
func portee(radius: float) -> float:
	if radius < LISIBLE_SEUIL:
		return 0.0
	return pow(clampf(inverse_lerp(LISIBLE_SEUIL, LISIBLE_PLAFOND, radius), 0.0, 1.0), 0.62)


func emit_noise(pos: Vector3, radius: float, kind := "") -> void:
	if radius <= 0.0:
		return
	noise.emit(pos, radius, kind)
	last.append({"pos": pos, "r": radius, "kind": kind, "t": Time.get_ticks_msec()})
	if last.size() > 24:
		last.pop_front()


func emit_kind(pos: Vector3, kind: String, scale := 1.0) -> void:
	emit_noise(pos, R.get(kind, 5.0) * scale, kind)
