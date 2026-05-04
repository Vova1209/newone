pipeline {
    agent any

    environment {
        AWS_REGION     = 'us-east-1'
        ECR_REGISTRY   = '507210367072.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPO       = 'test_jan'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
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
                echo "Building #${env.BUILD_NUMBER}"
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
                      -t ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} \
                      -t ${ECR_REGISTRY}/${ECR_REPO}:latest \
                      .
                """
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                      docker login --username AWS \
                      --password-stdin ${ECR_REGISTRY}

                    docker push ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
                """
            }
        }

        stage('Deploy with Ansible') {
            steps {
                sh """
                    ansible-playbook \
                      -i /home/test_jan/hosts \
                      /home/test_jan/deploy.yml \
                      -e "docker_image=${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
                """
            }
        }
    }

    post {
        success {
            echo "✅ Success! Image: ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
        always {
            sh 'docker image prune -f'
        }
    }
}
