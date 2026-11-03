// Task 4: CI/CD pipeline for the microservice (build, test, push, deploy).
// Task 6 adds the full infrastructure pipeline in cd-pipeline/Jenkinsfile.
//
// Jenkins needs: Docker on the Jenkins host, kubectl on the Jenkins host, and two credentials:
//   dockerhub-credentials  (Username with password)  your Docker Hub login
//   kubeconfig             (Secret file)             kubeconfig for the cluster

pipeline {
    agent any

    environment {
        DOCKERHUB_USER = 'mosesr'
        APP_NAME       = 'oeson-microservice'
        IMAGE_TAG      = "1.0.${env.BUILD_NUMBER}"
        IMAGE          = "${DOCKERHUB_USER}/${APP_NAME}:${IMAGE_TAG}"
        NAMESPACE      = 'microservices'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    triggers {
        // Fires on a GitHub webhook push (needs Jenkins reachable from GitHub)
        githubPush()
        // Fallback that works even when Jenkins is only open to your own IP
        pollSCM('H/2 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                // Tests for the deploy/helper scripts (stubs kubectl, ssh, terraform, curl; touches nothing real)
                sh 'sh scripts/tests/test-scripts.sh'

                // Run the unit tests in a throwaway Node container, so Jenkins needs no Node install
                sh '''
                    docker run --rm \
                      --user "$(id -u):$(id -g)" \
                      -e HOME=/tmp \
                      -v "$WORKSPACE/app":/app -w /app \
                      node:18-alpine sh -c "npm ci && npm test"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -f docker/Dockerfile -t "$IMAGE" -t "$DOCKERHUB_USER/$APP_NAME:latest" .'
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push "$IMAGE"
                        docker push "$DOCKERHUB_USER/$APP_NAME:latest"
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh 'ROLLOUT_TIMEOUT=180s sh scripts/deploy-app.sh "$IMAGE"'
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo "Deployed ${env.IMAGE} to namespace ${env.NAMESPACE}"
        }
        failure {
            echo 'Pipeline failed. Check the stage logs above.'
        }
    }
}
