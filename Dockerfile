# Use the official Bun image
FROM oven/bun:latest

# Set the Working Directory to /app, in order to copy all relevant files
WORKDIR /app

# Copy the static JS function
COPY ./static .

# Set the working directory to /app/endpoints/bun
WORKDIR /app/endpoints/bun

# Copy only the package/config files from endpoints/bun
COPY endpoints/bun/package.json .
COPY endpoints/bun/bun.lock .
COPY endpoints/bun/tsconfig.json .

# Install dependencies (only for the endpoints/bun folder)
RUN bun install

# Copy the rest of your application code
COPY endpoints/bun/src ./src

# Expose the port (if your Bun app listens on 3000)
EXPOSE 3000

# Command to start the server
CMD ["bun", "run", "src/index.ts"]
