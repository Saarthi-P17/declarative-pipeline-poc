// scripted pipeline
node {
    // Define environment variables
    def REPORT_DIR = "reports"
    // def APPROVED_AMI = "ami-1234567890abcdef" // change to your approved AMI ID

    try {
        stage('Install Security Tools') {
            echo "Installing security tools..."

            sh '''
            set -e

            echo "Installing Gitleaks..."
            wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
            tar -xvzf gitleaks_8.18.0_linux_x64.tar.gz
            sudo mv gitleaks /usr/local/bin/

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

        stage('Checkout') {
            checkout scm
        }

        stage('Commit Sign-off Check') {
            sh './scripts/commit-signoff-check.sh'
        }

        stage('Credential Scan') {
            sh """
            mkdir -p ${REPORT_DIR}

            gitleaks detect \
            --source . \
            --report-format json \
            --report-path ${REPORT_DIR}/gitleaks-report.json \
            --exit-code 1
            """
        }

        stage('License Scan') {
            sh """
            mkdir -p ${REPORT_DIR}

            trivy fs \
            --scanners license \
            --format sarif \
            --output ${REPORT_DIR}/trivy-license-report.sarif \
            .
            """
        }

        

        // If all stages pass
        echo "Build completed successfully."

        // Slack notification for success
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

    } catch (err) {
        // Slack notification for failure
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
        error "Pipeline failed: ${err}"
    } finally {
        // Always archive artifacts
        archiveArtifacts artifacts: 'reports/*', fingerprint: true
    }
}