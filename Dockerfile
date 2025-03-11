# Use the official Bun image
FROM oven/bun:latest

# Set the working directory inside the container
WORKDIR /app

# Copy package manager and config files
COPY package.json bun.lock tsconfig.json ./

# Install dependencies
RUN bun install

# Copy the rest of the application code
COPY ./src ./src
COPY ./static ./static

# Copy the .env file (Optional: Only for local testing, NOT recommended for production)
COPY .env .env

# If using a service account file locally, ensure it's available
COPY service-account.json /app/service-account.json

# Set environment variable to point to service account file
# (Only needed if copying the service account file, otherwise use the mounted volume)
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/service-account.json"

# Expose the port the app runs on (adjust based on your app configuration)
EXPOSE 3000

# Run the Bun application (ensure Bun compiles TypeScript properly)
CMD ["bun", "run", "src/index.ts"]
