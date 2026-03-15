pipeline {
    agent any

    environment {
        REPORT_DIR = "reports"
    }

    stages {

        // configure git credentials for checkout
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // commit sign-off check
        stage('Commit Sign-off Check') {
            steps {
                sh './scripts/commit-signoff-check.sh'
            }
        }

        // scanning for leaks of secrets using gitleaks
        stage('Credential Scan') {
            steps {
                sh '''
                mkdir -p reports
                gitleaks detect \
                --source . \
                --report-format json \
                --report-path reports/gitleaks-report.json \
                --exit-code 1
                '''
            }
        }

        // scanning licenses using trivy
        stage('License Scan') {
            steps {
                sh '''
                mkdir -p reports

                trivy fs \
                --scanners license \
                --format table \
                --output reports/trivy-license-report.txt \
                .
                '''
            }
        }

    }

    post {

        success {
            echo "Pipeline completed successfully."

            mail to: 'msmukeshkumarsharma95@gmail.com',
            subject: "Pipeline Success",
            body: "Build completed successfully."

            // Slack notification for success
            slackSend (
                channel: '#ci-operation-notifications',
                color: 'good',
                message: "SUCCESS: Job ${env.JOB_NAME} Build ${env.BUILD_NUMBER} succeeded. ${env.BUILD_URL}"
            )
        }

        failure {
            echo "Pipeline failed."

            mail to: 'msmukeshkumarsharma95@gmail.com',
            subject: "Pipeline Failed",
            body: "Security checks failed."

            // Slack notification for failure
            slackSend (
                channel: '#ci-operation-notifications',
                color: 'danger',
                message: "FAILED: Job ${env.JOB_NAME} Build ${env.BUILD_NUMBER} failed. ${env.BUILD_URL}"
            )
        }

        always {
            archiveArtifacts artifacts: 'reports/*', fingerprint: true
        }
    }
}