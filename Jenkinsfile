pipeline {
    agent any

    parameters {
        booleanParam(name: 'USE_SLIM_IMAGE', defaultValue: false, description: '[EXPERIMENTAL] Build slim app image when slim tool is available')
        string(name: 'APP_DOCKERHUB_REPO', defaultValue: 'task1-app', description: 'Private Docker Hub app repository name only (username comes from credentials)')
        string(name: 'NGINX_DOCKERHUB_REPO', defaultValue: 'task1-nginx', description: 'Private Docker Hub nginx repository name only (username comes from credentials)')
        string(name: 'DOCKERHUB_CREDENTIALS_ID', defaultValue: 'dockerhub', description: 'Jenkins credentialsId for Docker Hub username/password')
        string(name: 'SONAR_HOST_URL', defaultValue: 'http://172.31.35.75:9000', description: 'SonarQube server URL')
        string(name: 'SONAR_PROJECT_KEY', defaultValue: 'task1-app', description: 'SonarQube project key')
        string(name: 'SONAR_TOKEN_CREDENTIALS_ID', defaultValue: 'sonarqube-token', description: 'Jenkins credentialsId for Sonar token')
    }

    environment {
        DOCKER_NETWORK = 'task1-network'
        APP_CONTAINER = 'task1-app'
        NGINX_CONTAINER = 'task1-nginx'
        IMAGE_TAG = "${BUILD_NUMBER}"

        APP_IMAGE_LOCAL = "task1-app:${BUILD_NUMBER}"
        APP_IMAGE_SLIM = "task1-app:${BUILD_NUMBER}-slim"
        NGINX_IMAGE_LOCAL = "task1-nginx:${BUILD_NUMBER}"

        APP_IMAGE_LATEST = 'task1-app:latest'
        NGINX_IMAGE_LATEST = 'task1-nginx:latest'

        TRIVY_CACHE_DIR = '.trivycache'
        APP_IMAGE_TAR = 'task1-app.tar'
    }

    stages {
        stage('Clean-up') {
            steps {
                sh '''
                    docker stop ${APP_CONTAINER} ${NGINX_CONTAINER} || true
                    docker rm ${APP_CONTAINER} ${NGINX_CONTAINER} || true
                    docker network rm ${DOCKER_NETWORK} || true

                    rm -f trivy-fs-report.txt trivy-image-report.txt flask-app-sbom.cdx.json
                    rm -f build-metadata.json docker_inspect.json docker_history.txt docker_image_size.txt
                    rm -f ${APP_IMAGE_TAR}
                    rm -rf ${TRIVY_CACHE_DIR}
                '''
            }
        }

        stage('Parallel Pre-Build Checks') {
            steps {
                script {
                    parallel(
                        'Trivy FS Scan': {
                            sh '''
                                mkdir -p ${TRIVY_CACHE_DIR}
                                docker run --rm \
                                    --user "$(id -u):$(id -g)" \
                                    -e TRIVY_CACHE_DIR=/workspace/${TRIVY_CACHE_DIR} \
                                    -v "$PWD:/workspace" \
                                    aquasec/trivy:0.54.1 \
                                    fs --cache-dir /workspace/${TRIVY_CACHE_DIR} --format table --output /workspace/trivy-fs-report.txt /workspace
                            '''
                        },
                        'SonarQube Analysis': {
                            withCredentials([string(credentialsId: params.SONAR_TOKEN_CREDENTIALS_ID, variable: 'SONAR_TOKEN')]) {
                                sh '''
                                    docker run --rm \
                                        -e SONAR_HOST_URL="${SONAR_HOST_URL}" \
                                        -e SONAR_TOKEN="${SONAR_TOKEN}" \
                                        -v "${WORKSPACE}:/usr/src" \
                                        sonarsource/sonar-scanner-cli \
                                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                        -Dsonar.sources=. \
                                        -Dsonar.exclusions=.venv/**,venv/**,__pycache__/**,**/*.pyc,potential-journey/**
                                '''
                            }
                        }
                    )
                    archiveArtifacts artifacts: 'trivy-fs-report.txt', allowEmptyArchive: false
                }
            }
        }

        stage('Set-up (Network)') {
            steps {
                sh '''
                    docker network create ${DOCKER_NETWORK} || echo "Network already exists"
                '''
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    docker build -t ${APP_IMAGE_LOCAL} -f Dockerfile .
                    docker tag ${APP_IMAGE_LOCAL} ${APP_IMAGE_LATEST}

                    docker build -t ${NGINX_IMAGE_LOCAL} -f Dockerfile.nginx .
                    docker tag ${NGINX_IMAGE_LOCAL} ${NGINX_IMAGE_LATEST}
                '''
            }
        }

        stage('Unit Test') {
            steps {
                catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                    sh '''
                        docker run --rm \
                            --user "$(id -u):$(id -g)" \
                            -v "$PWD:/workspace" \
                            -w /workspace \
                            ${APP_IMAGE_LOCAL} \
                            python -m unittest -v test_app
                    '''
                }
            }
        }

        stage('Build Optional Slim Image') {
            when {
                expression { return params.USE_SLIM_IMAGE }
            }
            steps {
                script {
                    if (sh(script: 'command -v slim >/dev/null 2>&1', returnStatus: true) == 0) {
                        sh '''
                            slim build \
                                --target ${APP_IMAGE_LOCAL} \
                                --tag ${APP_IMAGE_SLIM} \
                                --http-probe=false
                        '''
                    } else {
                        unstable('USE_SLIM_IMAGE=true but slim is not installed on this Jenkins agent. Continuing with standard image.')
                    }
                }
            }
        }

        stage('Select Final App Image') {
            steps {
                script {
                    env.FINAL_APP_IMAGE = env.APP_IMAGE_LOCAL
                    if (params.USE_SLIM_IMAGE && sh(script: "docker image inspect ${env.APP_IMAGE_SLIM} >/dev/null 2>&1", returnStatus: true) == 0) {
                        env.FINAL_APP_IMAGE = env.APP_IMAGE_SLIM
                    }
                    echo "Selected app image: ${env.FINAL_APP_IMAGE}"
                }
            }
        }

        stage('Image Size Gate (200MB)') {
            steps {
                script {
                    def sizeBytes = sh(
                        script: "docker image inspect ${env.FINAL_APP_IMAGE} --format='{{.Size}}'",
                        returnStdout: true
                    ).trim().toLong()
                    def sizeMb = (sizeBytes / (1024 * 1024)) as long
                    def maxBytes = 200L * 1024L * 1024L

                    if (sizeBytes > maxBytes) {
                        unstable("Image size gate failed: ${env.FINAL_APP_IMAGE} is ${sizeMb}MB (>200MB)")
                    } else {
                        echo "Image size gate passed: ${env.FINAL_APP_IMAGE} is ${sizeMb}MB"
                    }
                }
            }
        }

        stage('Trivy Image Scan + SBOM') {
            steps {
                sh '''
                    mkdir -p ${TRIVY_CACHE_DIR}

                    docker save ${FINAL_APP_IMAGE} -o ${APP_IMAGE_TAR}

                    docker run --rm \
                        --user "$(id -u):$(id -g)" \
                        -e TRIVY_CACHE_DIR=/workspace/${TRIVY_CACHE_DIR} \
                        -v "$PWD:/workspace" \
                        aquasec/trivy:0.54.1 \
                        image --cache-dir /workspace/${TRIVY_CACHE_DIR} --input /workspace/${APP_IMAGE_TAR} --format table --output /workspace/trivy-image-report.txt

                    docker run --rm \
                        --user "$(id -u):$(id -g)" \
                        -e TRIVY_CACHE_DIR=/workspace/${TRIVY_CACHE_DIR} \
                        -v "$PWD:/workspace" \
                        aquasec/trivy:0.54.1 \
                        image --cache-dir /workspace/${TRIVY_CACHE_DIR} --input /workspace/${APP_IMAGE_TAR} --format cyclonedx --output /workspace/flask-app-sbom.cdx.json
                '''
                archiveArtifacts artifacts: 'trivy-image-report.txt,flask-app-sbom.cdx.json', allowEmptyArchive: false
            }
        }

        stage('Build Metadata Archive') {
            steps {
                withCredentials([usernamePassword(credentialsId: params.DOCKERHUB_CREDENTIALS_ID, usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
                    sh '''
                        COMMIT_HASH="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
                        COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
                        BRANCH_NAME_VALUE="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
                        APP_REPO_FULL="${DOCKERHUB_USER}/${APP_DOCKERHUB_REPO}"
                        NGINX_REPO_FULL="${DOCKERHUB_USER}/${NGINX_DOCKERHUB_REPO}"

                        cat > build-metadata.json <<EOF
                        {
                          "commit_hash": "${COMMIT_HASH}",
                          "commit_short": "${COMMIT_SHORT}",
                          "branch_name": "${BRANCH_NAME_VALUE}",
                          "build_number": "${BUILD_NUMBER}",
                          "jenkins_job": "${JOB_NAME}",
                          "build_url": "${BUILD_URL}",
                          "app_image_local": "${APP_IMAGE_LOCAL}",
                          "app_image_slim": "${APP_IMAGE_SLIM}",
                          "final_app_image": "${FINAL_APP_IMAGE}",
                          "nginx_image_local": "${NGINX_IMAGE_LOCAL}",
                          "app_repo": "${APP_REPO_FULL}",
                          "nginx_repo": "${NGINX_REPO_FULL}"
                        }
                        EOF

                        docker inspect ${FINAL_APP_IMAGE} > docker_inspect.json
                        docker history ${FINAL_APP_IMAGE} > docker_history.txt
                        docker images ${FINAL_APP_IMAGE} > docker_image_size.txt
                    '''
                }
                archiveArtifacts artifacts: 'build-metadata.json,docker_inspect.json,docker_history.txt,docker_image_size.txt', allowEmptyArchive: false
            }
        }

        stage('Manual Quality Gate') {
            steps {
                input message: "Quality gate pass? Verify Sonar at ${params.SONAR_HOST_URL}", ok: 'Proceed'
            }
        }

        stage('Run Containers') {
            steps {
                sh '''
                    docker run -d \
                        --name ${APP_CONTAINER} \
                        --network ${DOCKER_NETWORK} \
                        -e YOUR_NAME=production \
                        ${FINAL_APP_IMAGE}

                    sleep 3

                    docker run -d \
                        --name ${NGINX_CONTAINER} \
                        --network ${DOCKER_NETWORK} \
                        -p 8001:80 \
                        ${NGINX_IMAGE_LOCAL}

                    sleep 3
                '''
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    max_retries=10
                    retry_count=0

                    while [ $retry_count -lt $max_retries ]; do
                        if curl -fsS http://localhost:8001/health > /dev/null 2>&1; then
                            break
                        fi
                        retry_count=$((retry_count + 1))
                        sleep 2
                    done

                    if [ $retry_count -eq $max_retries ]; then
                        echo "Health check failed"
                        exit 1
                    fi

                    curl -f http://localhost:8001/
                    curl -f http://localhost:8001/health
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: params.DOCKERHUB_CREDENTIALS_ID, usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
                        sh '''
                            echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin

                            APP_REPO_FULL="${DOCKERHUB_USER}/${APP_DOCKERHUB_REPO}"
                            NGINX_REPO_FULL="${DOCKERHUB_USER}/${NGINX_DOCKERHUB_REPO}"

                            docker tag ${FINAL_APP_IMAGE} ${APP_REPO_FULL}:${IMAGE_TAG}
                            docker tag ${FINAL_APP_IMAGE} ${APP_REPO_FULL}:latest
                            docker tag ${NGINX_IMAGE_LOCAL} ${NGINX_REPO_FULL}:${IMAGE_TAG}
                            docker tag ${NGINX_IMAGE_LOCAL} ${NGINX_REPO_FULL}:latest

                            docker push ${APP_REPO_FULL}:${IMAGE_TAG}
                            docker push ${APP_REPO_FULL}:latest
                            docker push ${NGINX_REPO_FULL}:${IMAGE_TAG}
                            docker push ${NGINX_REPO_FULL}:latest
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker logs ${APP_CONTAINER} || true
                docker logs ${NGINX_CONTAINER} || true
                docker stop ${APP_CONTAINER} ${NGINX_CONTAINER} || true
                docker rm ${APP_CONTAINER} ${NGINX_CONTAINER} || true
                docker network rm ${DOCKER_NETWORK} || true
            '''
        }
    }
}
