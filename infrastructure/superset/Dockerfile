FROM apache/superset:latest

USER root

RUN pip install clickhouse-connect && \
    cp -r /usr/local/lib/python3.10/site-packages/clickhouse_connect /app/.venv/lib/python3.10/site-packages/ && \
    cp -r /usr/local/lib/python3.10/site-packages/clickhouse_connect-*.dist-info /app/.venv/lib/python3.10/site-packages/ 2>/dev/null; \
    for dep in lz4 zstd certifi urllib3; do \
        if [ -d "/usr/local/lib/python3.10/site-packages/${dep}" ]; then \
            cp -rn /usr/local/lib/python3.10/site-packages/${dep} /app/.venv/lib/python3.10/site-packages/ 2>/dev/null; \
        fi; \
        for dist in /usr/local/lib/python3.10/site-packages/${dep}*.dist-info; do \
            if [ -d "$dist" ]; then \
                cp -rn "$dist" /app/.venv/lib/python3.10/site-packages/ 2>/dev/null; \
            fi; \
        done; \
    done; \
    true

USER superset
