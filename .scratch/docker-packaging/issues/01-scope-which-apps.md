---
status: closed
type: wayfinder:grilling
---

## Question

Quelles applications microhaplot doivent être empaquetées dans Docker :
l'app principale (runShinyHaplot), le compagnon de préparation
(runShinyHaplotPrep), ou les deux ?

## Resolution

**Les deux apps.** Le contexte (dépendances système Perl + samtools pour le
support BAM) touche autant l'app principale que le wizard de préparation ;
dockeriser seulement l'une des deux laisserait l'utilisateur non-bioinfo
devoir installer R/Perl/samtools pour l'autre.
