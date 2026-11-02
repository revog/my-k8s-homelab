# <TBD> Barman Cloud CNPG-I Backup plugin

This documents the Barman cloud plugin backup system for Cloudnative-PG based databases. It uses Barman as the backup engine with two backup destinations following a **2-2-1 strategy**: local NFS and offsite Cloudflare R2.

---

## Architecture Overview

### Backup Strategy

```
┌──────────────────────────────────────────┐
│              Application PVC             │
└──────────────────────┬───────────────────┘
                       │
         VolSync ReplicationSources
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
   ┌───────────┐               ┌───────────┐
   │ Local NFS │               │Cloudflare │
   │  (QNAP)   │               │    R2     │
   │ (primary  │               │ (offsite  │
   │  restore) │               │  DR only) │
   └─────┬─────┘               └───────────┘
         │
         │ QNAP Hybrid Backup
         │ (NAS-to-NAS mirror)
         ▼
   ┌───────────┐
   │  Offsite  │
   │    NAS    │
   │  device   │
   └───────────┘

  3 copies, 2 storage types, 1+ offsite  ✓ 3-2-1
```
