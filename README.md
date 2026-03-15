# create a secret/aws-secret.txt and add the leak to show the leak

# ami workflow

                Developer
                    │
                    ▼
             Git Repository
                    │
                    ▼
                CI Server
              (Jenkins)
                    │
                    ▼
        Launch EC2 Instance from AMI
                    │
                    ▼
          CI Build Agent Instance
       ┌─────────────────────────┐
       │ Build Tools             │
       │ Security Scanners       │
       │ Docker                  │
       │ Language Runtimes       │
       └─────────────────────────┘
                    │
                    ▼
             Build + Scan
                    │
                    ▼
            Artifact Repository
                    │
                    ▼
           Instance Terminated

---


8. Proof of Concept (POC)

Step 1: Create Base EC2 Instance

Launch an instance in Amazon Web Services.

Install required tools:

sudo apt update
sudo apt install docker.io maven nodejs npm -y
Step 2: Install CI Agent

Example for Jenkins:

sudo useradd jenkins
sudo mkdir /opt/jenkins-agent

Step 3: Install Security Tools

Example:

wget https://github.com/jeremylong/DependencyCheck/releases
Step 4: Harden the Instance

Disable root login

Enable firewall

Install monitoring agents

Step 5: Create AMI

From the instance:

EC2 Console → Actions → Create Image

This becomes your Generic CI Operation AMI.

Step 6: Configure CI to Use AMI

Configure CI server to launch agents from this AMI automatically.

Example:

Jenkins → Manage Nodes → Cloud → EC2 Plugin
9. Best Practices
1. Version AMIs

Use version naming.

Example:

ci-ami-v1.0
ci-ami-v1.1
2. Keep AMI Minimal

Only install required tools.

3. Automate AMI Creation

Use:

HashiCorp Packer

CI pipelines

4. Regular Security Updates

Rebuild AMIs frequently to include OS patches.

5. Use Immutable Infrastructure

Do not modify running CI agents.

Always rebuild the AMI.

6. Use Auto Scaling

Automatically launch CI agents based on pipeline demand.

# scripted pipeline
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
            --format table \
            --output ${REPORT_DIR}/trivy-license-report.txt \
            .
            """
        }

        stage('AMI Validation') {
            sh """
            echo "Checking AMI used by Jenkins agent..."

            AMI_ID=\$(curl -s http://169.254.169.254/latest/meta-data/ami-id || echo "unknown")

            echo "Detected AMI ID: \$AMI_ID"

            if [ "\$AMI_ID" = "unknown" ]; then
                echo "Not running on AWS EC2. Skipping AMI validation."
                exit 0
            fi

            if [ "\$AMI_ID" != "${APPROVED_AMI}" ]; then
                echo "Unapproved AMI detected: \$AMI_ID"
                echo "Approved AMI: ${APPROVED_AMI}"
                exit 1
            fi

            echo "AMI validation successful."
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