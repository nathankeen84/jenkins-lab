# Jenkins Lab - Task 1 App

A simple Flask application with Nginx reverse proxy, containerized with Docker and orchestrated via Jenkins pipeline.

## Architecture

- **Flask App**: Simple Python web application with health check and API endpoints
- **Nginx**: Reverse proxy and load balancer
- **Docker**: Containerization
- **Jenkins**: CI/CD pipeline orchestration

## Prerequisites

### Local Setup

1. **Install Docker**:
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose
   
   # Or follow: https://docs.docker.com/engine/install/
   ```

2. **Add user to Docker group** (replace `username` with your username):
   ```bash
   sudo usermod -aG docker username
   newgrp docker
   ```

3. **Verify Docker installation**:
   ```bash
   docker --version
   docker run hello-world
   ```

### Jenkins Setup

**Critical: Docker access for Jenkins**

For Jenkins to run Docker commands in the pipeline, the Jenkins user must be in the docker group:

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins for the change to take effect
sudo systemctl restart jenkins

# or if using Docker
docker restart jenkins-container-name
```

After adding Jenkins to the docker group:
- Restart Jenkins
- Optionally, verify with: `groups jenkins` (should show docker group)
- Run a test build to verify Docker access

If you see "permission denied while trying to connect to the docker API" in build logs, the jenkins user needs to be added to the docker group.

## Project Files

- **app.py**: Flask application with endpoints
- **requirements.txt**: Python dependencies
- **Dockerfile**: Container definition for Flask app
- **Dockerfile.nginx**: Container definition for Nginx
- **nginx.conf**: Nginx reverse proxy configuration
- **Jenkinsfile**: Jenkins pipeline definition
- **run.sh**: Manual local run script

## Quick Start

### Manual Local Execution

```bash
# Make script executable
chmod +x run.sh

# Run the application
./run.sh
```

This will:
1. Clean up any previous containers
2. Build Docker images
3. Create Docker network
4. Start Flask and Nginx containers
5. Perform health checks
6. Display access information

### Testing the Application

**Using curl**:
```bash
# Health check
curl http://localhost:8001/health

# API info
curl http://localhost:8001/api/info

# Home endpoint
curl http://localhost:8001/
```

**Using browser**:
```
http://localhost:8001/
http://localhost:8001/health
http://localhost:8001/api/info
```

### View Logs

```bash
# App logs
docker logs task1-app

# Nginx logs
docker logs task1-nginx
```

### Stop Containers

```bash
docker stop task1-app task1-nginx
docker rm task1-app task1-nginx
docker network rm task1-network
```

## Jenkins Pipeline

The Jenkinsfile defines the following stages:

1. **Clean-up**: Stop and remove previous containers
2. **Set-up (Network)**: Create Docker network for inter-container communication
3. **Build Images**: Build Flask app and Nginx Docker images
4. **Run Containers**: Start both containers with proper networking
5. **Smoke Test**: Verify application health and endpoints

### Running in Jenkins

1. Create a new Pipeline job in Jenkins
2. Set SCM to this repository
3. Set Pipeline script path to `Jenkinsfile`
4. Run the job

## Environment Variables

- `ENV`: Set to `production` in Jenkins, `development` in manual run
- `DOCKER_NETWORK`: Network name (default: `task1-network`)
- `IMAGE_TAG`: Image tag (defaults to Jenkins BUILD_NUMBER in pipeline)

## Endpoints

- `GET /`: Home endpoint with service info
- `GET /health`: Health check endpoint (used by Docker and load balancers)
- `GET /api/info`: API information endpoint

## Troubleshooting

### Docker permission denied
```bash
# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Port 8080 already in use
```bash
# Find process using port 8080
lsof -i :8080

# Or use a different port by editing run.sh
```

### Containers not starting
```bash
# Check logs
docker logs task1-app
docker logs task1-nginx

# Verify network
docker network ls
docker network inspect task1-network
```

### Health check failing
```bash
# Test connectivity
docker exec task1-nginx curl http://app:5000/health

# Check if app container is running
docker ps | grep task1-app
```

## Next Steps

This is Task 1 of the Jenkins Lab. After verifying local execution:

- Phase 2: Add Trivy scanning and unit tests
- Production: Add registry push, SonarQube analysis, and SBOM generation

See `instructions.txt` for the complete project roadmap.