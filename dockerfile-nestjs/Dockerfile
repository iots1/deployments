# Stage 1: Build
FROM node:22.3-alpine AS builder

WORKDIR /app

# Copy only necessary files first for cache optimization
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install

# Now copy the rest
COPY . .

# Build NestJS project
RUN yarn build

# Stage 2: Production
FROM node:22.3-alpine AS production

WORKDIR /app

# Copy only what's needed from the build stage
COPY --from=builder /app/dist ./dist
# COPY --from=builder /app/assets ./assets
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# Optional: Set Timezone
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
    echo "Asia/Bangkok" > /etc/timezone && \
    apk del tzdata

ENV TZ=Asia/Bangkok
ENV ENV=prod

EXPOSE 3000

CMD ["node", "dist/main"]