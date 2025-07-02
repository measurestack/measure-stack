# Use the official Bun image
FROM oven/bun:latest

# Set the Working Directory to /app
WORKDIR /app

# Copy the static JS function
COPY ./static .

# Copy package files
COPY package.json .
COPY bun.lock .
COPY tsconfig.json .

# Install dependencies
RUN bun install

# Copy the source code
COPY src ./src

# Expose the port
EXPOSE 3000

# Command to start the server
CMD ["bun", "run", "src/api/index.ts"]
