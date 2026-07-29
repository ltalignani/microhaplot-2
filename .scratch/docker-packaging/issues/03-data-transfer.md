---
status: closed
type: wayfinder:grilling
---

## Question

Comment l'utilisateur non-bioinformaticien fait-il transiter ses fichiers
(BAM/VCF/TSV en entrée, .rds en sortie) vers/depuis les conteneurs ?

## Resolution

**Un dossier local monté en volume.** Un seul dossier sur la machine de
l'utilisateur (ex: `~/microhaplot-data`) est monté dans les deux
conteneurs ; il y dépose ses fichiers d'entrée et y retrouve les .rds en
sortie, sans jamais avoir à taper `docker cp` ou manipuler l'interface
Shiny pour le transfert de fichiers volumineux.
