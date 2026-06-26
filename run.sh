#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========== Task 1 App - Manual Run ==========${NC}"

# Check Docker installation
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is installed${NC}"

# Configuration
DOCKER_NETWORK="task1-network"
APP_CONTAINER="task1-app"
NGINX_CONTAINER="task1-nginx"
APP_PORT="5000"
NGINX_PORT="8001"

# Clean up function
cleanup() {
    echo -e "${YELLOW}Cleaning up previous containers...${NC}"
    docker stop $APP_CONTAINER $NGINX_CONTAINER 2>/dev/null || true
    docker rm $APP_CONTAINER $NGINX_CONTAINER 2>/dev/null || true
    docker network rm $DOCKER_NETWORK 2>/dev/null || true
}

# Build function
build_images() {
    echo -e "${BLUE}Building Docker images...${NC}"
    
    if [ -f "Dockerfile" ]; then
        echo "Building app image..."
        docker build -t $APP_CONTAINER:latest -f Dockerfile .
        echo -e "${GREEN}✓ App image built${NC}"
    fi
    
    if [ -f "Dockerfile.nginx" ]; then
        echo "Building nginx image..."
        docker build -t $NGINX_CONTAINER:latest -f Dockerfile.nginx .
        echo -e "${GREEN}✓ Nginx image built${NC}"
    fi
}

# Setup network
setup_network() {
    echo -e "${BLUE}Setting up Docker network...${NC}"
    docker network create $DOCKER_NETWORK 2>/dev/null || echo "Network already exists"
    echo -e "${GREEN}✓ Network ready${NC}"
}

# Run containers
run_containers() {
    echo -e "${BLUE}Starting containers...${NC}"
    
    # Run app container
    docker run -d \
        --name $APP_CONTAINER \
        --network $DOCKER_NETWORK \
        -e ENV=development \
        $APP_CONTAINER:latest
    
    echo -e "${GREEN}✓ App container started${NC}"
    
    sleep 2
    
    # Run nginx container
    docker run -d \
        --name $NGINX_CONTAINER \
        --network $DOCKER_NETWORK \
        -p $NGINX_PORT:80 \
        $NGINX_CONTAINER:latest
    
    echo -e "${GREEN}✓ Nginx container started${NC}"
}

# Health check
health_check() {
    echo -e "${BLUE}Performing health checks...${NC}"
    sleep 3
    
    max_retries=5
    retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -sf http://localhost:$NGINX_PORT/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Health check passed${NC}"
            return 0
        fi
        retry_count=$((retry_count + 1))
        echo "Waiting for service to be ready... (attempt $retry_count/$max_retries)"
        sleep 2
    done
    
    echo -e "${YELLOW}⚠ Health check failed${NC}"
    return 1
}

# Main execution
main() {
    cleanup
    build_images
    setup_network
    run_containers
    
    if health_check; then
        echo ""
        echo -e "${GREEN}========== Setup Complete ==========${NC}"
        echo ""
        echo "Access the application:"
        echo -e "${BLUE}  Browser: http://localhost:$NGINX_PORT/${NC}"
        echo -e "${BLUE}  Health:  http://localhost:$NGINX_PORT/health${NC}"
        echo -e "${BLUE}  API:     http://localhost:$NGINX_PORT/api/info${NC}"
        echo ""
        echo "Using curl:"
        echo "  curl http://localhost:$NGINX_PORT/"
        echo "  curl http://localhost:$NGINX_PORT/health"
        echo "  curl http://localhost:$NGINX_PORT/api/info"
        echo ""
        echo "View logs:"
        echo "  docker logs $APP_CONTAINER"
        echo "  docker logs $NGINX_CONTAINER"
        echo ""
        echo "Stop containers:"
        echo "  docker stop $APP_CONTAINER $NGINX_CONTAINER"
        echo ""
    else
        echo -e "${YELLOW}Setup completed but health check failed. Check logs with:${NC}"
        echo "  docker logs $APP_CONTAINER"
        echo "  docker logs $NGINX_CONTAINER"
        exit 1
    fi
}

main
