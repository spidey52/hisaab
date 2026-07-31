FROM oven/bun:1.3-alpine AS dependencies

WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

FROM oven/bun:1.3-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production

COPY --from=dependencies /app/node_modules ./node_modules
COPY package.json ./
COPY tsconfig.json ./
COPY drizzle.config.ts ./
COPY drizzle ./drizzle
COPY src ./src

USER bun
EXPOSE 3001

CMD ["sh", "-c", "bun run src/db/migrate.ts && bun run src/index.ts"]
