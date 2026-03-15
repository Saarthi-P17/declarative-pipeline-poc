pipeline {
    // using any agent
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
            slackSend(
                channel: '#ci-operation-notifications',
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
                message: """
                Build Failed
                Job: ${env.JOB_NAME}
                Build: #${env.BUILD_NUMBER}
                URL: ${env.BUILD_URL}
                """
            )
        }

        always {
            cleanWs()
            archiveArtifacts artifacts: 'reports/*', fingerprint: true
        }
    }
}