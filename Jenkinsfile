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
                            echo "Removing previous scan reports and venv..."
                            rm -f trivy-fs-report.txt trivy-image-report.txt
                            rm -rf venv
                            echo "Clean-up completed successfully"
                        '''
                    } catch (Exception e) {
                        echo "Clean-up errors (non-blocking): ${e.message}"
                    }
                }
            }
        }
        
        stage('Trivy FS Scan') {
            steps {
                script {
                    echo "========== Trivy FS Scan =========="
                    sh '''
                        trivy fs --format table -o trivy-fs-report.txt .
                        echo "FS scan complete. Report saved to trivy-fs-report.txt"
                    '''
                    archiveArtifacts artifacts: 'trivy-fs-report.txt', allowEmptyArchive: false
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
        
        stage('Trivy Image Scan') {
            steps {
                script {
                    echo "========== Trivy Image Scan =========="
                    sh '''
                        trivy image --format table -o trivy-image-report.txt ${APP_CONTAINER}:${IMAGE_TAG}
                        echo "Image scan complete. Report saved to trivy-image-report.txt"
                    '''
                    archiveArtifacts artifacts: 'trivy-image-report.txt', allowEmptyArchive: false
                }
            }
        }
        
        stage('Unit Test') {
            steps {
                script {
                    echo "========== Unit Test Stage =========="
                    catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                        sh '''
                            echo "Installing python3-venv..."
                            sudo apt-get install -y python3-venv
                            
                            echo "Creating virtual environment..."
                            python3 -m venv venv
                            
                            echo "Installing test dependencies..."
                            venv/bin/pip install --upgrade pip
                            venv/bin/pip install -r requirements.txt
                            
                            echo "Running unit tests..."
                            venv/bin/python -m pytest test_app.py -v
                        '''
                    }
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
