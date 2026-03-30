---
title: "Why Is This Here?"
description: "A note on why this CV exists as a website rather than a PDF."
url: /why/
layout: page
ShowToc: false
---

> **Good question. Honestly? Because a PDF felt insufficient.**

### The Honest Answer

I spend most of my time building infrastructure that nobody directly sees — pipelines, clusters, automation. This site is a small experiment in making that work visible. If you're reading this, it worked.

### A Living Document

A CV on paper is a snapshot. This is meant to evolve. New roles, new tools, new opinions — it gets updated here first. Think of it as infrastructure for my career history, with slightly fewer Terraform modules.

### For Anyone Considering Working With Me

Whether you're a recruiter, a potential colleague, or a hiring manager — this should give you a clearer picture of how I think and what I've actually built, beyond a list of bullet points on a page.

### Because I Built It Myself

This site doesn't run on a managed hosting platform or a page builder. It's a Hugo static site, containerised with Docker, deployed via ArgoCD to a self-managed k3s cluster running on Proxmox — with a cloud mirror on Oracle OKE. Tailscale Funnel handles TLS and public ingress. The whole stack is defined in code across four GitHub repositories, scanned by Checkov and Trivy, and kept up to date by Renovate.

It felt right that the person maintaining production systems at scale could also maintain their own website — and explain every layer of it in an interview.

---

> *Want to dig into the infrastructure behind this site? Check out the [CV Platform project post](/posts/cv-platform/).*
