FROM node:24.21.0-trixie-slim@sha256:173f125896c3b47ddf056734c7ea789d04595a6a08769a8f78e0df642781fb66 AS node

FROM node AS build
ARG PNPM_VERSION
ARG SERVICE
RUN npm install --global pnpm@${PNPM_VERSION}
WORKDIR /repo
COPY . .
RUN pnpm install --frozen-lockfile --filter ./${SERVICE}...
RUN pnpm --filter ./${SERVICE}... run build
RUN pnpm --filter ./${SERVICE} deploy --prod /out

FROM node AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /out .
USER node
CMD ["node", "dist/index.js"]
