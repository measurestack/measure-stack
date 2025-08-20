# Use Python base image for dbt
FROM python:3.11-slim

# Create a non-root user
RUN groupadd -r dbtuser && useradd -r -g dbtuser dbtuser

# Set working directory
WORKDIR /app

# Install system dependencies and update packages
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies as root (needed for system-wide installation)
RUN pip install --no-cache-dir -r requirements.txt

# Copy dbt project
COPY . ./dbt/

# Change ownership of the app directory to the dbtuser
RUN chown -R dbtuser:dbtuser /app

# Set environment variables
ENV PYTHONPATH=/app
ENV DBT_PROFILES_DIR=/app/dbt

# Create entrypoint script
RUN echo '#!/bin/bash\n\
cd /app/dbt/measure_js\n\
echo "Running dbt with target: ${DBT_TARGET:-prod}"\n\
dbt run --target ${DBT_TARGET:-prod} --profiles-dir /app/dbt\n\
echo "dbt run completed"' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Switch to non-root user
USER dbtuser

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
