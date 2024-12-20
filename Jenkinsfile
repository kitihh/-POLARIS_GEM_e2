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
                    sh """
                        docker build -t ${DOCKER_IMAGE} \
                            --progress=plain \
                            --compress \
                            -f Dockerfile .
                    """
                }
            }
        }
        
        stage('Run Tests') {
            environment {
                WORKSPACE_ROOT = '/workspace'
            }
            steps {
                container('docker') {
                    sh '''
                        docker run --rm \
                            -v "${WORKSPACE}:${WORKSPACE_ROOT}" \
                            ${DOCKER_IMAGE} \
                            /bin/bash -c "source /opt/ros/noetic/setup.bash && \
                                        mkdir -p ${WORKSPACE_ROOT} && \
                                        cp -r . ${WORKSPACE_ROOT}/ && \
                                        cd ${WORKSPACE_ROOT} && \
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
                subject: "Build Failed: ${currentBuild.fullDisplayName}",
                body: """
                    Build execution failed!
                    
                    Build: ${env.BUILD_NUMBER}
                    Branch: ${env.GIT_BRANCH}
                    Commit: ${env.GIT_COMMIT}
                    Status: ${currentBuild.result}
                    
                    Check console output at: ${env.BUILD_URL}
                """,
                to: "${EMAIL_RECIPIENTS}",
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