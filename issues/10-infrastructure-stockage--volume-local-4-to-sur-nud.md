# #10 — Infrastructure stockage : volume local 4 To sur nœud K3s

## What to build

Configure the 4 TB local disk (to be physically installed on the K3s node skat3.ird.fr) as a PersistentVolume for microhaplot2, replacing the `hostPath` development volume used during development.

End-to-end: BAM files deposited by researchers in the designated directory on the local disk are accessible read-only to the microhaplot2 pod via a K8s PersistentVolumeClaim, bound to the `MICROHAPLOT_DATA_DIR` mount point inside the container.

Key elements:
- K8s **PersistentVolume** of type `local` pointing to the mount path of the 4 TB disk on the node.
- K8s **PersistentVolumeClaim** bound to that PV, access mode `ReadOnlyMany`.
- **StorageClass** with `volumeBindingMode: WaitForFirstConsumer` and `reclaimPolicy: Retain`.
- Update the Deployment manifest to mount the PVC at `/data/lovelace`.
- Document the disk preparation steps (partition, format ext4, mount, fstab entry) for the sysadmin.
- Define a directory convention on the disk for user data (e.g. `/data/lovelace/<project>/<bam_files>`).

## Acceptance criteria

- [ ] Disk is mounted and stable across node reboots (fstab entry)
- [ ] PV and PVC are Bound in the `tools` namespace
- [ ] Pod mounts the volume at `/data/lovelace` (read-only)
- [ ] A test BAM file placed on the disk is visible from inside the running pod
- [ ] `hostPath` dev volume removed from production Deployment manifest

## Blocked by

- Physical disk installation on skat3.ird.fr (ops prerequisite — HITL)
- Issue #
