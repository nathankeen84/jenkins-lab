pipeline {
    agent any
    
    environment {
        DOCKER_NETWORK = 'task1-network'
        APP_CONTAINER = 'task1-app'
        NGINX_CONTAINER = 'task1-nginx'
        REGISTRY = 'docker.io'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Clean-up') {
            steps {
                script {
                    echo "========== Clean-up Stage =========="
                    try {
                        sh '''
                            echo "Stopping and removing containers..."
                            docker stop ${APP_CONTAINER} ${NGINX_CONTAINER} || true
                            docker rm ${APP_CONTAINER} ${NGINX_CONTAINER} || true
                            echo "Removing old network..."
                            docker network rm ${DOCKER_NETWORK} || true
                            echo "Clean-up completed successfully"
                        '''
                    } catch (Exception e) {
                        echo "Clean-up errors (non-blocking): ${e.message}"
                    }
                }
            }
        }
        
        stage('Set-up (Network)') {
            steps {
                script {
                    echo "========== Network Set-up Stage =========="
                    sh '''
                        echo "Creating Docker network: ${DOCKER_NETWORK}"
                        docker network create ${DOCKER_NETWORK} || echo "Network may already exist"
                        echo "Network set-up completed"
                    '''
                }
            }
        }
        
        stage('Build Images') {
            steps {
                script {
                    echo "========== Build Images Stage =========="
                    sh '''
                        echo "Building Flask app image..."
                        docker build -t ${APP_CONTAINER}:${IMAGE_TAG} -f Dockerfile .
                        docker tag ${APP_CONTAINER}:${IMAGE_TAG} ${APP_CONTAINER}:latest
                        
                        echo "Building Nginx image..."
                        docker build -t ${NGINX_CONTAINER}:${IMAGE_TAG} -f Dockerfile.nginx .
                        docker tag ${NGINX_CONTAINER}:${IMAGE_TAG} ${NGINX_CONTAINER}:latest
                        
                        echo "Images built successfully"
                        docker images | grep -E "${APP_CONTAINER}|${NGINX_CONTAINER}"
                    '''
                }
            }
        }
        
        stage('Run Containers') {
            steps {
                script {
                    echo "========== Run Containers Stage =========="
                    sh '''
                        echo "Starting Flask app container..."
                        docker run -d \
                            --name ${APP_CONTAINER} \
                            --network ${DOCKER_NETWORK} \
                            -e ENV=production \
                            ${APP_CONTAINER}:${IMAGE_TAG}
                        
                        echo "Waiting for app to be ready..."
                        sleep 3
                        
                        echo "Starting Nginx container..."
                        docker run -d \
                            --name ${NGINX_CONTAINER} \
                            --network ${DOCKER_NETWORK} \
                            -p 8001:80 \
                            ${NGINX_CONTAINER}:${IMAGE_TAG}
                        
                        echo "Waiting for containers to stabilize..."
                        sleep 3
                        
                        echo "Containers running:"
                        docker ps --filter "name=${APP_CONTAINER}|${NGINX_CONTAINER}"
                    '''
                }
            }
        }
        
        stage('Smoke Test') {
            steps {
                script {
                    echo "========== Smoke Test Stage =========="
                    sh '''
                        echo "Testing application health..."
                        max_retries=5
                        retry_count=0
                        
                        while [ $retry_count -lt $max_retries ]; do
                            if curl -f http://localhost:8001/health > /dev/null 2>&1; then
                                echo "Health check passed!"
                                break
                            fi
                            retry_count=$((retry_count + 1))
                            echo "Health check attempt $retry_count failed, retrying..."
                            sleep 2
                        done
                        
                        if [ $retry_count -eq $max_retries ]; then
                            echo "Health check failed after $max_retries attempts"
                            exit 1
                        fi
                        
                        echo "Testing API endpoints..."
                        curl -v http://localhost:8001/
                        echo ""
                        curl -v http://localhost:8001/api/info
                        echo ""
                        echo "Smoke tests completed successfully"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "========== Post Build =========="
                sh '''
                    echo "Container logs:"
                    docker logs ${APP_CONTAINER} || true
                    echo "---"
                    docker logs ${NGINX_CONTAINER} || true
                '''
            }
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
            sh '''
                echo "Cleaning up on failure..."
                docker stop ${APP_CONTAINER} ${NGINX_CONTAINER} || true
                docker rm ${APP_CONTAINER} ${NGINX_CONTAINER} || true
            '''
        }
    }
}
