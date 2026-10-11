# OpenFisca-France et Français Logique

*Genre : guide d'intégration · Public : utilisateurs · État : en cours (11 octobre 2026) · English: [OpenFisca, PolicyEngine and Logical English](openfisca.md)*

**OpenFisca-France** est le modèle du système socio-fiscal français écrit
avec OpenFisca, un logiciel libre. Le modèle est un ensemble de fichiers
Python. Il calcule l'impôt sur le revenu, les aides au logement, le revenu
de solidarité active (RSA), la prime d'activité, les cotisations sociales,
et bien d'autres montants. Des administrations et des chercheurs s'en
servent, et le simulateur public mes-aides.gouv.fr s'appuie sur lui.

**Français Logique** est Logical English écrit en français : des règles en
phrases françaises, qu'un ordinateur sait appliquer. Le traducteur lit un
programme d'OpenFisca-France et l'écrit en Français Logique. Le résultat
s'appelle un *jumeau* : un programme qui doit donner les mêmes réponses que
le modèle, et que l'on vérifie sur les propres tests du modèle.

Ce document dit ce que le traducteur fait d'OpenFisca-France, ce que les
jumeaux vérifient aujourd'hui, et ce qui reste à faire. Le guide en anglais
([OpenFisca, PolicyEngine and Logical English](openfisca.md)) décrit la
traduction en général ; celui-ci décrit ce qui est propre au modèle
français.

## Sommaire

- [Les mots de ce document](#les-mots-de-ce-document)
- [Ouvrir un programme d'OpenFisca-France](#ouvrir-un-programme-dopenfisca-france)
- [Ce que la traduction écrit](#ce-que-la-traduction-écrit)
- [Les jumeaux et ce qu'ils vérifient](#les-jumeaux-et-ce-quils-vérifient)
- [Deux codages des aides au logement comparés](#deux-codages-des-aides-au-logement-comparés)
- [Ce qui reste à traduire](#ce-qui-reste-à-traduire)
- [Voir aussi](#voir-aussi)

## Les mots de ce document

- Une **variable** d'OpenFisca est une grandeur que le modèle calcule ou
  qu'un cas donne : un montant, une réponse par oui ou par non, un code.
  Chaque variable appartient à une **entité** : l'individu, la famille (au
  sens des prestations), le ménage (le logement) ou le foyer fiscal (au
  sens de l'impôt).
- Un **paramètre** est une valeur fixée par la loi, avec les dates où elle
  change : un taux, un plafond, un barème.
- Un **modèle** (*template*) de Logical English est la forme d'une phrase,
  avec des places pour les valeurs : *le loyer d'un ménage est un montant*.
- Un **scénario** est un ensemble de faits sur un cas, une famille par
  exemple, avec les réponses que le cas attend.
- Un **résidu** (*residue*) est un morceau du modèle que le traducteur n'a
  pas su écrire en Français Logique. Il est gardé dans le programme, avec
  son code Python et la raison. Les réponses qui en dépendent ne sont pas
  vérifiées.

## Ouvrir un programme d'OpenFisca-France

**Fichier ▸ Ouvrir…** (ou **Fichier ▸ Importer depuis un autre système…**)
lit un fichier Python de variables, ou une archive zip d'une partie du
modèle avec ses dossiers `parameters/` et `entities.py`. Le traducteur
reconnaît le modèle français à ses entités, et il écrit alors le programme
en Français Logique. Il lit les fichiers comme du texte et n'exécute pas le
code Python. Les jumeaux décrits plus bas ont été faits autrement : à partir
du modèle installé avec son moteur de calcul, pour que chaque paramètre ait
la valeur que le moteur lui donne, et chaque test a été passé sur le moteur
pour le contrôler.

Le modèle est publié sous la licence AGPL-3.0, une licence qui oblige à
publier les œuvres qui en dérivent sous la même licence. Les jumeaux restent
donc privés : ils sont sur le service hébergé, et pas parmi les exemples de
chaque installation.

## Ce que la traduction écrit

**Une variable devient une règle.** La règle cite le libellé de la variable
et sa référence, souvent un lien vers Légifrance. Par exemple, la règle de
l'aide au logement d'une famille commence par *la aide logement montant
d'une famille est un montant M si…* (les accords du français sont encore
imparfaits : voir [ce qui reste](#ce-qui-reste-à-traduire)).

**Une période est un mot de la phrase.** Une prestation française lit
souvent un revenu d'une autre période : les ressources d'il y a deux ans
(l'année *N-2*), le mois précédent, les trois mois avant la demande. Seule
une variable lue à une autre période reçoit une place pour la période :
*le revenu fiscal de référence d'un foyer fiscal pour une période est un
montant*. Une période se nomme par son texte : `2024` pour une année,
`2024-03` pour un mois, `2023-12_3m` pour les trois mois qui commencent en
décembre 2023. Chaque scénario dit comment ses périodes se suivent : *2022
est 2 années avant 2024*, *2024-01 est un mois de 2023-12_3m*.

**Les rôles d'un groupe sont des faits.** Les parents d'une famille sont,
dans l'ordre où le cas les donne, le *demandeur* et le *conjoint*. Les
déclarants d'un foyer fiscal sont le *déclarant principal* puis son
conjoint. Le scénario les écrit comme des faits : *individu_1 est demandeur
dans la famille*. Une famille qui lit une valeur de son demandeur lit la
valeur du seul membre qui tient ce rôle.

**Une valeur que le cas donne passe avant la règle.** OpenFisca permet à un
test de donner une valeur que le modèle sait calculer : les tests de
l'administration fiscale donnent l'âge et le nombre d'enfants de chaque
case de la déclaration. Le jumeau lit d'abord la valeur que le scénario
donne (*le rfr donné*), et sinon applique la règle.

**Une table par commune est un fichier CSV.** Les aides au logement
dépendent de la zone de la commune du logement (zone 1, 2 ou 3), qu'une
table donne pour chacune des 36 682 communes, par son code INSEE. Le
modèle charge cette table en mémoire. Le jumeau la garde dans un fichier
CSV à côté du programme (un fichier de valeurs séparées par des virgules,
`zone_apl_by_depcom.csv`) et la lit par une table de Logical English :
*la table zone_apl_by_depcom est chargée depuis zone_apl_by_depcom.csv,
avec première correspondance*. La dernière ligne du fichier donne la zone 2
à toute commune que la table ne connaît pas, comme le fait le modèle.

**Les paramètres d'une autre date.** Une formule lit parfois les paramètres
à une autre date que celle du calcul : le 31 décembre d'il y a deux ans, ou
le dernier 1er juillet. Le jumeau écrit ces paramètres avec leurs propres
dates, déplacées d'autant.

## Les jumeaux et ce qu'ils vérifient

Chaque jumeau est vérifié sur les tests du modèle lui-même. Une réponse
compte comme vérifiée quand le jumeau donne exactement la valeur que le
moteur d'OpenFisca-France donne pour ce cas.

| Jumeau | Ce qu'il couvre | Réponses vérifiées |
|---|---|---|
| `impot_revenu` | l'impôt sur le revenu : parts, revenu brut global, revenu net imposable, revenu fiscal de référence, impôt, réductions | voir le tableau ci-dessous |
| `aides_logement` | les aides au logement (APL, ALF, ALS) : loyer plafond, charges, participation personnelle, montant | **39 sur 39** (11 octobre 2026) |
| `aides_logement_croise` | les mêmes règles, sur 36 situations écrites pour la comparaison avec Catala | **216 sur 216** |
| `rsa` | le RSA et la prime d'activité | **16 sur 40** : le revenu d'activité de la prime d'activité ne répond pas encore |

Pour l'impôt sur le revenu, sur les tests du calculateur de
l'administration fiscale et ceux du modèle (434 cas, mesure du 11 octobre
2026) :

| Valeur demandée | Accord | Désaccord |
|---|---|---|
| le nombre de parts du foyer fiscal (`nbptr`) | 363 | 0 |
| le revenu fiscal de référence (`rfr`) | 349 | 3 |
| le revenu brut global (`rbg`) | 321 | 0 |
| le revenu net imposable (`rni`) | 249 | 2 |
| l'impôt avant crédits (`iai`) | 77 | 219 |
| les réductions d'impôt | 30 | 112 |

## Deux codages des aides au logement comparés

La même loi des aides au logement est écrite deux fois : dans
OpenFisca-France, et par la Caisse nationale des allocations familiales
(CNAF) en Catala, un autre langage de programmation de la loi (voir
[Catala et Logical English](catala.md)). Les deux sont traduits en Français
Logique. Aucune des deux sources ne vérifie l'autre ; les deux jumeaux
permettent de le faire.

Le contrôle croisé pose 36 situations aux deux jumeaux : une personne seule
ou un couple, avec 0, 1 ou 3 enfants, locataire en zone 1, 2 ou 3, à une
date de 2022 à 2024, avec un loyer et des ressources. Il compare cinq
valeurs que les deux codages nomment.

| Valeur | Les deux jumeaux d'accord | Désaccord | Sans réponse d'un des deux |
|---|---|---|---|
| le loyer plafond | 35 | 0 | 1 |
| le forfait de charges | 36 | 0 | 0 |
| le taux de composition familiale | 36 | 0 | 0 |
| la participation minimale (P0) | 18 | 18 | 0 |
| la participation personnelle | 0 | 36 | 0 |

**Tous les désaccords ont la même cause, qui est dans les sources.** Le
programme de la CNAF arrondit au centime la participation minimale, et
chacun des deux termes de la participation personnelle, avant de les
additionner. OpenFisca-France ne les arrondit pas. Par exemple, pour un
couple avec trois enfants à 900 € de loyer en novembre 2022 : 48,654 € dans
OpenFisca-France, 48,65 € pour la CNAF ; et pour la participation
personnelle, 52,4969 € contre 48,65 € + 3,84 € = 52,49 €. Chaque jumeau donne
la valeur de sa propre source. L'écart est d'un ou deux centimes ; il peut
faire changer d'un euro une aide que la loi arrondit à l'euro.

Une situation reste à éclaircir : en mars 2024, pour une personne seule en
zone 3, le jumeau de la CNAF ne donne pas de loyer plafond. Il faut
regarder ce que l'interpréteur de Catala lui-même répond.

## Ce qui reste à traduire

- **Les accords du français.** Les phrases suivent les noms des variables :
  *la aide logement montant* (pour *l'aide*), *le zone apl* (pour *la
  zone*), *le pensions alimentaires versees* (pour *les pensions*), sans les
  accents. Les mots propres au traducteur sont parfois encore en anglais
  (*member part of*, *counts for*, *step*).
- **Plusieurs groupes du même genre dans un cas.** Un cas où une famille
  vit avec un enfant qui fait sa propre déclaration a deux foyers fiscaux.
  Le jumeau ne sait pas encore écrire un tel scénario : 11 cas des aides au
  logement et 33 cas du RSA attendent pour cette raison.
- **Une année glissante.** Depuis 2021, les aides au logement lisent les
  ressources des douze derniers mois (une année qui ne commence pas en
  janvier). Le jumeau ne sait pas encore nommer une telle période.
- **L'impôt lui-même.** L'impôt avant crédits et les réductions ne
  répondent pas dans 286 cas ; les retracer demande une machine de plus de
  8 Go de mémoire. La réduction Duflot-Pinel-Denormandie donnait 0 dans 10
  cas, à cause d'une erreur du traducteur, corrigée le 11 octobre ; le
  jumeau reste à reconstruire pour le vérifier.

## Voir aussi

- [OpenFisca, PolicyEngine and Logical English](openfisca.md), le guide
  général, en anglais
- [Catala et Logical English](catala.md) : le programme des aides au
  logement de la CNAF
- OpenFisca-France : https://github.com/openfisca/openfisca-france
