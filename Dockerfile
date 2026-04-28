# Stage 1: Build Hugo site
ARG HUGO_VERSION
ARG NGINX_VERSION

# Stage 1: Build Hugo site
FROM debian:bookworm-slim AS builder

ARG HUGO_VERSION
ARG IMAGE_VERSION=dev
ARG GIT_COMMIT=unknown

RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates && \
    TARGETARCH="$(dpkg --print-architecture)" && \
    case "${TARGETARCH}" in \
        amd64)  HUGO_ARCH="amd64" ;; \
        arm64)  HUGO_ARCH="arm64" ;; \
        *)      echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    wget -O hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz" && \
    tar -xzf hugo.tar.gz && \
    mv hugo /usr/local/bin/hugo && \
    rm -rf hugo.tar.gz /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN if echo "$IMAGE_VERSION" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then \
      FILE_VERSION=$(cat VERSION); \
      TAG_VERSION=$(echo "$IMAGE_VERSION" | sed 's/^v//'); \
      if [ "$FILE_VERSION" != "$TAG_VERSION" ]; then \
        echo "ERROR: VERSION file (${FILE_VERSION}) does not match image tag (${IMAGE_VERSION})"; \
        exit 1; \
      fi; \
      echo "OK: VERSION file matches tag: ${FILE_VERSION}"; \
    else \
      echo "INFO: Non-release build (${IMAGE_VERSION}), skipping VERSION file check"; \
    fi

ARG BASE_URL=

ENV HUGO_PARAMS_APPVERSION=$IMAGE_VERSION
ENV HUGO_PARAMS_GITCOMMIT=$GIT_COMMIT

RUN hugo --minify --environment production ${BASE_URL:+--baseURL "$BASE_URL"}

# Stage 2: Serve with Nginx (Alpine)
FROM nginx:${NGINX_VERSION}-alpine

ARG IMAGE_VERSION=dev
ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown

COPY --from=builder /src/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN sed -i "s/__APP_VERSION__/${IMAGE_VERSION}/" /etc/nginx/conf.d/default.conf \
    && printf '{"version":"%s","commit":"%s","built":"%s"}\n' \
       "${IMAGE_VERSION}" "${GIT_COMMIT}" "${BUILD_DATE}" \
       > /usr/share/nginx/html/version.json

RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /usr/share/nginx/html \
    && chown -R appuser:appgroup /var/cache/nginx \
    && chown -R appuser:appgroup /var/log/nginx \
    && touch /var/run/nginx.pid \
    && chown appuser:appgroup /var/run/nginx.pid

USER appuser

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -qO- http://localhost:8080/ || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
