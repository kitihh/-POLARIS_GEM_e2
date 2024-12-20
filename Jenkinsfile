pipeline {
    agent any
    
    options {
        timeout(time: 1, unit: 'HOURS')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }
    
    environment {
        DOCKER_IMAGE = "polaris_gem_e2:${BUILD_NUMBER}"
        EMAIL_RECIPIENTS = 'kirilltihhonov@me.com'
        WORKSPACE_ROOT = '/home/ros/workspace'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.GIT_BRANCH = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()

                    // Echo the values
                    echo "Git Commit: ${env.GIT_COMMIT}"
                    echo "Git Branch: ${env.GIT_BRANCH}"
                }
            }
        }
        
        stage('Start Docker Daemon') {
            steps {
                container('docker') {
                    sh '''
                        # Start Docker daemon
                        dockerd &
                        # Wait for Docker to be ready
                        while ! docker info >/dev/null 2>&1; do
                            echo "Waiting for Docker to be ready..."
                            sleep 1
                        done
                        echo "Docker is ready!"
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    sh '''
                        docker build -t ${DOCKER_IMAGE} \
                            --progress=plain \
                            --compress \
                            -f Dockerfile .
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                container('docker') {
                    sh '''
                        docker run --rm \
                            ${DOCKER_IMAGE} \
                            bash -c "source /opt/ros/noetic/setup.bash && \
                                        cd /home/ros/workspace && \
                                        catkin_make run_tests_gem_pure_pursuit_sim -j\$(nproc) && \
                                        catkin_test_results"
                    '''
                }
            }
        }
    }
    
    post {
        failure {
            emailext (
                subject: "[Jenkins] Pipeline '${currentBuild.fullProjectName}' - Build #${BUILD_NUMBER} - ${currentBuild.result}",
                body: """
                    <h2>Build Status: ${currentBuild.result}</h2>
                    <p>Pipeline: ${env.JOB_NAME}</p>
                    <p>Build Number: ${env.BUILD_NUMBER}</p>
                    <hr/>
                    <h3>Change Log</h3>
                    <p>Branch: ${env.GIT_BRANCH ?: 'N/A'}</p>
                    <p>Commit: ${env.GIT_COMMIT ?: 'N/A'}</p>
                    <hr/>
                    <p>Check console output at <a href='${env.BUILD_URL}'>${env.BUILD_URL}</a></p>
                """,
                to: "${EMAIL_RECIPIENTS}",
                from: "Jenkins CI <kirill.test.jenkins@gmail.com>",
                replyTo: "kirill.test.jenkins@gmail.com",
                mimeType: 'text/html',
                attachLog: true,
                compressLog: true
            )
        }
        
        always {
            container('docker') {
                sh "docker rmi ${DOCKER_IMAGE} || true"
            }
            
            cleanWs()
        }
    }
}