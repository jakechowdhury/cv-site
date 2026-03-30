# ── Stage 1: Build Hugo site ──────────────────────────────────────────────────
FROM hugomods/hugo:exts AS builder

WORKDIR /src

# Clone PaperMod theme directly — no submodule or go.mod needed
RUN git clone --depth 1 https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod

# Copy source (themes/ is now populated above, .dockerignore should exclude local themes/)
COPY . .

# Build — minify, no drafts
RUN hugo --minify --environment production

# ── Stage 2: Serve with Nginx (Alpine) ────────────────────────────────────────
FROM nginx:alpine

# Non-root user (matches SecurityContext in k8s manifests)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy built site
COPY --from=builder /src/public /usr/share/nginx/html

# Minimal Nginx config — security headers, cache headers for static assets
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Fix permissions
RUN chown -R appuser:appgroup /usr/share/nginx/html \
    && chown -R appuser:appgroup /var/cache/nginx \
    && chown -R appuser:appgroup /var/log/nginx \
    && touch /var/run/nginx.pid \
    && chown appuser:appgroup /var/run/nginx.pid

USER appuser

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]