---
status: closed
type: wayfinder:grilling
---

## Question

Comment les deux apps (main + prep) doivent-elles s'articuler côté Docker :
une image unique en un seul conteneur, une image unique avec deux services
docker-compose, ou deux images Docker séparées ?

## Resolution

**Une seule image, deux services via docker-compose.** Même Dockerfile
(mêmes dépendances R/Perl/samtools) construit une image unique ; le
docker-compose.yml lance deux conteneurs/ports distincts — un pour le
wizard de préparation, un pour l'app de visualisation — partageant un
volume de données commun (voir [Partage des .rds entre les deux
conteneurs](09-rds-sharing.md)).
