@echo off
setlocal enabledelayedexpansion

echo Setting up monitoring stack (Prometheus, Grafana, Loki)...

:: Create required directories
echo Creating directory structure...
if not exist prometheus mkdir prometheus
if not exist grafana\provisioning\datasources mkdir grafana\provisioning\datasources
if not exist grafana\provisioning\dashboards mkdir grafana\provisioning\dashboards
if not exist loki mkdir loki

:: Check if docker-compose.yml exists, and create it if not
if not exist docker-compose.yml (
    echo Creating Docker Compose configuration...
    (
        echo services:
        echo   prometheus:
        echo     image: prom/prometheus:latest
        echo     container_name: prometheus
        echo     restart: unless-stopped
        echo     volumes:
        echo       - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
        echo       - prometheus_data:/prometheus
        echo     command:
        echo       - '--config.file=/etc/prometheus/prometheus.yml'
        echo       - '--storage.tsdb.path=/prometheus'
        echo       - '--web.console.libraries=/etc/prometheus/console_libraries'
        echo       - '--web.console.templates=/etc/prometheus/consoles'
        echo       - '--web.enable-lifecycle'
        echo     ports:
        echo       - "9090:9090"
        echo     networks:
        echo       - monitoring-network
        echo.
        echo   grafana:
        echo     image: grafana/grafana:latest
        echo     container_name: grafana
        echo     restart: unless-stopped
        echo     volumes:
        echo       - grafana_data:/var/lib/grafana
        echo       - ./grafana/provisioning:/etc/grafana/provisioning
        echo     environment:
        echo       - GF_SECURITY_ADMIN_USER=admin
        echo       - GF_SECURITY_ADMIN_PASSWORD=admin
        echo       - GF_USERS_ALLOW_SIGN_UP=false
        echo     ports:
        echo       - "3000:3000"
        echo     networks:
        echo       - monitoring-network
        echo     depends_on:
        echo       - prometheus
        echo       - loki
        echo.
        echo   loki:
        echo     image: grafana/loki:latest
        echo     container_name: loki
        echo     restart: unless-stopped
        echo     ports:
        echo       - "3100:3100"
        echo     volumes:
        echo       - ./loki/config.yml:/etc/loki/config.yml
        echo       - loki_data:/loki
        echo     command: -config.file=/etc/loki/config.yml
        echo     networks:
        echo       - monitoring-network
        echo.
        echo networks:
        echo   monitoring-network:
        echo     driver: bridge
        echo     # Use host network mode for container access to host services
        echo     # Uncomment the line below to use host network mode instead of bridge
        echo     # driver: host
        echo.
        echo volumes:
        echo   prometheus_data:
        echo   grafana_data:
        echo   loki_data:
    ) > docker-compose.yml
)

:: Check if Prometheus config exists, and create it if not
if not exist prometheus\prometheus.yml (
    echo Creating Prometheus configuration...
    (
        echo global:
        echo   scrape_interval: 15s
        echo   evaluation_interval: 15s
        echo   scrape_timeout: 10s
        echo.
        echo scrape_configs:
        echo   - job_name: 'prometheus'
        echo     static_configs:
        echo       - targets: ['localhost:9090']
        echo.
        echo   - job_name: 'host'
        echo     static_configs:
        echo       - targets: ['host.docker.internal:9100']  # For node_exporter on host
        echo.
        echo   # Add more scrape configurations as needed
        echo   # Example for Docker metrics:
        echo   # - job_name: 'docker'
        echo   #   static_configs:
        echo   #     - targets: ['host.docker.internal:9323']
    ) > prometheus\prometheus.yml
)

:: Check if Loki config exists, and create it if not
if not exist loki\config.yml (
    echo Creating Loki configuration...
    (
        echo auth_enabled: false
        echo.
        echo server:
        echo   http_listen_port: 3100
        echo.
        echo ingester:
        echo   lifecycler:
        echo     address: 127.0.0.1
        echo     ring:
        echo       kvstore:
        echo         store: inmemory
        echo       replication_factor: 1
        echo     final_sleep: 0s
        echo   chunk_idle_period: 5m
        echo   chunk_retain_period: 30s
        echo.
        echo schema_config:
        echo   configs:
        echo     - from: 2020-10-24
        echo       store: boltdb-shipper
        echo       object_store: filesystem
        echo       schema: v11
        echo       index:
        echo         prefix: index_
        echo         period: 24h
        echo.
        echo storage_config:
        echo   boltdb_shipper:
        echo     active_index_directory: /loki/boltdb-shipper-active
        echo     cache_location: /loki/boltdb-shipper-cache
        echo     cache_ttl: 24h
        echo     shared_store: filesystem
        echo   filesystem:
        echo     directory: /loki/chunks
        echo.
        echo limits_config:
        echo   enforce_metric_name: false
        echo   reject_old_samples: true
        echo   reject_old_samples_max_age: 168h
        echo.
        echo compactor:
        echo   working_directory: /loki/compactor
        echo   shared_store: filesystem
    ) > loki\config.yml
)

:: Check if Grafana datasource config exists, and create it if not
if not exist grafana\provisioning\datasources\datasources.yml (
    echo Creating Grafana datasource configuration...
    if not exist grafana\provisioning\datasources mkdir grafana\provisioning\datasources
    (
        echo apiVersion: 1
        echo.
        echo datasources:
        echo   - name: Prometheus
        echo     type: prometheus
        echo     access: proxy
        echo     url: http://prometheus:9090
        echo     isDefault: true
        echo     editable: true
        echo.    
        echo   - name: Loki
        echo     type: loki
        echo     access: proxy
        echo     url: http://loki:3100
        echo     editable: true
        echo.    
        echo   # Uncomment and modify the following template to add additional datasources
        echo   # - name: DataSourceName
        echo   #   type: datasource_type
        echo   #   access: proxy
        echo   #   url: http://datasource-url
        echo   #   editable: true
    ) > grafana\provisioning\datasources\datasources.yml
)

:: Start the stack
echo Starting monitoring stack...
docker-compose up -d

echo.
echo Monitoring stack is up and running!
echo Grafana:     http://localhost:3000 (admin/admin)
echo Prometheus:  http://localhost:9090
echo Loki:        http://localhost:3100
echo.
echo To stop the stack, run: docker-compose down
echo To view logs, run: docker-compose logs -f

:: Adding information about how to add data sources
echo.
echo ========== HOW TO ADD DATA SOURCES ==========
echo 1. Adding Prometheus scrape targets:
echo    Edit the file: prometheus\prometheus.yml
echo    Add a new job under 'scrape_configs' section, for example:
echo    - job_name: 'my-app'
echo      static_configs:
echo        - targets: ['host.docker.internal:8080']
echo    Then reload Prometheus configuration: curl -X POST http://localhost:9090/-/reload
echo.
echo 2. Adding Grafana datasources:
echo    Method 1 - Provisioning (automatic):
echo    Edit the file: grafana\provisioning\datasources\datasources.yml
echo    Add a new datasource entry and restart the stack: docker-compose restart grafana
echo    Method 2 - UI (manual):
echo    Visit http://localhost:3000, go to Configuration ^> Data Sources ^> Add data source
echo.
echo 3. Connecting to your applications:
echo    For containerized apps: Add them to the same network with network_mode: "container:prometheus"
echo    For host applications: Use host.docker.internal as the hostname when configuring targets
echo ==========================================

endlocal 