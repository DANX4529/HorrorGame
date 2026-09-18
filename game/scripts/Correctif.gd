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


# ==========================================================================
#  Aller chercher le correctif
# ==========================================================================
## Dépôt interrogé. Écrit ici plutôt que deviné : le jeu doit savoir d'où il
## accepte du code, et d'un seul endroit.
const DEPOT := "DANX4529/HorrorGame"
const PREFIXE := "RESPIRE-correctif-"

signal disponible(version: String, octets: int)
signal progression(recus: int, total: int)
signal installe_ok(version: String)
signal echec(raison: String)

var _http: HTTPRequest = null
var _vers_dispo := ""
var _url_dispo := ""
var _taille_dispo := 0
var en_cours := false


## Demande à GitHub s'il existe un correctif pour NOTRE version de base.
##
## Muet en cas d'échec : pas de réseau, dépôt injoignable, réponse illisible —
## rien de tout cela n'est un problème du joueur, et un jeu d'horreur qui
## affiche une erreur réseau sur son écran-titre casse ce qu'il construit.
func verifier() -> void:
	if OS.has_feature("web") or en_cours:
		return
	en_cours = true
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_sur_liste)
	var e := _http.request("https://api.github.com/repos/%s/releases?per_page=10" % DEPOT,
			["Accept: application/vnd.github+json", "User-Agent: RESPIRE"])
	if e != OK:
		_fin("requête impossible")


func _sur_liste(_r: int, code: int, _h: PackedStringArray, corps: PackedByteArray) -> void:
	if code != 200:
		_fin("GitHub a répondu %d" % code)
		return
	var j = JSON.parse_string(corps.get_string_from_utf8())
	if not (j is Array):
		_fin("réponse illisible")
		return
	# On cherche un correctif qui part de NOTRE base. Les autres ne nous
	# concernent pas : un joueur en 1.3.0 ne doit pas se voir proposer le
	# correctif écrit pour la 1.4.0.
	var attendu := "%s%s-vers-" % [PREFIXE, version_base]
	var meilleure := ""
	for rel in j:
		for a in (rel.get("assets", []) as Array):
			var nom: String = str(a.get("name", ""))
			if not nom.begins_with(attendu) or not nom.ends_with(".pck"):
				continue
			var v := nom.substr(attendu.length())
			v = v.substr(0, v.length() - 4)
			if _plus_recent(v, version_active) and _plus_recent(v, meilleure):
				meilleure = v
				_url_dispo = str(a.get("browser_download_url", ""))
				_taille_dispo = int(a.get("size", 0))
	_fin("")
	if meilleure != "" and _url_dispo != "":
		_vers_dispo = meilleure
		disponible.emit(meilleure, _taille_dispo)


## a est-il postérieur à b ? Comparaison champ par champ, pas alphabétique :
## « 1.10.0 » vient après « 1.9.0 », ce que l'ordre des chaînes dit faux.
func _plus_recent(a: String, b: String) -> bool:
	if b == "":
		return true
	var pa := a.split(".")
	var pb := b.split(".")
	for i in 3:
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


## Télécharge et installe le correctif annoncé. Prend effet au relancement.
func telecharger() -> void:
	if _url_dispo == "" or en_cours:
		return
	en_cours = true
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive("correctifs")
	var fichier := "%s%s-vers-%s.pck" % [PREFIXE, version_base, _vers_dispo]
	_http = HTTPRequest.new()
	_http.timeout = 120.0
	# Écrit directement sur le disque : un correctif tient en mémoire
	# aujourd'hui, pas forcément le jour où il portera un étage entier.
	_http.download_file = DOSSIER.path_join(fichier)
	add_child(_http)
	_http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray,
			_c: PackedByteArray) -> void:
		_fin("")
		if code != 200:
			echec.emit("téléchargement interrompu (%d)" % code)
			return
		# On ne se déclare installé qu'après avoir VU le fichier : une coupure
		# en fin de transfert laisserait sinon un marqueur pointant sur rien,
		# et le prochain lancement chercherait un correctif absent.
		var chemin := DOSSIER.path_join(fichier)
		if not FileAccess.file_exists(chemin):
			echec.emit("fichier absent après téléchargement")
			return
		installer(fichier, version_base, _vers_dispo)
		installe_ok.emit(_vers_dispo))
	if _http.request(_url_dispo, ["User-Agent: RESPIRE"]) != OK:
		_fin("téléchargement impossible")


func _fin(raison: String) -> void:
	en_cours = false
	if _http:
		_http.queue_free()
		_http = null
	if raison != "":
		echec.emit(raison)
