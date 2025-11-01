# Use the official Bun image (pinned to specific version)
FROM oven/bun:1.3.1

# Set the Working Directory to /app
WORKDIR /app

# Set NODE_ENV to production
ENV NODE_ENV=production

# Copy the static JS function
COPY ./static ./static

# Copy package files
COPY package.json .
COPY bun.lock .
COPY tsconfig.json .

# Install dependencies (including dev deps needed for build)
RUN bun install

# Copy the source code
COPY src ./src

# Build the TypeScript to JavaScript (exclude problematic dependencies)
RUN bun build src/api/index.ts --outdir ./dist --target bun --external useragent --external request --external yamlparser

# Expose the port
EXPOSE 3000

# Command to start the server (using pre-built JS)
CMD ["bun", "run", "src/api/index.ts"]
#CMD ["bun", "run", "dist/index.js"] # Note, firestore access in cloud run currently fails when running pre-compiled code
