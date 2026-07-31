FROM node:22-alpine AS dependencies

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

FROM dependencies AS builder

WORKDIR /app
COPY . .
RUN pnpm build

FROM node:22-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/.next ./.next
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/db ./db
COPY --from=builder --chown=node:node /app/scripts ./scripts
COPY --from=builder --chown=node:node /app/package.json ./
COPY --from=builder --chown=node:node /app/pnpm-lock.yaml ./
COPY --from=builder --chown=node:node /app/pnpm-workspace.yaml ./
COPY --from=builder --chown=node:node /app/next.config.ts ./
COPY --from=builder --chown=node:node /app/tsconfig.json ./

USER node
EXPOSE 3000

CMD ["sh", "-c", "node node_modules/tsx/dist/cli.mjs scripts/migrate.ts && node node_modules/next/dist/bin/next start --hostname 0.0.0.0"]
