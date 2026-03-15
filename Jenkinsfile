pipeline {
    agent any

    environment {
        REPORT_DIR = "reports"
    }

    stages {

        // Install required security tools
        stage('Install Security Tools') {
            steps {
                sh '''
                set -e

                echo "Installing Gitleaks..."
                wget -q https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks-linux-amd64 -O gitleaks
                chmod +x gitleaks
                sudo mv gitleaks /usr/local/bin/gitleaks

                echo "Installing Trivy..."
                sudo apt-get update -y
                sudo apt-get install -y wget apt-transport-https gnupg lsb-release

                wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list

                sudo apt-get update -y
                sudo apt-get install -y trivy

                echo "Installed versions:"
                gitleaks version
                trivy --version
                '''
            }
        }

        // checkout repository
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // commit sign-off verification
        stage('Commit Sign-off Check') {
            steps {
                sh './scripts/commit-signoff-check.sh'
            }
        }

        // credential leak scanning
        stage('Credential Scan') {
            steps {
                sh '''
                mkdir -p ${REPORT_DIR}

                gitleaks detect \
                --source . \
                --report-format json \
                --report-path ${REPORT_DIR}/gitleaks-report.json \
                --exit-code 1
                '''
            }
        }

        // license scanning using trivy
        stage('License Scan') {
            steps {
                sh '''
                mkdir -p ${REPORT_DIR}

                trivy fs \
                --scanners license \
                --format table \
                --output ${REPORT_DIR}/trivy-license-report.txt \
                .
                '''
            }
        }

    }

    post {

        success {
            slackSend(
                channel: '#ci-operation-notifications',
                color: 'good',
                message: """
                Build Successful

                Job: ${env.JOB_NAME}
                Build: #${env.BUILD_NUMBER}
                URL: ${env.BUILD_URL}
                """
            )
        }

        failure {
            slackSend(
                channel: '#ci-operation-notifications',
                color: 'danger',
                message: """
                Build Failed

                Job: ${env.JOB_NAME}
                Build: #${env.BUILD_NUMBER}
                URL: ${env.BUILD_URL}
                """
            )
        }

        always {
            archiveArtifacts artifacts: 'reports/*', fingerprint: true
            cleanWs()
        }
    }
}