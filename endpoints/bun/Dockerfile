# Use the official Bun image
FROM oven/bun:latest

# Set the working directory inside the container
WORKDIR /app

# Copy the necessary files into the container
COPY package.json bun.lockb tsconfig.json ./README.md ./

# Copy the entire src directory
COPY ./src ./src

# Install dependencies using Bun
RUN bun install

# Set environment variables if needed (optional)
# ENV NODE_ENV=production

# Expose the port the app runs on (adjust based on your app configuration)
EXPOSE 3000

# Run the Bun application using the correct path to the output .js file
CMD ["bun", "src/index.ts"]