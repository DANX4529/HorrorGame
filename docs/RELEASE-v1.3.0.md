<!-- Corps de la release GitHub v1.3.0.
     Le workflow .github/workflows/release.yml retire ce commentaire avant
     publication : il ne s'adresse pas aux joueurs. -->

> *Le carrelage est encore humide. Le bassin n'a pas été vidé depuis 1961.*
> *Et l'eau porte le bruit bien plus loin que le lino.*

Jeu d'horreur psychologique à la première personne. **Elle est aveugle. Elle chasse au son.** Et le bruit le plus fort dans un bâtiment vide, c'est votre propre respiration.

## Télécharger

| Fichier | Taille | Pour qui |
|---|---|---|
| **`RESPIRE-windows.exe`** | 149 Mo | Double-cliquez, ça se lance. Rien à installer. |
| `RESPIRE-windows.zip` | 77 Mo | Même jeu, moitié moins lourd à télécharger. À décompresser. |

Windows peut afficher un avertissement SmartScreen : l'exécutable n'est pas signé numériquement. **Informations complémentaires → Exécuter quand même.**

Jouable aussi dans le navigateur, **y compris sur téléphone** : https://danx4529.github.io/HorrorGame/

## Ce que change la 1.3.0

**Un troisième étage : les bains.** On descend au niveau −3, celui de la balnéothérapie. Quatre volants de vanne à rapporter à la nourrice principale, dans un plan à deux anneaux, entre les baignoires, les cabines de déshabillage et le solarium dont la verrière a cédé.

**Le sol devient la mécanique.** Jusqu'ici, ce qui vous trahissait c'était votre allure : marcher, courir, respirer. Aux bains, **c'est aussi l'endroit où vous posez le pied**. L'eau stagnante porte votre bruit une fois et demie plus loin ; le verre brisé du solarium, deux fois. Le lino des vestiaires, lui, l'étouffe. Ce n'est pas qu'un son différent : c'est vraiment la distance à laquelle elle vous entend qui change, et le chemin le plus court cesse d'être le plus sûr.

**Le pavillon C a enfin son chapitre.** Sept documents racontent l'incident — ceux qui étaient restés du niveau −1 lui cèdent la place. Sept autres attendent aux bains.

**Onze objets neufs** pour les bains seuls : baignoire de balnéothérapie, cabine de déshabillage, pommeau, table de massage, nourrice, siphon de sol, tuyauterie, seau, tabouret, bassine, volant de vanne. Plus six matériaux : carrelage de bains, sol en mosaïque, verre brisé, eau, laiton vert-de-grisé, émail.

## Ce qui a été réparé

**Les couloirs avaient perdu leur mobilier.** Un défaut introduit après la 1.2.0 — donc jamais publié, jamais joué — vidait l'habillage de tous les couloirs, cachettes comprises. C'est réparé, et un contrôle automatique refuse désormais qu'une salle reste sans habillage.

**Les grandes surfaces ne se répètent plus en damier.** Murs, sols et plafonds existent maintenant en quatre versions, choisies case par case. On ne reconnaît plus la même tache au même endroit tout le long d'un couloir.

**L'eau des bains se voit.** Elle sortait quasiment noire : le matériau était réglé comme un métal, et misait sur des reflets que le moteur ne calcule pas dans le mode utilisé par le jeu. Une flaque qu'on ne voit pas est une punition qu'on ne comprend pas.

## Ce qu'il y a dans le jeu

**La traque est lisible.** L'asile vous renvoie le bruit que vous faites : accroupi il se tait, en courant le couloir vous répond. Vous entendez quand elle vous a entendu, et — surtout — quand elle a perdu votre trace.

**Une descente, pas une partie.** Le monte-charge ne fait pas gagner : il descend. Ce que vous ramassez reste **en main** tant que vous n'êtes pas remonté par la cabine — mourir le laisse en bas.

**Vous pouvez l'envoyer ailleurs.** Ramassez un morceau de plâtre, jetez-le : le bruit se fait **là où il tombe**, assez fort pour la lancer loin de vous. `G` pour jeter.

**Le sanatorium fait du bruit tout seul** : deux nappes de fond, une horloge, des bruits isolés posés dans le noir. Rien de tout cela n'est entendu par la Veilleuse — vous n'êtes jamais puni pour un bruit que vous n'avez pas fait.

**Une histoire à reconstituer.** Vingt-huit documents en cinq chapitres, à retrouver dans les salles où ils ont un sens.

**Chaque descente est différente.** Objectifs, mobilier, cachettes, lampes et documents sont tirés au sort.

**Trois difficultés**, qui agissent sur la finesse de son ouïe — jamais sur le bruit que vous émettez.

**Jouable au doigt.** Manche analogique à gauche, visée au glissement à droite, et un large bouton **SOUFFLE** sous le pouce.

## Ce qui n'y est pas encore

La descente s'arrête aux bains. **Deux étages sont écrits et pas encore bâtis** : la cure d'obscurité, où la lampe meurt, et la ronde, où elle apprend de vous. Les trois fins en dépendent.

## Commandes

`ZQSD`/`WASD` se déplacer · `Maj` courir · `C` s'accroupir · **`Ctrl` retenir son souffle** · `E` interagir · **`G` jeter** · `F` lampe · `Échap` pause

## Crédits

Conception, écriture et réalisation : **Liam RIIS**.

Modèles, textures et animations sont fabriqués par les scripts du dépôt — aucune banque d'assets. Les enregistrements sonores viennent de banques **CC0 1.0** (Owlish Media, rubberduck, Fantozzi, qubodup, Spring Spring, Ogrebane), détaillées dans [`docs/CREDITS_AUDIO.md`](https://github.com/DANX4529/HorrorGame/blob/claude/horror-game-dev-p1suvq/docs/CREDITS_AUDIO.md) et dans les crédits en jeu. Moteur : Godot Engine 4.3.
