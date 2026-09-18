<!-- Corps de la release GitHub v1.2.0.
     Le workflow .github/workflows/release.yml retire ce commentaire avant
     publication : il ne s'adresse pas aux joueurs. -->

> *Le monte-charge ne remonte plus. Il descend.*
> *Et ce que vous avez lu ne vous appartient qu'une fois ressorti.*

Jeu d'horreur psychologique à la première personne. **Elle est aveugle. Elle chasse au son.** Et le bruit le plus fort dans un bâtiment vide, c'est votre propre respiration.

## Télécharger

| Fichier | Taille | Pour qui |
|---|---|---|
| **`RESPIRE-windows.exe`** | 128 Mo | Double-cliquez, ça se lance. Rien à installer. |
| `RESPIRE-windows.zip` | 57 Mo | Même jeu, moitié moins lourd à télécharger. À décompresser. |

Windows peut afficher un avertissement SmartScreen : l'exécutable n'est pas signé numériquement. **Informations complémentaires → Exécuter quand même.**

Jouable aussi dans le navigateur, **y compris sur téléphone** : https://danx4529.github.io/HorrorGame/

## Ce que change la 1.2.0

**Le sanatorium a un deuxième étage.** Une partie n'est plus une partie : c'est une **descente**. Le monte-charge ne fait plus gagner, il vous emmène plus bas. On arrive au **pavillon C** — celui de « l'incident » —, un plan à deux anneaux au lieu d'un : on peut toujours la contourner, mais il faut choisir par où.

**Ce que vous lisez ne vous appartient pas encore.** Un document ramassé reste **en main** tant que vous n'êtes pas ressorti par la cabine. Mourir le laisse en bas. Le monte-charge vous dit ce qu'il met à l'abri, le journal marque ce que vous portez encore, et l'écran de mort nomme ce que vous venez de perdre — pour qu'aucune de ces pertes ne soit une surprise.

Mourir vous renvoie au début de l'étage, **sur le même plan** : ce que vous avez appris du bâtiment en mourant sert encore. Le point de reprise au tableau ne subsiste qu'en *Veilleur* ; aux deux autres difficultés, l'étage est l'unité de reprise.

**Vous pouvez enfin l'envoyer ailleurs.** Ramassez un morceau de plâtre, jetez-le : le bruit se fait **là où il tombe**, assez fort pour la lancer — loin de vous. Jusqu'ici la Veilleuse ne pouvait qu'être évitée. Deux morceaux en main au plus : c'est une décision, pas une mitraillette.

`G` pour jeter.

**Vos sauvegardes traversent.** Tout ce que vous aviez retrouvé est conservé, et le jeu sait désormais que vous aviez déjà vu le niveau −1.

## Ce qui n'y est pas encore

Le pavillon C **n'a pas encore son chapitre**. On y descend, on y joue, on y meurt — mais les documents qu'on y trouve sont ceux restés du niveau −1. C'est une version de structure, pas de récit : l'histoire du pavillon est la suite immédiate, avec les étages qui descendent plus bas.

## Ce qu'il y a dans le jeu

**La traque est lisible.** L'asile vous renvoie le bruit que vous faites : accroupi il se tait, en courant le couloir vous répond. Vous entendez quand elle vous a entendu, et — surtout — quand elle a perdu votre trace.

**Le sanatorium fait du bruit tout seul** : deux nappes de fond, une horloge qui va et vient, des bruits isolés posés dans le noir, de rares nappes musicales. Rien de tout cela n'est entendu par la Veilleuse — vous n'êtes jamais puni pour un bruit que vous n'avez pas fait — et tout se tait pendant une traque.

**Une histoire à reconstituer.** Quatorze documents en trois chapitres, à retrouver dans les salles où ils ont un sens. Un journal conserve ce que vous avez rapporté d'une descente à l'autre.

**Chaque descente est différente.** Objectifs, mobilier, cachettes, lampes et documents sont tirés au sort.

**Trois difficultés**, qui agissent sur la finesse de son ouïe — jamais sur le bruit que vous émettez.

**Jouable au doigt.** Manche analogique à gauche, visée au glissement à droite, et un large bouton **SOUFFLE** sous le pouce. Le jeu reconnaît sur quoi vous jouez et bascule tout seul.

## Commandes

`ZQSD`/`WASD` se déplacer · `Maj` courir · `C` s'accroupir · **`Ctrl` retenir son souffle** · `E` interagir · **`G` jeter** · `F` lampe · `Échap` pause

## Crédits

Conception, écriture et réalisation : **Liam RIIS**.

Modèles, textures et animations sont fabriqués par les scripts du dépôt — aucune banque d'assets. Les enregistrements sonores viennent de banques **CC0 1.0** (Owlish Media, rubberduck, Fantozzi, qubodup, Spring Spring, Ogrebane), détaillées dans [`docs/CREDITS_AUDIO.md`](https://github.com/DANX4529/HorrorGame/blob/claude/horror-game-dev-p1suvq/docs/CREDITS_AUDIO.md) et dans les crédits en jeu. Moteur : Godot Engine 4.3.
