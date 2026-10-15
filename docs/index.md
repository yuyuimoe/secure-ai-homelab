<div align="center" markdown>

<img src="assets/secure-ai-homelab-logo.svg" alt="Secure AI Homelab" width="360" />

# Secure AI Homelab

Recipes for self-hosting AI coding agents with real isolation — OpenShell behind
Pangolin's zero-trust VPN, with Rauthy as the OIDC identity provider.

[OpenShell + Pangolin recipe](guides/openshell-pangolin.md){ .md-button .md-button--primary }

</div>

## OpenShell over Pangolin

```mermaid
flowchart LR
    CLI["openshell CLI"] --> VPN["Pangolin client VPN"]
    VPN --> PS["Pangolin server"]
    PS --> NEWT["Newt (VPS)"]
    NEWT --> GW["OpenShell gateway<br/>127.0.0.1:17670"]
    GW --> SBX["sandboxes"]
    BROWSER["browser"] --> IDP["Rauthy"]
    GW -. "JWKS" .-> IDP
```

Each person reaches a shared OpenShell gateway through the Pangolin VPN. OpenShell
runs each agent in a kernel-enforced sandbox with deny-by-default network policy,
so a shared gateway stays safe even when agents are untrusted. Rauthy provides
the OIDC login, and one account signs into both Pangolin and OpenShell.

**Start here:** [OpenShell over Pangolin](guides/openshell-pangolin.md).

## Verify the host

OpenShell needs Linux 6.2+, Landlock, nested seccomp user notifications, and an
x86-64-v2-or-newer CPU. Check before deploying:

```bash
./scripts/check-openshell-host.sh --probe --container
```
