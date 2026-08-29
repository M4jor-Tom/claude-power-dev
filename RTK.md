# RTK - Rust Token Killer

**Usage**: Proxy CLI optimisé tokens (60-90 % d'économie sur les opérations de dev)

## Meta commandes (toujours utiliser rtk directement)

```bash
rtk gain              # Analytics des économies de tokens
rtk gain --history    # Historique des commandes avec économies
rtk discover          # Analyse l'historique Claude Code pour repérer les opportunités manquées
rtk proxy <cmd>       # Exécute une commande brute sans filtrage (debug)
```

## Vérification de l'installation

```bash
rtk --version         # Doit afficher : rtk X.Y.Z
rtk gain              # Doit fonctionner (et non « command not found »)
which rtk             # Vérifier le bon binaire
```

⚠️ **Collision de nom** : si `rtk gain` échoue, vous avez peut-être reachingforthejack/rtk (Rust Type Kit) installé à la place.

## Usage via hook

Toutes les autres commandes sont automatiquement réécrites par le hook Claude Code.
Exemple : `git status` → `rtk git status` (transparent, 0 token d'overhead).
