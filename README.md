# srv6lab

A self-contained lab for experimenting with **SRv6 (Segment Routing over IPv6)** on top
of an OSPFv3 underlay. It builds a virtual multi-router network entirely out of Linux
network namespaces and containerized [FRRouting][frr] routers — no VMs or external
hardware required.

[frr]: https://frrouting.org/

## What it builds

The lab instantiates **11 routers** and wires them together with veth pairs:

- **2 Provider-Edge (PE) routers**: `pe1`, `pe2`
- **9 Provider (P) core routers** arranged in a 3×3 grid: `p11 p12 p13 / p21 p22 p23 / p31 p32 p33`

Each router runs in its own network namespace as an `frrouting/frr` container (via Podman).
The connectivity forms a multi-stage fabric:

```
        ┌───────┐   full mesh   ┌───────┐   full mesh   ┌───────┐
 pe1 ──▶│ col1  │ ────────────▶ │ col2  │ ────────────▶ │ col3  │◀── pe2
        │p11 p21│               │p12 p22│               │p13 p23│
        │p31    │               │p32    │               │p33    │
        └───────┘               └───────┘               └───────┘
```

- `pe1` connects to every node in column 1 (`p11 p21 p31`).
- `pe2` connects to every node in column 3 (`p13 p23 p33`).
- Every node in column *N* is fully meshed with every node in column *N+1`
  (column 1↔2 and 2↔3, 9 links each).

That is **24 point-to-point links** in total.

## Addressing scheme

All addresses live under the documentation prefix `2001:db8:1::/48` (the `domain_global`).
The hextets intentionally encode **region** and **node**, which makes the scheme friendly
to SRv6 locators/segments.

| Entity | Region ID | Node ID |
| --- | --- | --- |
| `pe1` | 1 | 1 |
| column 1 (`p11 p21 p31`) | 2 | row number (1–3) |
| column 2 (`p12 p22 p32`) | 3 | row number (1–3) |
| column 3 (`p13 p23 p33`) | 4 | row number (1–3) |
| `pe2` | 5 | 1 |

- **Loopback (`lo`)** — `<domain>:<region><node>::/64`
  e.g. `pe1` → `2001:db8:1:101::/64`, `p22` → `2001:db8:1:302::/64`.
- **Point-to-point links** — `<domain>:<src_region><src_node>::<dst_region><dst_node>:<order>/127`,
  where the trailing `order` bit (0/1) distinguishes each end of the link.

The `make_address` and `make_ptp_address` helpers in `init.d/02-assign-addresses.sh`
compose these by shifting the 8-bit region and node IDs into a single hextet.

## The init.d / deinit.d scripts

The scripts are numbered and meant to run in order. `init.d/` brings the lab up;
`deinit.d/` tears it down in reverse.

### `init.d/` — bring up the lab

| Script | Purpose |
| --- | --- |
| `00-create-netns.sh` | Creates the 11 namespaces, brings up `lo`, and enables IPv6 forwarding in each. |
| `01-connect-netns.sh` | Creates the veth pairs between namespaces to build the fabric topology above. |
| `02-assign-addresses.sh` | Computes region/node IDs, assigns loopback and `/127` point-to-point IPv6 addresses. |
| `03-create-node-directories.sh` | Stages a per-node `frr.conf.d` config dir under `nodes/<node>/` from the shared template, writing hostname + logging into `frr.conf`. |
| `04-launch-frr.sh` | Launches one `frrouting/frr:10.6.1` container per namespace via Podman, joined to its namespace (`--network ns:/run/netns/<node>`) with the relevant networking caps. |
| `05-config-frr.sh` | Configures the **OSPFv3 underlay** through `vtysh`: sets each router's router-ID (`<region>.<node>.0.0`), enables OSPFv3 area 0 on all interfaces (loopback as passive, transit links as point-to-point), and saves the config. |

### `deinit.d/` — tear down the lab

| Script | Purpose |
| --- | --- |
| `07-teardown-frr.sh` | Stops all 11 `frr-<node>` containers (they were launched with `--rm`, so they self-remove on stop). |
| `08-remove-node-directories.sh` | Deletes the staged `nodes/` config tree. |
| `09-teardown-netns.sh` | Deletes the 11 network namespaces (which also removes their veth links). |

## Running

Bring the lab up by executing the `init.d` scripts in numeric order, and tear it down
with the `deinit.d` scripts in numeric order, e.g.:

```bash
# bring up
for s in init.d/*.sh; do bash "$s"; done

# tear down
for s in deinit.d/*.sh; do bash "$s"; done
```

> Requires root (for `ip netns`), Podman, and the `frrouting/frr:10.6.1` image.

## Notes

- The base container template lives in [`frr.conf.d/`](frr.conf.d/); per-node runtime
  configs are generated under `nodes/<node>/frr.conf.d/`.
- `launch_frr.sh` is a leftover single-container launcher for a `dn42` namespace and is
  not part of the numbered init/deinit workflow.
