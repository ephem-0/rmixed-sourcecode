# Voix radio — FabFilter, Pro-C 3 et deux Pro-MB

**Version 2** — Script pour REAPER 7 sous Windows. Il prépare une **nouvelle piste** sans modifier la piste ni le routage existants. Cible : voix parlée proche, dense et claire, avec des graves contrôlés. Ce n'est pas le preset d'Inoxtag, ni une garantie de reproduire sa voix ou son mix.

## Lancer le script

1. Télécharger `Installer_Voix_Radio_FabFilter.lua` avec le bouton de téléchargement du fichier sur GitHub. Ne pas enregistrer la page HTML à sa place.
2. Dans REAPER, ouvrir **Actions → Show action list → New action → Load ReaScript** (selon la version, bouton **ReaScript: Load**), puis sélectionner le `.lua`.
3. Sélectionner la piste micro actuelle, puis exécuter le script avec **Run**.
4. Lire le message final. Si la configuration est complète, sélectionner l'entrée **mono** du micro sur la nouvelle piste, couper le monitoring de l'ancienne piste, puis démuter, armer et activer le monitoring de la nouvelle, au casque.

La piste est toujours créée **muette, désarmée, monitoring coupé**. Aucune sortie Discord/OBS, entrée matérielle supplémentaire ou modification du périphérique audio n'est effectuée. Les items de l'ancienne piste ne sont pas copiés. Pour tester le WAV, l'importer sur la nouvelle piste et couper l'ancienne pendant la comparaison.

Prérequis : versions VST3 installées et activées de **Pro-Q 4, Pro-G, Pro-C 3 et Pro-MB**. Pro-C 2 n'est pas utilisé comme remplacement. Aucune licence n'est incluse ou demandée.

## Chaîne prévue

| Étape | Fonction et point de départ |
|---|---|
| Pro-Q 4 | Zero Latency, coupe-bas 65 Hz / 12 dB/oct, grave +2 dB à 125 Hz, −3 dB à 330 Hz, présence +3 dB à 2,8 kHz, shelf +1,5 dB à 8 kHz. Gain de sortie +8 dB adapté au niveau de l'extrait fourni. |
| Pro-G | Expansion douce, seuil −46 dB après EQ, ratio 1,6:1, range 12 dB, attaque 3 ms, hold 30 ms, release 140 ms. Lookahead nul. |
| Pro-C 3 | Style Clean, seuil −25 dB, ratio 3,5:1, knee 6 dB, attaque 5 ms, release 100 ms. Auto Gain et Auto Release désactivés, signal sec coupé, gain wet nul, lookahead nul. |
| Pro-MB 1 | Dynamic Phase, une bande de 100 à 350 Hz. Seuil −26 dB, range −3 dB, ratio 1,6:1, attaque 25 %, release 35 %, knee 6 dB. Contient les gonflements du grave/bas-médium. |
| Pro-MB 2 | **Minimum Phase**, une bande de 4,5 à 11 kHz. Seuil −34 dB, range −4 dB, ratio 3:1, attaque 5 %, release 20 %, knee 6 dB. Contrôle des sifflantes. |
| Sécurité JSFX incluse | Gain +12 dB et plafond d'échantillons −1,5 dBFS, anticipation 1 ms. Ce n'est pas un limiteur true-peak. |

Les attaques/releases Pro-MB sont exprimées en **pourcentage**, pas en millisecondes. Les autres bandes sont désactivées. Le mode Minimum Phase ne garantit pas à lui seul une latence nulle ; la latence réelle dépend aussi des plugins, du buffer et du pilote. Commencer par 128 échantillons à 48 kHz et diminuer uniquement si la machine reste stable.

La sécurité de sortie est un petit JSFX fourni dans le script, installé dans `Effects/RMixed/RadioSafety.jsfx` du dossier de ressources REAPER. Les cinq traitements principaux utilisent FabFilter. Le script refuse d'écraser un JSFX existant dont le contenu diffère. Annuler la création de piste ne supprime pas ce fichier de ressources.

## Vérification automatique et rapport

Le script tente de charger le preset usine de chaque nouvelle instance. Certains VST3, dont le Pro-Q 4 du rapport reçu, ne l’exposent pas via cette API REAPER : ce refus est maintenant informatif et ne bloque plus la configuration explicite. Les bandes EQ sont activées en stéréo, leurs modes dynamiques/spectraux et solos sont désactivés, le gain automatique est coupé et la balance est centrée. Il recherche les paramètres par leur nom, puis utilise leurs valeurs affichées pour trouver les positions des contrôles : il ne suppose pas que telle fréquence correspond à un indice ou une position fixe. Les valeurs appliquées sont relues. Un plugin absent ou un paramètre requis non reconnu bloque la validation. Les choix à positions discrètes sont vérifiés selon leur libellé final ; les valeurs numériques sont relues dans leur unité. Les autres plugins sont quand même chargés pour enrichir le rapport si l’un manque.

Il écrit `Rapport_FabFilter.txt` à côté du script et dans la console REAPER, avec le numéro de version et des exemples de valeurs affichées pour chaque paramètre. **Si la configuration est incomplète, tous les effets restent bypassés et la piste reste muette.** Envoyer ce fichier dans la conversation permettra d'adapter les correspondances exactes à la version installée, sans captures ni envoi des VST3. Le rapport contient les noms et valeurs des paramètres ; en cas d'erreur, il peut aussi contenir le chemin local du script.

Ne pas activer une chaîne partiellement configurée sans vérifier ses réglages. Si le JSFX nouvellement installé est introuvable, relancer REAPER, supprimer la piste d'essai incomplète et relancer le script. Chaque exécution crée une piste supplémentaire.

## Ajuster à la prise réelle

Ce sont des points de départ basés sur l'analyse du court enregistrement fourni, pas un étalonnage de toutes les prises futures. Le gain du micro et la distance doivent rester comparables. Si la prise d'origine était déjà traitée, un extrait réellement brut sera nécessaire pour affiner.

- Voix trop sourde : ramener le shelf 125 Hz de +2 à 0 dB.
- Voix trop pincée : réduire la présence 2,8 kHz de +3 à +1 dB.
- Voix amincie : réduire l'action du premier Pro-MB ; il ne doit pas atténuer constamment de 3 dB.
- Sifflantes persistantes : abaisser légèrement le seuil du deuxième Pro-MB. Si la diction devient terne ou zozotante, relever le seuil ou réduire son range.
- Fins de mots mangées : abaisser le seuil de Pro-G.
- Sécurité de sortie sollicitée en permanence : baisser son gain de sortie. Ne pas chercher la densité en écrêtant la voix.

Comparer à volume d'écoute égal. Ne pas empiler cette chaîne avec le traitement précédent pour le premier essai. Une prise à distance stable avec filtre anti-pop aide davantage qu'une compression excessive.

## Ce qui a été vérifié ici

Syntaxe/exécution Lua et cinq scénarios avec une API REAPER simulée : succès, plugin absent, mode de phase absent, preset usine non exposé et paramètres à positions discrètes. Les noms des contrôles Pro-Q 4 supplémentaires viennent du rapport fourni. Les tests sont dans `tests/test_installer.py` et nécessitent le paquet Python `lupa` (`python tests/test_installer.py`). Les tests vérifient le recours à **Pro-C 3**, le second Pro-MB en **Minimum Phase**, la conservation de la piste d'origine et les mises en sécurité.

**Aucune exécution dans REAPER ni dans les FabFilter réels, aucune validation auditive de cette nouvelle chaîne.** Leurs noms de paramètres peuvent différer des correspondances prévues : le rapport sert précisément à résoudre cela. Aucun WAV rendu avec cette chaîne n'est fourni. Les WAV et mesures du dossier parent concernent uniquement la première version JSFX, pas cette version FabFilter.

Pour remplacer la première version : retélécharger le `.lua` et remplacer le fichier chargé dans REAPER, puis relancer l’action. Le titre du message doit afficher **v2**. La précédente piste d’essai incomplète peut être supprimée ; conserver la piste micro d’origine.
