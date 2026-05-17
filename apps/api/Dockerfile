# ----- builder -----
FROM node:20-bookworm-slim AS builder

WORKDIR /repo

# Use a deterministic install. We copy the whole workspace because the API
# depends on the root prisma/ schema and the npm workspaces graph.
COPY package.json package-lock.json* ./
COPY apps/api/package.json apps/api/package.json
COPY packages packages
COPY prisma prisma

# Install all deps (incl. dev) so we can run `nest build` + `prisma generate`.
RUN npm install --no-audit --no-fund --workspaces

# Bring in source after the install layer for better caching.
COPY apps/api apps/api
COPY tsconfig.base.json* ./

# Generate Prisma client + build the API.
RUN npx prisma generate
RUN npm run build -w api

# Prune dev deps for the runtime image.
RUN npm prune --omit=dev --workspaces


# ----- runtime -----
FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production
WORKDIR /app

# Copy only what the runtime needs: compiled JS, node_modules, prisma schema
# + migrations (so `prisma migrate deploy` can run on boot if you want), and
# package manifests for module resolution.
COPY --from=builder /repo/apps/api/dist ./dist
COPY --from=builder /repo/node_modules ./node_modules
COPY --from=builder /repo/apps/api/node_modules ./apps/api/node_modules
COPY --from=builder /repo/apps/api/package.json ./apps/api/package.json
COPY --from=builder /repo/package.json ./package.json
COPY --from=builder /repo/prisma ./prisma

# Persistent upload directory (override with UPLOADS_DIR pointing at a
# volume / object-store mount in real deployments).
RUN mkdir -p /app/uploads
ENV UPLOADS_DIR=/app/uploads

EXPOSE 3000

# Default command: serve the compiled API. Override with a different CMD or
# pre-step (e.g., `prisma migrate deploy && node apps/api/dist/main`) when
# your deployment pipeline runs migrations on boot.
CMD ["node", "apps/api/dist/main"]
