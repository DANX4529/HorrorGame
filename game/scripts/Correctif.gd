extends Node
## Charge le correctif téléchargé, AVANT tout le reste.
##
## Un correctif est une archive .pck qui ne contient que les fichiers modifiés
## depuis la version de base. Godot sait la superposer au jeu : les fichiers
## qu'elle contient remplacent ceux de l'exécutable, les autres restent.
##
## POURQUOI CET AUTOLOAD EST LE PREMIER DE LA LISTE. Godot instancie les
## autoloads dans l'ordre déclaré, et un script déjà chargé en mémoire ne se
## remplace plus. Chargé ici, le correctif est en place avant que Settings,
## GameState, Lore et les autres ne soient lus — sinon un correctif ne pourrait
## jamais toucher au cœur du jeu, c'est-à-dire à presque tout ce qu'on corrige.
##
## Rien de tout cela ne vaut pour le navigateur : la page est reconstruite à
## chaque visite, et il n'y a pas d'installation à rattraper.

const DOSSIER := "user://correctifs"
## Fichier qui nomme le correctif à charger. Le nom du .pck ne suffit pas :
## on veut aussi savoir de QUELLE version de base il part, pour refuser un
## correctif écrit pour une autre.
const MARQUEUR := "user://correctifs/installe.cfg"

var version_base := ""       ## la version gravée dans l'exécutable
var version_active := ""     ## ce qu'on joue réellement, correctif compris
var correctif_charge := ""


func _init() -> void:
	version_base = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version_active = version_base
	if OS.has_feature("web"):
		return
	_charger()


func _charger() -> void:
	var c := ConfigFile.new()
	if c.load(MARQUEUR) != OK:
		return
	var pour: String = str(c.get_value("correctif", "base", ""))
	var vers: String = str(c.get_value("correctif", "version", ""))
	var fichier: String = str(c.get_value("correctif", "fichier", ""))
	if fichier == "" or vers == "":
		return
	# Un correctif écrit pour une autre base remplacerait des fichiers par des
	# versions qui n'ont jamais tourné avec celle-ci. On préfère jouer sans.
	if pour != version_base:
		push_warning("Correctif ignoré : prévu pour la %s, l'exécutable est en %s"
				% [pour, version_base])
		return
	var chemin := DOSSIER.path_join(fichier)
	if not FileAccess.file_exists(chemin):
		push_warning("Correctif introuvable : %s" % chemin)
		return
	if not ProjectSettings.load_resource_pack(chemin, true):
		push_warning("Correctif illisible : %s" % chemin)
		return
	correctif_charge = fichier
	version_active = vers


## Enregistre un correctif fraîchement téléchargé. Il ne prendra effet qu'au
## prochain lancement : les scripts déjà en mémoire ne se remplacent pas.
func installer(fichier: String, base: String, vers: String) -> void:
	var c := ConfigFile.new()
	c.set_value("correctif", "base", base)
	c.set_value("correctif", "version", vers)
	c.set_value("correctif", "fichier", fichier)
	c.save(MARQUEUR)


## Revient à la version d'origine — le recours si un correctif casse le jeu.
func oublier() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MARQUEUR))
