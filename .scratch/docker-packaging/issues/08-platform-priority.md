---
status: closed
type: wayfinder:grilling
---

## Question

Les utilisateurs cibles sont-ils uniquement sur Mac (Intel + Apple
Silicon) et Linux, ou faut-il aussi garantir/tester le fonctionnement sur
Windows (Docker Desktop + WSL2) dès ce premier jalon ?

## Resolution

**Mac (Intel + Apple Silicon) et Linux d'abord.** Build multi-arch
amd64+arm64 pour couvrir ces plateformes. Windows fonctionnera
probablement aussi via Docker Desktop/WSL2 (voir [Windows/BAM sous
Docker](06-windows-bam-restriction.md)) mais n'est pas testé/garanti dans
ce premier jalon — support Windows explicite laissé en zone d'ombre pour
un effort ultérieur si la demande se confirme.
