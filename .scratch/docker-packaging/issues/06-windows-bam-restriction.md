---
status: closed
type: wayfinder:grilling
---

## Question

Le blocage actuel "BAM non supporté sur Windows" (dans `prepHaplotFiles`)
existe parce que le code tourne nativement sur l'OS hôte. Dans Docker,
l'intérieur du conteneur est toujours Linux, même si l'hôte est Windows.
Faut-il lever cette restriction quand l'exécution passe par Docker ?

## Resolution

**Oui — et aucun changement de code n'est nécessaire.** Le check existant
dans `prepHaplotFiles()` teste l'OS *du process R qui exécute le code*
(`.Platform$OS.type`), pas l'OS de la machine hôte. À l'intérieur d'un
conteneur Linux, ce check vaudra toujours `"unix"`, quel que soit l'hôte
(Windows via Docker Desktop/WSL2 compris) — la restriction BAM/Windows ne
se déclenche donc jamais sous Docker, de façon purement mécanique.

Seule la documentation doit mentionner ce bénéfice ; à vérifier lors du
ticket de rédaction de la doc ([Documentation utilisateur
Docker](14-user-documentation.md)).
