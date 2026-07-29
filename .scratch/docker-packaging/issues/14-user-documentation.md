---
status: closed
type: wayfinder:task
blocked_by: ["12-compose-design.md", "13-ci-publish-workflow.md"]
---

## Question

Rédiger la documentation utilisateur pour l'usage via Docker (section
README, à l'image de la section "Field Genotyping Prep app" et
"Troubleshooting" existantes) :

- Prérequis : installer Docker Desktop (lien officiel par OS).
- Récupérer le `docker-compose.yml` (sans cloner le repo, voir
  [Distribution de l'image](05-distribution.md)).
- Commande de lancement unique (voir [UX de lancement](04-launch-ux.md)),
  et comment configurer/pointer le dossier de données partagé (voir
  [Transfert de fichiers utilisateur](03-data-transfer.md)).
- Mentionner explicitement le bénéfice Windows/BAM levé sous Docker (voir
  [Windows/BAM sous Docker](06-windows-bam-restriction.md)).
- Note sur le support Mac/Linux prioritaire et Windows non garanti pour ce
  premier jalon (voir [Priorité plateformes cible](08-platform-priority.md)).

## Resolution

**Nouvelle section README, `## Run microhaplot with Docker (recommended for
non-bioinformaticians)`, positionnée avant la section "Field Genotyping Prep
app" existante** (elle en devient l'alternative recommandée — la section R
manuelle reste documentée en dessous pour les utilisateurs bioinformaticiens
qui préfèrent l'installation R classique). Contenu ci-dessous, prêt à être
placé tel quel lors de `/implement` (styles/liens à ajuster au moment de
l'intégration finale) :

```markdown
## Run microhaplot with Docker (recommended for non-bioinformaticians)

If you'd rather not install R, Perl, or samtools yourself, both the main
microhaplot app and the field genotyping prep wizard are available as a
single Docker image — no R console, no package installation.

### Prerequisites

Install Docker Desktop for your OS:

- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) (Intel and Apple Silicon)
- [Docker Desktop for Linux](https://www.docker.com/products/docker-desktop/)

This first release targets Mac and Linux. It will likely also work on
Windows via Docker Desktop + WSL2, but that hasn't been tested yet.

### One-time setup

Download `docker-compose.yml` from this repo (no need to clone it):

​```sh
curl -O https://raw.githubusercontent.com/ltalignani/microhaplot-2/master/docker-compose.yml
​```

Create a folder on your machine where you'll drop your BAM/VCF/TSV files
and where the generated `.rds` files will appear:

​```sh
mkdir -p ./microhaplot-data
​```

### Launch

​```sh
docker compose up
​```

Then open:

- the field genotyping prep wizard at <http://localhost:3839>
- the main microhaplot app at <http://localhost:3838>

Both apps share the same `./microhaplot-data` folder — files you extract
in the prep wizard show up immediately in the main app, no copying, no
restart.

### A note for Windows and BAM files

The main package currently doesn't support BAM input directly on Windows
(only SAM). Running through Docker sidesteps this entirely: the
container is always Linux inside, regardless of your host OS, so BAM
input works the same way on Windows-via-Docker as it does on Mac or
Linux.

### Stopping

​```sh
docker compose down
​```

Your data stays in `./microhaplot-data` between runs.
```

**Positionnement des liens vers les décisions sous-jacentes** (pour la
traçabilité de ce spec, pas pour le README final) : prérequis Docker
Desktop et absence de clone git → [Distribution de l'image](05-distribution.md) ;
commande unique `docker compose up`/`down` → [UX de lancement](04-launch-ux.md) ;
dossier `./microhaplot-data` et ports 3838/3839 → [Transfert de fichiers
utilisateur](03-data-transfer.md) et [Conception du
docker-compose](12-compose-design.md) ; note Windows/BAM →
[Windows/BAM sous Docker](06-windows-bam-restriction.md) ; portée
Mac/Linux d'abord → [Priorité plateformes cible](08-platform-priority.md).

**Non inclus ici, volontairement :** la variable `MICROHAPLOT_UID`/`GID`
et le fichier `.env` (voir [Conception du docker-compose](12-compose-design.md))
ne sont pas mis en avant dans le quickstart — ils fonctionnent avec leurs
valeurs par défaut pour l'immense majorité des utilisateurs Mac ; les
mentionner dans une note ou un paragraphe "Troubleshooting" séparé
(à côté de la section Troubleshooting existante) plutôt que dans le chemin
principal, pour ne pas surcharger cognitivement l'utilisateur non-bioinfo
dès la première lecture.
