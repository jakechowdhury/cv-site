---
title: "CV Platform — Building a Production-Grade Portfolio"
date: 2026-03-01
description: >
  How I built this CV site using k3s, ArgoCD, Hugo, Tailscale Funnel, and Oracle OKE —
  deliberately over-engineered as a portfolio piece.
tags:
  - kubernetes
  - gitops
  - argocd
  - terraform
  - homelab
  - devops
ShowToc: true
TocOpen: false
ShowReadingTime: true
ShowBreadCrumbs: true
---

## What Is This?

This CV website is deliberately over-engineered. The goal was never just to put a CV online — it was to build a production-grade platform that demonstrates the full DevOps stack, end to end, from bare metal to public traffic.

## The Stack

```
Proxmox → Packer → OpenTofu/Terragrunt → Ansible
→ k3s HA cluster → ArgoCD → Hugo + Nginx
→ Tailscale Funnel → OCI OKE (cloud mirror)
```

## Infrastructure

### Homelab

A ThinkCentre running Proxmox hosts three Ubuntu 24.04 VMs (2 vCPU / 4 GB / 20 GB each). The VM template is built with Packer — baking in `qemu-guest-agent`, disabled swap, and the kernel modules k3s needs. OpenTofu + Terragrunt clones the template and applies cloud-init to set hostnames, SSH keys, and static IPs. Ansible handles OS configuration and bootstraps a three-node k3s HA cluster with embedded etcd.

Remote state lives in an S3 bucket (`cv-platform-tofu-state`, eu-west-2), encrypted and versioned.

### Cloud — Oracle OKE

The cloud mirror runs on Oracle Cloud Always Free (upgraded to PAYG for OKE). Two Ampere A1 Flex nodes (ARM, 2 OCPU / 12 GB each) form an OKE Basic cluster — free tier, no control plane charge. Because the nodes are ARM, all images are built multi-arch (`docker buildx`, `linux/amd64` + `linux/arm64`) and pushed to GitHub Container Registry.

Monitoring (kube-prometheus-stack) lives here rather than on the homelab — the 20 GB homelab disks are too tight for Prometheus retention alongside k3s, etcd, and ArgoCD.

### GitOps

ArgoCD manages everything post-bootstrap using the App of Apps pattern. Both clusters — homelab and OKE — read from the same `cv-gitops` repository, pointing at different Kustomize overlays. When `cv-site` CI builds a new image, it opens a PR to `cv-gitops` bumping the image tag. On merge, both clusters auto-sync.

ArgoCD itself is installed via the OpenTofu Helm provider, pinned to a specific version. Renovate opens PRs to bump it.

### Public Access

Tailscale Funnel handles TLS termination and public ingress — no cert-manager required, no LoadBalancer needed. The site is reachable at a custom domain over HTTPS with zero manual certificate management.

## Key Decisions

| Decision | Rationale |
|---|---|
| **OpenTofu over Terraform** | BSL licence change in 2023; signals awareness of the open source ecosystem |
| **Terragrunt** | Keeps S3 backend config DRY; `dependency` blocks enforce provisioning order |
| **Kustomize for the app, Helm for infra** | Own manifests are simple — no Helm overhead; third-party infra benefits from Helm's values system |
| **Renovate over Dependabot** | Detects Terraform providers, Helm chart versions, GitHub Actions — not just npm packages |
| **OKE alongside k3s** | Homelab shows self-managed k8s from scratch; OKE shows managed k8s. Same GitOps pipeline — demonstrates portability |

## Repositories

| Repo | Purpose |
|---|---|
| `cv-platform` | Homelab IaC — Packer, OpenTofu/Terragrunt, Ansible |
| `cv-site` | Hugo source, Dockerfile, GitHub Actions CI |
| `cv-gitops` | ArgoCD Applications + Kubernetes manifests |
| `cv-platform-oci` | OCI/OKE Terraform (separate — state contains sensitive data) |

## Security

- **Checkov** runs on all Terraform and Kubernetes manifests in CI, including Renovate PRs
- **Trivy** scans images on every build
- **SecurityContext** enforced on all pods (non-root, read-only filesystem, dropped capabilities)
- **Sealed Secrets** for any secrets that must live in git

## What I'd Do Differently

If I were building this for a production product rather than a portfolio, I'd use a managed Kubernetes service from day one and skip the homelab complexity. The homelab k3s cluster exists precisely to demonstrate I understand what managed services abstract away — not because it's the right choice for most production workloads.
