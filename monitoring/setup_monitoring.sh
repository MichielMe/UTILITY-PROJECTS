#!/bin/bash

# Script to set up and run the monitoring stack with Prometheus, Grafana, and Loki

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up monitoring stack (Prometheus, Grafana, Loki)...${NC}"

# Create required directories
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p prometheus
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p loki

# Check if docker-compose.yml exists, and create it if not
if [ ! -f docker-compose.yml ]; then
    echo -e "${YELLOW}Creating Docker Compose configuration...${NC}"
    cat > docker-compose.yml << 'EOF'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    networks:
      - monitoring-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    networks:
      - monitoring-network
    depends_on:
      - prometheus
      - loki

  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - ./loki/config.yml:/etc/loki/config.yml
      - loki_data:/loki
    command: -config.file=/etc/loki/config.yml
    networks:
      - monitoring-network

networks:
  monitoring-network:
    driver: bridge
    # Use host network mode for container access to host services
    # Uncomment the line below to use host network mode instead of bridge
    # driver: host

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
EOF
fi

# Check if configuration files exist, and create them if not
if [ ! -f prometheus/prometheus.yml ]; then
    echo -e "${YELLOW}Creating Prometheus configuration...${NC}"
    cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'host'
    static_configs:
      - targets: ['host.docker.internal:9100']  # For node_exporter on host

  # Add more scrape configurations as needed
  # Example for Docker metrics:
  # - job_name: 'docker'
  #   static_configs:
  #     - targets: ['host.docker.internal:9323']
EOF
fi

if [ ! -f loki/config.yml ]; then
    echo -e "${YELLOW}Creating Loki configuration...${NC}"
    cat > loki/config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
EOF
fi

if [ ! -f grafana/provisioning/datasources/datasources.yml ]; then
    echo -e "${YELLOW}Creating Grafana datasource configuration...${NC}"
    mkdir -p grafana/provisioning/datasources
    cat > grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
    
  # Uncomment and modify the following template to add additional datasources
  # - name: DataSourceName
  #   type: datasource_type
  #   access: proxy
  #   url: http://datasource-url
  #   editable: true
EOF
fi

# Start the stack
echo -e "${GREEN}Starting monitoring stack...${NC}"
docker-compose up -d

echo -e "${GREEN}Monitoring stack is up and running!${NC}"
echo -e "${YELLOW}Grafana:     http://localhost:3000 (admin/admin)${NC}"
echo -e "${YELLOW}Prometheus:  http://localhost:9090${NC}"
echo -e "${YELLOW}Loki:        http://localhost:3100${NC}"

echo -e "${GREEN}To stop the stack, run: docker-compose down${NC}"
echo -e "${GREEN}To view logs, run: docker-compose logs -f${NC}"

# Adding information about how to add data sources
echo -e "\n${BLUE}========== HOW TO ADD DATA SOURCES ===========${NC}"
echo -e "${YELLOW}1. Adding Prometheus scrape targets:${NC}"
echo -e "   Edit the file: ${BLUE}prometheus/prometheus.yml${NC}"
echo -e "   Add a new job under 'scrape_configs' section, for example:"
echo -e "   ${BLUE}- job_name: 'my-app'
     static_configs:
       - targets: ['host.docker.internal:8080']${NC}"
echo -e "   Then reload Prometheus configuration: ${BLUE}curl -X POST http://localhost:9090/-/reload${NC}"

echo -e "\n${YELLOW}2. Adding Grafana datasources:${NC}"
echo -e "   Method 1 - Provisioning (automatic):"
echo -e "   Edit the file: ${BLUE}grafana/provisioning/datasources/datasources.yml${NC}"
echo -e "   Add a new datasource entry and restart the stack: ${BLUE}docker-compose restart grafana${NC}"
echo -e "   Method 2 - UI (manual):"
echo -e "   Visit http://localhost:3000, go to Configuration > Data Sources > Add data source"

echo -e "\n${YELLOW}3. Connecting to your applications:${NC}"
echo -e "   For containerized apps: Add them to the same network with ${BLUE}network_mode: \"container:prometheus\"${NC}"
echo -e "   For host applications: Use ${BLUE}host.docker.internal${NC} as the hostname when configuring targets"
echo -e "${BLUE}==========================================${NC}" 