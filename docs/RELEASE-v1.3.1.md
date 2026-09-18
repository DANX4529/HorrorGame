<!-- Corps de la release GitHub v1.3.1.
     Le workflow .github/workflows/release.yml retire ce commentaire avant
     publication : il ne s'adresse pas aux joueurs. -->

> *Trois parties sur quatre cachaient un fusible sous une feuille de papier.*

Jeu d'horreur psychologique à la première personne. **Elle est aveugle. Elle chasse au son.** Et le bruit le plus fort dans un bâtiment vide, c'est votre propre respiration.

## La dernière fois que vous téléchargez 148 Mo

Cette version apprend au jeu à se mettre à jour **sans se remplacer en entier**. Une correction de bugs, c'est trois cents kilo-octets de scripts ; jusqu'ici elle vous en coûtait cent quarante-huit millions.

Il y a une réserve, et autant la dire franchement : **le mécanisme ne peut rien pour la 1.3.0**, qui ne sait pas encore l'utiliser. Il faut donc prendre celle-ci en entier, une dernière fois. À partir d'elle, le jeu vérifiera tout seul, proposera, et ne téléchargera que ce qui a changé.

## Télécharger

| Fichier | Taille | Pour qui |
|---|---|---|
| **`RESPIRE-windows.exe`** | 149 Mo | Double-cliquez, ça se lance. Rien à installer. |
| `RESPIRE-windows.zip` | 77 Mo | Même jeu, moitié moins lourd à télécharger. |

Windows peut afficher un avertissement SmartScreen : l'exécutable n'est pas signé numériquement. **Informations complémentaires → Exécuter quand même.**

Jouable aussi dans le navigateur, **y compris sur téléphone** : https://danx4529.github.io/HorrorGame/

## Ce que corrige la 1.3.1

**Un fusible pouvait se poser sur un document.** Les deux se retrouvaient dans le même demi-mètre : leurs corps se recouvrent, un seul répond quand on appuie, et l'autre devient impossible à ramasser. Quand c'était le fusible qui passait dessous, l'étage ne pouvait plus être terminé du tout.

Ce n'était pas rare. Sur vingt-cinq descentes mesurées au niveau −1, **dix-neuf étaient touchées**. Les documents, les piles et les morceaux de plâtre s'écartent maintenant de tout ce qui est déjà au sol, et un contrôle automatique refuse désormais toute version où deux objets seraient à moins de 75 cm.

**Le pied de page d'un document était illisible.** Il affichait `%s · %d / %d documents` au lieu du chapitre et du compte. Une erreur de mise en forme qui traînait depuis la 1.0.2.

**Le plein écran existe.** Sans bordure, donc l'alt-tab reste instantané et le second écran utilisable — ce qui compte pour un jeu qu'on quitte des yeux quand elle approche. Dans les options, ou **`F11`** à tout moment.

**Le jeu sait se mettre à jour.** Il regarde au lancement s'il existe une version plus récente, et le dit d'une ligne sous les boutons — jamais d'une fenêtre. S'il n'y a pas de réseau, il ne dit rien du tout.

## Ce qu'il y a dans le jeu

**La traque est lisible.** L'asile vous renvoie le bruit que vous faites : accroupi il se tait, en courant le couloir vous répond. Vous entendez quand elle vous a entendu, et — surtout — quand elle a perdu votre trace.

**Une descente, pas une partie.** Trois étages : le service de veille, le pavillon C, les bains. Le monte-charge ne fait pas gagner, il descend. Ce que vous ramassez reste **en main** tant que vous n'êtes pas remonté par la cabine.

**Le sol fait partie du danger.** Aux bains, l'eau stagnante porte votre bruit une fois et demie plus loin, le verre brisé deux fois. Le chemin le plus court cesse d'être le plus sûr.

**Vous pouvez l'envoyer ailleurs.** Ramassez un morceau de plâtre, jetez-le : le bruit se fait là où il tombe. `G` pour jeter.

**Une histoire à reconstituer.** Vingt-huit documents en cinq chapitres, à retrouver dans les salles où ils ont un sens.

**Jouable au doigt**, manche à gauche, visée à droite, un large bouton **SOUFFLE** sous le pouce.

## Ce qui n'y est pas encore

La descente s'arrête aux bains. **Deux étages sont écrits et pas encore bâtis** : la cure d'obscurité, où la lampe meurt, et la ronde, où elle apprend de vous. Les trois fins en dépendent.

## Commandes

`ZQSD`/`WASD` se déplacer · `Maj` courir · `C` s'accroupir · **`Ctrl` retenir son souffle** · `E` interagir · **`G` jeter** · `F` lampe · **`F11` plein écran** · `Échap` pause

## Crédits

Conception, écriture et réalisation : **Liam RIIS**.

Modèles, textures et animations sont fabriqués par les scripts du dépôt — aucune banque d'assets. Les enregistrements sonores viennent de banques **CC0 1.0** (Owlish Media, rubberduck, Fantozzi, qubodup, Spring Spring, Ogrebane), détaillées dans [`docs/CREDITS_AUDIO.md`](https://github.com/DANX4529/HorrorGame/blob/claude/horror-game-dev-p1suvq/docs/CREDITS_AUDIO.md) et dans les crédits en jeu. Moteur : Godot Engine 4.3.
