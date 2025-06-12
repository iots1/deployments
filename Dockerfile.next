ARG NODE_OPTIONS=--max-old-space-size=8192

## Stage 1: Install dependencies
FROM --platform=linux/amd64 node:22.3-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json yarn.lock* package-lock.json* ./
# Use yarn if yarn.lock exists, otherwise npm
RUN if [ -f yarn.lock ]; then \
    echo "Installing with Yarn..." && yarn install --frozen-lockfile; \
    elif [ -f package-lock.json ]; then \
    echo "Installing with npm..." && npm ci; \
    else \
    echo "No lockfile found. Installing with npm by default..." && npm install; \
    fi

# Clean caches
RUN npm cache clean --force
# RUN yarn cache clean # yarn install --frozen-lockfile should handle dependencies without cache issues if needed

## Stage 2: Build the Next.js application
FROM --platform=linux/amd64 node:22.3-alpine AS builder
WORKDIR /app

# Copy all dependencies from the deps stage
COPY --from=deps /app/node_modules ./node_modules
# Copy all application source code
COPY . .

ENV NEXT_TELEMETRY_DISABLED 1

# Build the Next.js application
# This command generates the .next directory
RUN npm run build

## Stage 3: Create the final production image
FROM --platform=linux/amd64 node:22.3-alpine AS runner
WORKDIR /app

ARG NODE_OPTIONS
ENV NODE_ENV production
ENV NODE_OPTIONS $NODE_OPTIONS

ENV NEXT_TELEMETRY_DISABLED 1

# Create a non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy the built application files from the builder stage
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next

# Copy production node_modules from the deps stage
# This ensures only necessary production dependencies are included
COPY --from=deps /app/node_modules ./node_modules

# Copy public assets and package.json
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["npm", "start"]
