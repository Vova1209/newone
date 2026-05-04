pipeline {
    agent any

    environment {
        AWS_REGION      = 'us-east-1'
        ECR_REGISTRY    = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_REPO        = 'my-app'
        IMAGE_TAG       = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        FULL_IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                }
                echo "Building commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    docker run --rm \
                      -v $(pwd):/app \
                      -w /app \
                      node:20-alpine \
                      sh -c "npm ci && npm test"
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
                      --build-arg GIT_COMMIT=${env.GIT_COMMIT} \
                      -t ${FULL_IMAGE_NAME} \
                      -t ${ECR_REGISTRY}/${ECR_REPO}:latest \
                      .
                """
            }
        }

        stage('Security Scan') {
            steps {
                sh """
                    # Trivy scan — перевірка вразливостей в образі
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      aquasec/trivy:latest image \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      ${FULL_IMAGE_NAME}
                """
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    # Логін в ECR
                    aws ecr get-login-password --region ${AWS_REGION} | \
                      docker login --username AWS --password-stdin ${ECR_REGISTRY}

                    # Push image з тегами
                    docker push ${FULL_IMAGE_NAME}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
                """
            }
        }

        stage('Deploy with Ansible') {
            when {
                branch 'main'  // деплой тільки з main гілки
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'aws-deploy-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        ansible-playbook \
                          -i ansible/inventory/hosts.ini \
                          ansible/playbooks/deploy_app.yml \
                          --private-key=${SSH_KEY} \
                          -e "docker_image=${FULL_IMAGE_NAME}" \
                          -e "app_port=3000" \
                          -v
                    """
                }
            }
        }

        stage('Smoke Test') {
            when { branch 'main' }
            steps {
                sh '''
                    # Чекаємо поки застосунок стане доступним
                    for i in $(seq 1 10); do
                        if curl -sf http://<APP_EC2_IP>:3000/health; then
                            echo "App is healthy!"
                            exit 0
                        fi
                        echo "Waiting... attempt $i"
                        sleep 5
                    done
                    echo "Health check failed!"
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded! Image: ${FULL_IMAGE_NAME}"
            // slackSend channel: '#deployments', message: "Deployed: ${FULL_IMAGE_NAME}"
        }
        failure {
            echo "Pipeline failed! Check logs."
        }
        always {
            sh 'docker image prune -f'  // чистимо локальні образи
        }
    }
}
