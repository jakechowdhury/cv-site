---
title: "CV Platform - Building a Portfolio"
date: 2026-03-01
description: >
  How I built this CV site using k3s, ArgoCD, Cloudflare, Hugo, and Oracle OKE -
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

## Why I Built This

This site is completely and deliberately over-engineered. My goal was to host not just my CV online but something I could point recruiters, interviewers, anyone to and say "here's how I work and how I think about infrastructure."

I already had a small homelab, so the natural starting point was a self-managed Kubernetes cluster from bare metal - VM templating with Packer, infrastructure provisioned with OpenTofu and Terragrunt, configuration managed with Ansible, all bootstrapped into a three-node k3s HA cluster running GitOps via ArgoCD.

From there I wanted to demonstrate cloud infrastructure using the same patterns. The OKE mirror cluster isn't there just to tick a cloud checkbox - it's there because building the self-managed version first means I actually understand what a managed service is doing for you.

## The Stack

```
Proxmox → Packer → OpenTofu/Terragrunt → Ansible
→ k3s HA cluster → ArgoCD → Hugo + Nginx
→ Cloudflare Tunnel → OCI OKE (cloud mirror)
```

The repositories:

| Repo | Purpose |
|---|---|
| [`cv-platform`](https://github.com/jakechowdhury/cv-platform) | Homelab IaC - Packer, OpenTofu/Terragrunt, Ansible |
| [`cv-site`](https://github.com/jakechowdhury/cv-site) | Hugo source, Dockerfile, GitHub Actions CI |
| [`cv-gitops`](https://github.com/jakechowdhury/cv-gitops) | ArgoCD Applications + Kubernetes manifests |
| [`cv-platform-oci`](https://github.com/jakechowdhury/cv-platform-oci) | OCI/OKE Terraform |


### Homelab - [cv-platform](https://github.com/jakechowdhury/cv-platform)

The homelab was my starting point - I already had a ThinkCentre running Proxmox for personal use. The first step was building a golden image with Packer, baking in everything the cluster nodes would need: qemu-guest-agent, swap disabled, and the kernel modules k3s requires. Getting this right once means every VM starts from a known, reproducible base.

From there I provisioned three VMs using OpenTofu with Terragrunt. Terragrunt keeps the S3 backend config DRY across modules and lets me share variables - like remote state location - without repeating them. Anything sensitive lives in an env file outside of version control; if this were pipeline-driven I'd use CI/CD variables instead, but this is intentionally run locally.

With three VMs ready I used Ansible to configure them into a k3s HA cluster with embedded etcd. I could have used an existing role from Ansible Galaxy but I wanted to write it myself - the point was to demonstrate how I approach configuration management, not just that I can install a community package.

### Public Access

I wanted a way to expose the site publicly without exposing my home network. I'd used Cloudflare Tunnels on a previous personal project and it suited this use case perfectly - no open ports on your router, TLS handled automatically, no cert-manager needed, no LoadBalancer needed, and most importantly - cost me nothing.

In a production environment - AWS for example - I'd approach this differently: an ingress controller (NGINX, Traefik) using external-dns to manage DNS records and cert-manager with Let's Encrypt for certificate management, sat behind a cloud load balancer. Cloudflare Tunnels is the right call here precisely because this isn't that - it lets me focus on the Kubernetes side of the project without the overhead of managing ingress infrastructure on a homelab.

The tunnel configuration is managed in the homelab repo using the same OpenTofu + Terragrunt pattern, and because both clusters share the same GitOps pipeline, any change to the tunnel config propagates to OKE automatically.

### GitOps - [cv-gitops](https://github.com/jakechowdhury/cv-gitops)

ArgoCD is a tool I've used extensively and it was the natural choice for keeping both clusters in sync. The setup uses an App of Apps pattern - a root Application on each cluster that manages the child Applications, meaning I only need to maintain one set of manifests regardless of how many clusters are reading from them.

Both clusters point at the same repo with no environment-specific overlays, which is intentional. The whole point of the OKE cluster is to be a true mirror of the homelab - if I introduced overlays I'd be managing drift, which defeats the purpose.

For the manifests themselves I used Kustomize for my own application resources and Helm for infrastructure components like Traefik. Helm makes sense there because third-party charts benefit from a values file and Renovate can track chart versions automatically - using Kustomize for everything would mean managing those versions manually.

Renovate is configured across all four repos, keeping Helm chart versions, Terraform providers, GitHub Actions, and container image tags up to date.

### The Website - [cv-site](https://github.com/jakechowdhury/cv-site)

I'll be upfront - I'm not a frontend developer and this isn't meant to be anything fancy. Hugo with a clean theme does the job: fast, static, no runtime to manage.

The Dockerfile uses a multistage build, compiling the Hugo site and copying the output into a small Nginx Alpine image to serve it. Because the homelab runs on x86 and the OCI nodes are ARM, images are built multi-arch using docker buildx (linux/amd64 + linux/arm64) and pushed to GitHub Container Registry.

The CI pipeline runs on every PR and covers two areas. The first is build and security validation: the image is built and scanned with Trivy, TruffleHog checks for accidentally committed secrets, Checkov scans the Dockerfile and GitHub Actions workflows, and Gixy runs against the Nginx config if it's been changed. There's also a preview deploy to GitHub Pages so the site can be reviewed before merging, and a check that the VERSION file has been bumped (skipped automatically on Renovate PRs via a label).

The release process is tag-driven. Once a PR is merged, a Makefile target handles checking out main, pulling, tagging, and pushing which triggers the release pipeline. That pipeline validates the tag, builds and pushes the multi-arch image to GHCR, signs it with Cosign for supply chain integrity, and opens a PR to cv-gitops bumping the image tag. From there ArgoCD takes over and both clusters sync automatically.

### Cloud Mirror - [cv-platform-oci](https://github.com/jakechowdhury/cv-platform-oci)

I hadn't worked with Oracle Cloud before this project, but the decision was straightforward - OCI offers the best free options for a managed Kubernetes cluster. The Always Free tier includes a free OKE control plane and two Ampere A1 Flex ARM nodes (2 OCPU / 12 GB each), which is more than enough to mirror the homelab workload at zero cost.

The repo follows the same patterns as cv-platform - OpenTofu with Terragrunt, env file for sensitive values, remote state in an S3-compatible bucket. Keeping the same structure across both repos was deliberate; it means anyone reading the code doesn't have to context-switch between different conventions.

I didn't add a CI/CD pipeline for the infrastructure here. For a personal project it's run locally, but in a production context I'd look at OIDC-based authentication from the pipeline rather than long-lived credentials, along with proper drift detection and cluster monitoring.

ArgoCD is deployed via Terraform's Helm provider using the same pinned version as the homelab cluster, and points at the same cv-gitops repo. From that point the GitOps pipeline is identical - both clusters are genuinely running the same workloads from the same source of truth.

---

### Security

Security tooling is consistent across all repos where possible. Pre-commit hooks run on every commit covering linting, formatting, secret detection, Checkov for static analysis, and terraform-docs to keep documentation in sync with the code automatically.

In CI, Checkov scans Terraform, Kubernetes manifests, and Dockerfiles. Trivy scans container images on every build and gates the push to GHCR - a failing scan means nothing gets published. TruffleHog runs on every PR to catch any secrets accidentally committed.

The most interesting security addition is Cosign. Every image built by the release pipeline is signed before it's pushed to GHCR. The cv-gitops repo then verifies that signature when a PR is raised to bump the image tag - if the image isn't signed by the expected key the PR is blocked. This closes off a supply chain attack vector where a compromised image could be swapped in without detection, even if it passed Trivy scanning.

---

### A note on AI

I used AI throughout this project - primarily Claude and Claude Code - as a tool for code generation, debugging, and working through problems.

The architecture decisions, tool choices, and overall design are my own and reflect how I'd approach this kind of work professionally. AI helped me move faster, but the thinking behind it didn't come from a prompt. No different to how you'd use Stack Overflow or read through documentation.

The aim of this site and the repos is still to show how I work and how I think about problems - that comes through in the decisions made and the code itself.

## What I'd Do Differently

If someone asked me to just host a static website, I'd put it on GitHub Pages or an S3 bucket with CloudFront in front of it - and that's actually where this site will end up once it's served its purpose as a portfolio piece. The Kubernetes stack exists to demonstrate the stack, not because it's the right tool for hosting a CV.

The infrastructure CI/CD is also incomplete. Running Terraform in a pipeline with OIDC-based authentication rather than local credentials, drift detection, and automated plan/apply on PR merge are all things I'd add in a production context. Similarly there's no monitoring here - no alerting if the site goes down, no metrics. For a personal project that's an acceptable trade-off; for anything production-grade it wouldn't be.
