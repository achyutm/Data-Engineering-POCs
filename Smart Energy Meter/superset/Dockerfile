FROM apache/superset:latest

USER root

# Install Trino driver using system pip but targeting the venv site-packages
RUN pip install --target=/app/.venv/lib/python3.10/site-packages --no-cache-dir trino sqlalchemy-trino

USER superset

# Set PATH to use venv by default
ENV PATH="/app/.venv/bin:${PATH}"
ENV PYTHONPATH="/app/.venv/lib/python3.10/site-packages:${PYTHONPATH}"