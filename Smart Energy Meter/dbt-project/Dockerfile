FROM python:3.11-slim

WORKDIR /dbt

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install dbt-trino and dependencies
RUN pip install --no-cache-dir \
    dbt-trino==1.7.0 \
    dbt-core==1.7.0

# Copy dbt project files
COPY . /dbt/

# Set DBT profiles directory
ENV DBT_PROFILES_DIR=/dbt

# Install dbt packages on container start
RUN dbt deps || true

# Copy and set executable permission for entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
