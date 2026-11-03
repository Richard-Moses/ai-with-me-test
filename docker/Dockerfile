# Build context is the repo root:  docker build -f docker/Dockerfile -t <dockerhub_user>/oeson-microservice:1.0.0 .

# ---- Stage 1: install production dependencies ----
FROM node:18-alpine AS build
WORKDIR /app
COPY app/package*.json ./
RUN npm ci --omit=dev

# ---- Stage 2: minimal runtime image ----
FROM node:18-alpine
ENV NODE_ENV=production \
    PORT=8080
WORKDIR /app

# Non-root user "appuser" with a fixed numeric UID (Kubernetes runAsNonRoot needs a numeric UID)
RUN addgroup -S -g 10001 appgroup && adduser -S -u 10001 -G appgroup appuser

COPY --from=build /app/node_modules ./node_modules
COPY app/package*.json ./
COPY app/src ./src
COPY docker/entrypoint.sh ./entrypoint.sh

USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["sh", "/app/entrypoint.sh"]
