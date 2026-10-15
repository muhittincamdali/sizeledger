<!-- i18n-source: README.md@45c49e938b57cf9ea6e1cc58be521060242517f3 status=reviewed -->
<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/banner-light.svg" alt="sizeledger: Shows where every megabyte of an iOS app comes from: by category, framework, asset catalog, language and architecture."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/sizeledger/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/sizeledger/actions/workflows/ci.yml/badge.svg" alt="État de la CI"></a>
<a href="https://github.com/muhittincamdali/sizeledger/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-version-light.svg" alt="Dernière version: v0.1.1"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/blob/main/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-platforms-light.svg" alt="Plateformes prises en charge: macOS 13+, Linux (x86_64, arm64)"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/blob/main/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-language-light.svg" alt="Version du langage: Swift 6.2+ · Swift 6 mode"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/blob/main/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-license-light.svg" alt="Licence: MIT"></picture></a>
</p>

<p align="center">
<a href="#démarrage-rapide"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-start-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-start-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-start-fr-light.svg" alt="Commencer"></picture></a>
<a href="https://muhittincamdali.github.io/sizeledger/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-docs-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-docs-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-docs-fr-light.svg" alt="Documentation"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/tree/main/docs/guides"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-guides-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-guides-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-guides-fr-light.svg" alt="Guides"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/tree/main/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-examples-fr-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-examples-fr-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-examples-fr-light.svg" alt="Exemples"></picture></a>
</p>

> Ceci est une traduction du README anglais. En cas de différence, la version anglaise fait foi.

<!-- brand:end -->

Pointez sizeledger vers un `.ipa`, une `.app` ou un `.xcarchive` et il montre où se trouvent les octets de
l'app : par catégorie, par framework et par ressource, par langue et par architecture de CPU. Il lit
uniquement les fichiers ; il ne compile, n'exécute, n'envoie et ne modifie rien, et il fonctionne de la
même façon sous macOS et sous Linux.

<picture><source media="(prefers-color-scheme: dark)" srcset="docs/media/demo-analyze-dark.svg"><source media="(prefers-color-scheme: light)" srcset="docs/media/demo-analyze-light.svg"><img src="docs/media/demo-analyze-light.svg" alt="sizeledger analyze sur SampleShop 2.0 : 8.75 MB répartis dans 21 fichiers, 8.80 MB de taille d'installation estimée, 2.72 MB compressés ; catalog.json représente 70.8% de l'app et Assets.car 18.1% ; sept langues ; trois binaires universels avec des slices x86_64 et arm64"></picture>

<sub>Enregistré à partir de la vraie commande (<code>node scripts/demo.mjs</code>) sur
<a href="Fixtures/README.md">SampleShop 2.0</a>, une app SwiftUI que ce dépôt compile pour l'iOS
Simulator. La sortie est identique sur un Mac (Apple silicon) et dans les images CI Linux.</sub>

## Points forts

- **Un seul tableau pour toute l'app.** Exécutable principal, frameworks et dylibs, extensions de l'app,
  App Clips, app watch, localisations, asset catalogs, signature de code et tout le reste. Les catégories
  s'additionnent toujours au total.
- **Chaque framework et chaque extension sur sa propre ligne**, et chaque langue `.lproj` cumulée sur
  l'ensemble de l'app et de ses frameworks.
- **Slices d'architecture de chaque binaire** : quels binaires sont universels et quelle place prend
  chaque slice ; les tailles de segments et les métadonnées Swift figurent dans le JSON.
- **Trois tailles distinctes** : la somme des fichiers, une estimation de la taille d'installation
  (blocs entiers de 4 KiB, comme les stocke APFS) et, pour un `.ipa`, la taille compressée. sizeledger ne
  prétend pas connaître la taille de téléchargement de l'App Store ;
  [voici pourquoi](docs/guides/why-install-size-is-an-estimate.md).
- **Pour les humains et pour la CI** : un tableau dans le terminal, du Markdown pour un pull request ou
  le résumé d'un job, et un rapport JSON à l'ordre de clés stable que vous pouvez commiter, interroger
  avec `jq` et comparer.
- **Aussi une bibliothèque Swift** : [SizeLedgerKit](https://muhittincamdali.github.io/sizeledger/)
  donne le même rapport à vos propres outils. Aucune dépendance : le lecteur ZIP, le décodeur DEFLATE et
  le parseur Mach-O en font partie.

## Démarrage rapide

**1. Installez** (macOS ou Linux avec [Homebrew](https://brew.sh)) :

```sh
brew install muhittincamdali/tap/sizeledger
```

Sans Homebrew, utilisez un [binaire de la release ou compilez depuis les sources](#installation).

**2. Mesurez votre app.** Au choix : un `.ipa` exporté, la `.app` issue d'une compilation ou un
`.xcarchive` obtenu avec **Product › Archive**.

```sh
sizeledger analyze path/to/MyApp.ipa
```

**3. Lisez le tableau.** « By category » indique quel type de contenu pèse lourd ; « Largest items »
nomme les fichiers, frameworks et dossiers ; « Binaries » montre lesquels contiennent plusieurs
architectures. Les notes de fin signalent quand un chiffre demande du contexte (par exemple, une
compilation pour simulateur). Enregistrez le rapport complet avec `--out size/main.json` pour le
conserver ou le comparer plus tard.

[Lire votre première répartition](docs/guides/read-your-first-breakdown.md) parcourt un vrai rapport
ligne par ligne.

## Ce qui fonctionne aujourd'hui

| Fonctionnalité                                                                                                                            | État        |
| ----------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| `analyze` d'une `.app`, d'un `.ipa` ou d'un `.xcarchive` : catégories, composants, langues, binaires et slices, arborescence des fichiers | fonctionne  |
| Sortie en tableau de terminal, en Markdown ou en JSON (`--format`, `--out`)                                                               | fonctionne  |
| macOS 13+ et Linux (x86_64 et arm64, Swift 6.2 et 6.4.1 en CI)                                                                            | fonctionne  |
| Bibliothèque SizeLedgerKit avec documentation DocC                                                                                        | fonctionne  |
| `diff` de deux rapports, avec un résumé Markdown pour les pull requests                                                                   | prévu (0.2) |
| Règles `budget` en YAML (par chemin, total, limite d'App Clip) avec code de sortie 1, et une GitHub Action                                | prévu (0.3) |
| Treemap HTML dans un seul fichier ; renditions des asset catalogs via `assetutil` sous macOS                                              | prévu (0.8) |
| Schéma JSON figé (version 1)                                                                                                              | prévu (1.0) |
| Android `.apk` et `.aab`                                                                                                                  | prévu (1.1) |

Tant que `budget` n'existe pas, vérifier une limite en CI tient en une ligne de `jq` ; voir
[Vérifier les tailles en CI](docs/guides/size-checks-in-ci.md).

## Installation

| Méthode                 | Commande                                                                                                                                                                                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Homebrew (macOS, Linux) | `brew install muhittincamdali/tap/sizeledger`                                                                                                                                                                                                     |
| Binaire de la release   | Téléchargez `sizeledger-<version>-macos-universal.tar.gz` ou `-linux-x86_64` / `-linux-aarch64` depuis [Releases](https://github.com/muhittincamdali/sizeledger/releases), vérifiez-le avec `SHA256SUMS` et placez `sizeledger` dans votre `PATH` |
| Depuis les sources      | `git clone https://github.com/muhittincamdali/sizeledger.git && cd sizeledger && swift build -c release` (le binaire est `.build/release/sizeledger`)                                                                                             |
| Swift package           | `.package(url: "https://github.com/muhittincamdali/sizeledger", from: "0.1.1")`, produit `SizeLedgerKit`                                                                                                                                          |

La compilation nécessite Swift 6.2 ou plus récent (Xcode 26 ou plus récent sur un Mac). Les binaires de
release pour Linux embarquent le runtime Swift et nécessitent glibc 2.35 ou plus récent (Ubuntu 22.04,
Debian 12 ou plus récent).

## Utilisation

```text
sizeledger analyze <input> [--format tty|markdown|json] [--out <file>] [--top <n>] [--color auto|always|never] [--quiet]
```

| Option             | Effet                                                                                     |
| ------------------ | ----------------------------------------------------------------------------------------- |
| `<input>`          | Un dossier `.app`, un fichier `.ipa` ou un dossier `.xcarchive`                           |
| `-f, --format`     | Ce qui est affiché : `tty` (par défaut, un tableau), `markdown` ou `json`                 |
| `-o, --out <file>` | Écrit aussi le rapport JSON dans un fichier ; les dossiers manquants sont créés           |
| `--top <n>`        | Combien d'éléments, de langues et de binaires lister (10 par défaut)                      |
| `--color`          | `auto` n'utilise les couleurs que dans un terminal, et pas lorsque `NO_COLOR` est définie |
| `-q, --quiet`      | N'affiche rien (avec `--out`)                                                             |

Code de sortie : `0` lorsque le rapport a été produit, `2` lorsque l'entrée n'a pas pu être lue ou que le
rapport n'a pas pu être écrit (une ligne sur la sortie d'erreur standard en donne la raison), `64` pour
des options invalides. `1` est réservé à la commande `budget` prévue.

```sh
# Keep the report for later
sizeledger analyze build/MyApp.ipa --out size/main.json

# Markdown in a GitHub Actions job summary
sizeledger analyze build/MyApp.xcarchive --format markdown >> "$GITHUB_STEP_SUMMARY"

# The ten biggest files anywhere in the bundle (bytes and file name)
jq -r '[.tree | .. | objects | select(has("children") | not)] | sort_by(-.bytes) | .[:10][] | "\(.bytes)\t\(.name)"' size/main.json
```

La structure du JSON est décrite dans l'[article DocC](https://muhittincamdali.github.io/sizeledger/documentation/sizeledgerkit/jsonlayout) ;
[Fixtures/snapshots](Fixtures/snapshots) contient des rapports complets.

## Les trois tailles

| Taille                                             | Signification                                                                             | Pour SampleShop 2.0 |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------- |
| Total (`bytes`)                                    | Les fichiers additionnés, ce qu'affiche un gestionnaire de fichiers                       | 8.75 MB             |
| Taille d'installation, estimation (`installBytes`) | Chaque fichier arrondi au supérieur en blocs entiers de 4 KiB, comme les stocke APFS      | 8.80 MB             |
| Compressé dans le `.ipa` (`compressedBytes`)       | Ce que les fichiers du bundle occupent dans l'archive ; uniquement pour une entrée `.ipa` | 2.72 MB             |

Aucune n'est la taille de téléchargement ou d'installation de l'App Store : l'App Store adapte l'app à
chaque appareil (thinning), chiffre les binaires et compresse le téléchargement. Ces chiffres sont donnés
par l'App Thinning Size Report de Xcode et par App Store Connect. sizeledger donne ceux que l'on peut
obtenir à partir des seuls fichiers, sur n'importe quelle machine et pour chaque build.
[Pourquoi la taille d'installation est une estimation](docs/guides/why-install-size-is-an-estimate.md)
détaille tout cela, et [Limites de taille des App Clips](docs/guides/app-clip-size.md) l'applique aux
App Clips.

## Comment c'est testé

- **Contre `du`**, le contrôle d'acceptation de la v0.1, sur les deux versions de SampleShop extraites du
  `.ipa`. Sur un Mac (Apple silicon, macOS 27.0.1, APFS), l'estimation d'installation est exactement égale
  à `du -sk` et le total est à moins de 0.16% de `du -A` ; dans le conteneur Linux (swift:6.4.1-noble,
  aarch64), le total est égal à `du -b --apparent-size` et l'estimation d'installation est à moins de
  0.65% de `du -sk`, qui y compte aussi 4 KiB par dossier. Les tests échouent au-delà de 1% dans les deux
  cas.
- **Snapshots** : les rapports JSON, texte et Markdown des deux versions sont commités ; les mêmes
  snapshots passent sous macOS et sous Linux.
- **Une vraie app** : SampleShop est compilée avec `swiftc`, `actool` et `codesign` par
  [un script](Fixtures/scripts/build-sample-app.sh) et s'exécute dans le simulateur iOS 27.0 :

    <picture><source media="(prefers-color-scheme: dark)" srcset="docs/media/sampleshop-ios27-simulator-dark.png"><source media="(prefers-color-scheme: light)" srcset="docs/media/sampleshop-ios27-simulator-light.png"><img src="docs/media/sampleshop-ios27-simulator-light.png" alt="SampleShop 2.0 dans l'iOS 27 Simulator : une bannière et une liste de produits avec images et prix" width="240"></picture>

- **Lecteurs vérifiés par rapport à des références** : le décodeur DEFLATE par rapport à la sortie de
  zlib pour les blocs stored, fixed et dynamic ; le parseur Mach-O sur des fichiers thin, 32 bits, fat et
  fat64 ; ainsi que ZIP64, les archives endommagées et les noms de fichiers qui contiennent des séquences
  d'échappement de terminal.

Au total, 100 tests, exécutés par la CI sous macOS et sous Linux (x86_64 et arm64). Mesurer SampleShop 2.0
prend une médiane de 10.5 ms sur 21 exécutions, sur un Mac (Apple silicon) avec le build release,
démarrage du processus compris ; [scripts/bench.sh](scripts/bench.sh) refait la mesure.

## Limites

- Les tailles sont des mesures locales. Les tailles de téléchargement et d'installation de l'App Store
  dépendent du thinning, du chiffrement et de la compression appliqués chez Apple ; sizeledger donne donc
  une estimation et le dit.
- Les asset catalogs (`Assets.car`) sont comptés comme des fichiers ; les renditions qu'ils contiennent ne
  sont pas encore listées (prévu pour la 0.8, via `assetutil` sous macOS).
- Les métadonnées Swift correspondent à la taille des sections `__swift5_*`, une borne inférieure : une
  partie des métadonnées se trouve dans `__const`.
- Les bundles de style iOS (iOS, iPadOS, tvOS, watchOS, visionOS) sont classés. Une `.app` macOS avec un
  dossier `Contents/` est mesurée, mais ses fichiers sont rangés sous « Other resources ».
- Un `.ipa` contenant plusieurs apps, des entrées chiffrées, une compression autre que stored et DEFLATE
  ou un chemin d'entrée avec un composant `..` est refusé avec un message, sans deviner.
- Pour atteindre un en-tête Mach-O situé loin dans une entrée compressée d'un `.ipa`, sizeledger
  décompresse tout ce qui le précède et ne garde qu'une fenêtre de 32 KiB ; une entrée forgée coûte
  donc du temps, pas de la mémoire : environ 1 s par GB décompressé sur un Mac (Apple silicon).

## Documentation

- [Guides](docs/guides/) : lire votre première répartition, l'estimation de la taille d'installation, les
  limites de taille des App Clips, les vérifications de taille en CI.
- [Documentation de l'API](https://muhittincamdali.github.io/sizeledger/) (DocC) de SizeLedgerKit, avec une
  prise en main et la structure du JSON.
- [Exemples](Examples/) : un programme Swift basé sur SizeLedgerKit et un workflow GitHub Actions.
- [Journal des modifications](CHANGELOG.md).

## Contribuer

Ce qui aide le plus, ce sont les rapports de bug accompagnés d'une petite app qui montre le problème.
Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour la compilation, les tests et les snapshots, et
[SECURITY.md](SECURITY.md) pour signaler une vulnérabilité en privé.

## Licence

[MIT](LICENSE)
