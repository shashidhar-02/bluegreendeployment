pipeline {
    agent any
    
    environment {
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_IMAGE = 'your-dockerhub-username/todo-api'
        SERVER_IP = credentials('server-ip')
        SSH_CREDENTIALS = credentials('ssh-credentials')
        APP_VERSION = ""
        DOCKER_TAG = "-"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    sh '''
                        npm ci
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    sh '''
                        npm test
                    '''
                }
            }
            post {
                always {
                    junit '**/test-results/*.xml'
                }
            }
        }
        
        stage('Code Quality Analysis') {
            parallel {
                stage('Lint') {
                    steps {
                        sh 'npm run lint || true'
                    }
                }
                stage('Security Scan') {
                    steps {
                        sh 'npm audit || true'
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'docker-hub-credentials') {
                        def customImage = docker.build(":")
                        customImage.push()
                        customImage.push('latest')
                    }
                }
            }
        }
        
        stage('Deploy to Staging (Green)') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    sshagent(credentials: ['ssh-credentials']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no @ '
                                cd /opt/todo-app &&
                                docker-compose pull todo-api-green &&
                                docker-compose up -d todo-api-green &&
                                sleep 10
                            '
                        """
                    }
                }
            }
        }
        
        stage('Health Check - Green') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    retry(3) {
                        sh """
                            curl -f http:///green/health || exit 1
                        """
                        sleep 5
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Deploy to Green environment first
                    sshagent(credentials: ['ssh-credentials']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no @ '
                                cd /opt/todo-app &&
                                export DOCKER_IMAGE=: &&
                                docker-compose pull todo-api-green &&
                                docker-compose up -d todo-api-green &&
                                sleep 15
                            '
                        """
                    }
                }
            }
        }
        
        stage('Smoke Tests - Green') {
            when {
                branch 'main'
            }
            steps {
                script {
                    retry(3) {
                        sh """
                            # Health check
                            curl -f http://:3002/health
                            
                            # Test API endpoints
                            curl -f http://:3002/todos
                        """
                        sleep 5
                    }
                }
            }
        }
        
        stage('Blue-Green Switch') {
            when {
                branch 'main'
            }
            steps {
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        input message: 'Switch traffic to Green environment?', ok: 'Deploy'
                    }
                    
                    sshagent(credentials: ['ssh-credentials']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no @ '
                                cd /opt/todo-app &&
                                bash scripts/blue-green-deploy.sh
                            '
                        """
                    }
                }
            }
        }
        
        stage('Verify Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    retry(3) {
                        sh """
                            curl -f http:///health
                            curl -f http:///todos
                        """
                        sleep 5
                    }
                }
            }
        }
        
        stage('Cleanup Old Images') {
            steps {
                script {
                    sh """
                        docker image prune -f
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline executed successfully!"
            // Add notification here (Slack, Email, etc.)
        }
        failure {
            echo "Pipeline failed!"
            script {
                if (env.BRANCH_NAME == 'main') {
                    sshagent(credentials: ['ssh-credentials']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no @ '
                                cd /opt/todo-app &&
                                bash scripts/rollback.sh
                            '
                        """
                    }
                }
            }
        }
    }
}
