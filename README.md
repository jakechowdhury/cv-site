# cv-site

Personal CV and portfolio site built with Hugo, containerised with Docker, and deployed via a GitOps pipeline.

Live at [cv.jakechowdhury.co.uk](https://cv.jakechowdhury.co.uk)

## Stack

| Layer | Technology |
|---|---|
| Static site generator | [Hugo](https://gohugo.io/) v0.161.0 (extended) |
| Theme | [PaperMod](https://github.com/adityatelange/hugo-PaperMod) |
| Web server | Nginx v1.30.0 (Alpine) |
| Container registry | GitHub Container Registry (GHCR) |
| Deployment | GitOps via [cv-gitops](https://github.com/jakechowdhury/cv-gitops) |

## Architecture

The site is built as a multi-stage Docker image:

1. **Build stage** — Hugo compiles and minifies the static site
2. **Runtime stage** — Nginx serves the output on port 8080 as a non-root user

Version pinning for Hugo and Nginx is managed in [`versions.env`](versions.env) and kept up to date automatically via [Renovate](https://docs.renovatebot.com/).

## Local development

**Prerequisites:** Hugo (extended) v0.161.0, Docker, pre-commit

```bash
# Clone with theme submodule
git clone --recurse-submodules git@github.com:jakechowdhury/cv-site.git

# Install pre-commit hooks
pre-commit install
```

```bash
make          # list available targets

make dev      # Hugo dev server at http://localhost:1313 (live reload, drafts visible)
make build    # build Docker image
make run      # run container at http://localhost:8080
make stop     # stop running container
make lint     # run all pre-commit hooks
```

## CI/CD

All pipelines are defined in [`.github/workflows/`](.github/workflows/).

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | Pull request | Builds image, runs Trivy scan, validates version bump, deploys PR preview |
| `release.yml` | `v*.*.*` tag | Builds multi-arch image (amd64/arm64), pushes to GHCR, opens PR in cv-gitops |
| `security.yml` | Changes to `Dockerfile`, `nginx.conf`, workflows | Runs Checkov, gixy |

### Releasing

1. Bump [`VERSION`](VERSION) in your branch
2. Raise a PR — CI validates the version has been incremented
3. Merge to `main`
4. `make release` — tags the commit and pushes, triggering the release pipeline

## Security

- Container runs as a non-root user
- Trivy scans block on `HIGH`/`CRITICAL` CVEs
- Nginx security headers configured (CSP, `X-Frame-Options`, `X-Content-Type-Options`)
- Secrets scanning via TruffleHog on every PR
- Dockerfile and workflow IaC scanning via Checkov
- Nginx config scanning via gixy
