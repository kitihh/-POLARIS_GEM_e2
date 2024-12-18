pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                    containers:
                    - name: docker
                      image: docker:24.0-dind
                      securityContext:
                        privileged: true
                      volumeMounts:
                        - name: docker-socket
                          mountPath: /var/run/docker.sock
                    - name: ros-builder
                      image: ros:noetic-ros-base-focal
                      command:
                        - cat
                      tty: true
                    volumes:
                    - name: docker-socket
                      hostPath:
                        path: /var/run/docker.sock
            '''
            defaultContainer 'ros-builder'
        }
    }
    
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
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    script {
                        try {
                            sh """
                                docker build -t ${DOCKER_IMAGE} \
                                    --progress=plain \
                                    --compress \
                                    -f Dockerfile .
                            """
                        } catch (Exception e) {
                            currentBuild.result = 'FAILURE'
                            error("Docker build failed: ${e.message}")
                        }
                    }
                }
            }
        }
        
        stage('Run Tests') {
            parallel {
                stage('Pure Pursuit Tests') {
                    steps {
                        container('ros-builder') {
                            script {
                                try {
                                    sh '''
                                        source /opt/ros/noetic/setup.bash
                                        mkdir -p ${WORKSPACE_ROOT}
                                        cp -r . ${WORKSPACE_ROOT}/
                                        cd ${WORKSPACE_ROOT}
                                        catkin_make run_tests_gem_pure_pursuit_sim -j$(nproc)
                                        catkin_test_results
                                    '''
                                } catch (Exception e) {
                                    currentBuild.result = 'FAILURE'
                                    error("Pure Pursuit tests failed: ${e.message}")
                                }
                            }
                        }
                    }
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