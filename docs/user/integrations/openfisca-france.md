# OpenFisca-France et Français Logique

*Genre : guide d'intégration · Public : utilisateurs · État : en cours (11 octobre 2026) · English: [OpenFisca, PolicyEngine and Logical English](openfisca.md)*

**OpenFisca-France** est le modèle du système socio-fiscal français. Ce modèle est
écrit avec OpenFisca, un logiciel libre. Le modèle est un ensemble de fichiers
Python. Python est un langage de programmation. Le modèle calcule l'impôt sur le
revenu, les aides au logement, le revenu de solidarité active (RSA), la prime
d'activité, les cotisations sociales, et beaucoup d'autres montants. Des
administrations et des chercheurs utilisent le modèle. Le simulateur public
mes-aides.gouv.fr utilise aussi le modèle.

**Français Logique** est Logical English écrit en français. Un programme en Français
Logique contient des règles en phrases françaises. Un ordinateur sait appliquer ces
règles. Le traducteur lit un programme d'OpenFisca-France et l'écrit en Français
Logique. Le résultat s'appelle un *jumeau*. Un jumeau est un programme qui doit
donner les mêmes réponses que le modèle. On vérifie le jumeau sur les tests du modèle
lui-même.

Ce document dit ce que le traducteur fait d'OpenFisca-France. Il dit aussi ce que les
jumeaux vérifient aujourd'hui, et ce qui reste à faire. Le guide en anglais
([OpenFisca, PolicyEngine and Logical English](openfisca.md)) décrit la traduction en
général. Ce document-ci décrit ce qui est propre au modèle français.

## Sommaire

- [Les mots de ce document](#les-mots-de-ce-document)
- [Ouvrir un programme d'OpenFisca-France](#ouvrir-un-programme-dopenfisca-france)
- [Ce que la traduction écrit](#ce-que-la-traduction-écrit)
- [Les jumeaux et ce qu'ils vérifient](#les-jumeaux-et-ce-quils-vérifient)
- [Deux codages des aides au logement comparés](#deux-codages-des-aides-au-logement-comparés)
- [Ce qui reste à traduire](#ce-qui-reste-à-traduire)
- [Voir aussi](#voir-aussi)

## Les mots de ce document

- Une **variable** d'OpenFisca est une grandeur que le modèle calcule ou qu'un cas
  donne. Une variable est un montant, une réponse par oui ou par non, ou un code.
  Chaque variable appartient à une **entité**. Une entité est l'individu, la famille
  (au sens des prestations), le ménage (le logement) ou le foyer fiscal (au sens de
  l'impôt).
- Un **paramètre** est une valeur que la loi fixe, avec les dates où la valeur
  change. Un paramètre est un taux, un plafond ou un barème.
- Un **modèle** (*template*) de Logical English est la forme d'une phrase, avec des
  places pour les valeurs. Exemple : *le loyer d'un ménage est un montant*.
- Un **scénario** est un ensemble de faits sur un cas, par exemple une famille. Le
  scénario contient aussi les réponses que le cas attend.
- Un **résidu** (*residue*) est un morceau du modèle que le traducteur n'a pas su
  écrire en Français Logique. Le programme garde le résidu, avec son code Python et
  la raison. Les réponses qui dépendent d'un résidu ne sont pas vérifiées.

## Ouvrir un programme d'OpenFisca-France

**Fichier ▸ Ouvrir…** (ou **Fichier ▸ Importer depuis un autre système…**) lit un
fichier Python de variables. Ce menu lit aussi une archive zip d'une partie du
modèle, avec ses dossiers `parameters/` et `entities.py`. Une archive zip est un seul
fichier compressé qui contient beaucoup de fichiers.

Le traducteur reconnaît le modèle français à ses entités. Alors il écrit le programme
en Français Logique. Le traducteur lit les fichiers comme du texte. Il n'exécute pas
le code Python.

Les jumeaux décrits plus bas sont faits d'une autre façon. Ils sont faits à partir du
modèle installé avec son moteur de calcul. Ainsi, chaque paramètre a la valeur que le
moteur lui donne. Aussi, chaque test est passé sur le moteur pour le contrôler.

Le modèle est publié sous la licence AGPL-3.0. Cette licence oblige à publier les
œuvres qui dérivent du modèle sous la même licence. Les jumeaux restent donc privés.
Ils sont sur le service hébergé, et pas parmi les exemples de chaque installation.

## Ce que la traduction écrit

**Une variable devient une règle.** La règle cite le libellé de la variable et sa
référence. La référence est souvent un lien vers Légifrance. Par exemple, la règle de
l'aide au logement d'une famille commence par *la aide logement montant d'une famille
est un montant M si…*. Les accords du français sont encore imparfaits (voir [ce qui
reste](#ce-qui-reste-à-traduire)).

**Une période est un mot de la phrase.** Une prestation française lit souvent un
revenu d'une autre période. Exemples : les ressources d'il y a deux ans (l'année
*N-2*), le mois précédent, les trois mois avant la demande. Seule une variable lue à
une autre période reçoit une place pour la période : *le revenu fiscal de référence
d'un foyer fiscal pour une période est un montant*.

Une période a pour nom son texte :

- `2024` pour une année,
- `2024-03` pour un mois,
- `2023-12_3m` pour les trois mois qui commencent en décembre 2023.

Chaque scénario dit comment ses périodes se suivent : *2022 est 2 années avant 2024*,
*2024-01 est un mois de 2023-12_3m*.

**Les rôles d'un groupe sont des faits.** Les parents d'une famille sont le
*demandeur* et le *conjoint*, dans l'ordre où le cas les donne. Les déclarants d'un
foyer fiscal sont le *déclarant principal*, puis son conjoint. Le scénario écrit ces
rôles comme des faits : *individu_1 est demandeur dans la famille*. Une famille peut
lire une valeur de son demandeur. Alors elle lit la valeur du seul membre qui a ce
rôle.

**Une valeur que le cas donne passe avant la règle.** OpenFisca permet à un test de
donner une valeur que le modèle sait calculer. Par exemple, les tests de
l'administration fiscale donnent l'âge et le nombre d'enfants de chaque case de la
déclaration. Le jumeau lit d'abord la valeur que le scénario donne (*le rfr donné*).
S'il n'y a pas de valeur donnée, le jumeau applique la règle.

**Une table par commune est un fichier CSV.** Les aides au logement dépendent de la
zone de la commune du logement (zone 1, 2 ou 3). Une table donne cette zone pour
chacune des 36 682 communes, par son code INSEE. Le modèle charge cette table en
mémoire. Le jumeau garde la table dans un fichier CSV à côté du programme
(`zone_apl_by_depcom.csv`). Un fichier CSV est un fichier de valeurs séparées par des
virgules. Le jumeau lit le fichier par une table de Logical English : *la table
zone_apl_by_depcom est chargée depuis zone_apl_by_depcom.csv, avec première
correspondance*. La dernière ligne du fichier donne la zone 2 à toute commune que la
table ne connaît pas. Le modèle fait la même chose.

**Les paramètres d'une autre date.** Une formule lit parfois les paramètres à une
autre date que la date du calcul. Exemples : le 31 décembre d'il y a deux ans, ou le
dernier 1er juillet. Le jumeau écrit ces paramètres avec leurs propres dates,
déplacées d'autant.

## Les jumeaux et ce qu'ils vérifient

Chaque jumeau est vérifié sur les tests du modèle lui-même. Une réponse est vérifiée
quand le jumeau donne exactement la valeur que le moteur d'OpenFisca-France donne
pour ce cas.

| Jumeau | Ce qu'il couvre | Réponses vérifiées |
|---|---|---|
| `impot_revenu` | l'impôt sur le revenu : parts, revenu brut global, revenu net imposable, revenu fiscal de référence, impôt, réductions | voir le tableau ci-dessous |
| `aides_logement` | les aides au logement (APL, ALF, ALS) : loyer plafond, charges, participation personnelle, montant | **50 sur 50** (12 octobre 2026) |
| `aides_logement_croise` | les mêmes règles, sur 36 situations écrites pour la comparaison avec Catala | **216 sur 216** |
| `rsa` | le RSA et la prime d'activité | **28 sur 28** (12 octobre 2026). 12 autres réponses attendent des parties qui ne sont pas encore traduites, par exemple le forfait logement de la prime d'activité |

Le tableau suivant donne les résultats pour l'impôt sur le revenu. Les tests sont
ceux du calculateur de l'administration fiscale et ceux du modèle (434 cas, mesure
du 12 octobre 2026) :

| Valeur demandée | Accord | Désaccord |
|---|---|---|
| le nombre de parts du foyer fiscal (`nbptr`) | 363 | 0 |
| le revenu fiscal de référence (`rfr`) | 351 | 1 |
| le revenu brut global (`rbg`) | 321 | 0 |
| le revenu net imposable (`rni`) | 251 | 0 |
| l'impôt avant crédits (`iai`) | 293 | 3 |
| les réductions d'impôt | 139 | 4 |

## Deux codages des aides au logement comparés

La même loi des aides au logement est écrite deux fois :

- dans OpenFisca-France,
- par la Caisse nationale des allocations familiales (CNAF) en Catala. Catala est un
  autre langage de programmation de la loi (voir [Catala et Logical
  English](catala.md)).

Le traducteur écrit les deux en Français Logique. Aucune des deux sources ne vérifie
l'autre. Les deux jumeaux permettent de faire cette vérification.

Le contrôle croisé pose 36 situations aux deux jumeaux. Chaque situation est une
personne seule ou un couple, avec 0, 1 ou 3 enfants. La personne ou le couple est
locataire en zone 1, 2 ou 3, à une date de 2022 à 2024, avec un loyer et des
ressources. Le contrôle compare cinq valeurs que les deux codages nomment.

| Valeur | Les deux jumeaux d'accord | Désaccord | Sans réponse d'un des deux |
|---|---|---|---|
| le loyer plafond | 36 | 0 | 0 |
| le forfait de charges | 36 | 0 | 0 |
| le taux de composition familiale | 36 | 0 | 0 |
| la participation minimale (P0) | 19 | 17 | 0 |
| la participation personnelle | 0 | 36 | 0 |

**Tous les désaccords ont la même cause, et cette cause est dans les sources.** Le
programme de la CNAF arrondit au centime la participation minimale. Il arrondit aussi
au centime chacun des deux termes de la participation personnelle, avant de les
additionner. OpenFisca-France ne fait pas ces arrondis.

Exemple : un couple avec trois enfants, avec un loyer de 900 €, en novembre 2022. La
participation minimale est 48,654 € dans OpenFisca-France, et 48,65 € pour la CNAF.
La participation personnelle est 52,4969 € dans OpenFisca-France, et 48,65 € + 3,84 €
= 52,49 € pour la CNAF. Chaque jumeau donne la valeur de sa propre source. L'écart
est d'un ou deux centimes. Cet écart peut changer d'un euro une aide que la loi
arrondit à l'euro.

Une situation restait sans loyer plafond (une personne seule en zone 3, en mars
2024). La cause était une erreur du traducteur, pas de la loi. En français, « me
est » s'écrit « m'est ». Le traducteur appliquait cette règle à un nom de valeur
écrit en capitales, ME. Alors la règle lisait une autre valeur. Le traducteur ne
raccourcit plus un mot en capitales. Depuis le 12 octobre 2026, le jumeau de la CNAF
donne pour cette situation le même loyer plafond qu'OpenFisca-France.

## Ce qui reste à traduire

- **Les accords du français.** Les phrases suivent les noms des variables, sans les
  accents. Exemples : *la aide logement montant* (pour *l'aide*), *le zone apl* (pour
  *la zone*), *le pensions alimentaires versees* (pour *les pensions*). Les mots
  propres au traducteur sont parfois encore en anglais (*member part of*, *counts
  for*, *step*).
- **Le RSA lui-même.** Le montant de base du RSA lit un paramètre. Le modèle n'a plus
  ce paramètre pour les années de ses tests. La plupart des cas du RSA attendent donc
  cette partie, qui n'est pas traduite.
- **L'impôt lui-même.** Le jumeau répond à toutes les 1 948 réponses vérifiées. Sur
  ces 1 948 réponses, 1 934 sont d'accord avec le moteur. La réduction
  Duflot-Pinel-Denormandie est juste dans les 119 réponses. Il reste ces écarts :
  - 6 écarts d'un euro, qui viennent des arrondis du moteur lui-même,
  - 5 écarts sur les cotisations syndicales,
  - 3 écarts sur la contribution exceptionnelle sur les hauts revenus de 2026.

## Voir aussi

- [OpenFisca, PolicyEngine and Logical English](openfisca.md), le guide général, en
  anglais
- [Catala et Logical English](catala.md) : le programme des aides au logement de la
  CNAF
- OpenFisca-France : https://github.com/openfisca/openfisca-france
