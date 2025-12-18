#!/bin/bash
set -e

echo "dbt container starting..."

# Check if AUTO_RUN is enabled
if [ "$DBT_AUTO_RUN" = "true" ]; then
    echo "Auto-run mode enabled. dbt will run every ${DBT_RUN_INTERVAL:-600} seconds."

    # Wait for Trino to be fully ready (not just starting)
    echo "Waiting for Trino to be fully ready..."
    MAX_WAIT=300  # 5 minutes max
    WAITED=0
    until curl -s http://trino:8080/v1/info 2>/dev/null | grep -q '"starting":false'; do
        if [ $WAITED -ge $MAX_WAIT ]; then
            echo "Trino did not become ready in time. Proceeding anyway..."
            break
        fi
        echo "Trino still starting... (waited ${WAITED}s)"
        sleep 10
        WAITED=$((WAITED + 10))
    done
    echo "Trino is ready! Starting dbt processing..."

    # Install dbt dependencies only if not already installed
    if [ ! -d "/dbt/dbt_packages/dbt_utils" ]; then
        echo "dbt packages not found, installing..."
        dbt deps || echo "Warning: dbt deps failed, but continuing anyway"
    else
        echo "✓ dbt packages already installed"
    fi
    echo ""

    # Start HTTP server to serve dbt documentation (if not already running)
    if ! curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo "Starting dbt documentation server on port 8080..."
        mkdir -p /dbt/target
        cd /dbt/target && nohup python3 -m http.server 8080 > /dev/null 2>&1 &
        cd /dbt
        sleep 2
        echo "✓ dbt documentation server started (accessible at http://localhost:8082/)"
    else
        echo "✓ dbt documentation server already running"
    fi
    echo ""

    while true; do
        echo "================================================================================"
        echo "Running dbt at $(date)"
        echo "================================================================================"

        # Run dbt models (suppress errors to stderr)
        dbt run 2>/dev/null || echo "⚠️  dbt run completed with errors (check logs)"

        echo ""
        echo "✓ dbt run completed"

        # Generate documentation and lineage (suppress errors to stderr)
        echo "Generating dbt documentation and lineage..."
        dbt docs generate 2>/dev/null || echo "⚠️  dbt docs generate completed with errors"

        echo "✓ Documentation generated at /dbt/target/"
        echo "  - manifest.json: Data lineage and model metadata"
        echo "  - catalog.json: Column-level metadata"
        echo "  - index.html: Interactive documentation"
        echo "  - View at: http://localhost:8082/"

        echo ""
        echo "Next run in ${DBT_RUN_INTERVAL:-600} seconds..."
        sleep "${DBT_RUN_INTERVAL:-600}"
    done
else
    echo "Manual mode. Container will stay running."
    echo "Run: docker exec -it dbt-transformations dbt run"

    # Keep container running
    tail -f /dev/null
fi
