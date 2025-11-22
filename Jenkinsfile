pipeline {

    agent any

    environment {
        AWS_REGION = "eu-west-2"
    }

    stages {

        /* ------------------ CHECKOUT ------------------ */
        stage('Checkout Repo') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/suraj-tripathi/oneclickinfra.git'
            }
        }

        /* ------------------ TERRAFORM ------------------ */
        stage('Terraform Apply') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'jenkinsdemo',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        cd terraform
                        terraform init
                        terraform apply -auto-approve
                    '''
                }
            }
        }

        /* ------------------ GENERATE INVENTORY ------------------ */
        stage('Generate Inventory') {
            steps {
                script {
                    def master_ip  = sh(script: "cd terraform && terraform output -raw valkey_master_private_ip", returnStdout: true).trim()
                    def replica_ip = sh(script: "cd terraform && terraform output -raw valkey_replica_private_ip", returnStdout: true).trim()
                    def bastion_ip = sh(script: "cd terraform && terraform output -raw bastion_public_ip", returnStdout: true).trim()

                    writeFile file: "ansible/inventory/hosts.ini", text: """
[valkey_master]
${master_ip}

[valkey_replica]
${replica_ip}

[bastion]
${bastion_ip}

[all: vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=../terraform/valkey-demo-key.pem
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../terraform/valkey-demo-key.pem ubuntu@${bastion_ip}"'
"""
                }
            }
        }

        /* ------------------ ANSIBLE INSTALL ------------------ */
        stage('Install Valkey via Ansible') {
            steps {
                sh '''
                    cd ansible
                    ansible-galaxy install -r requirements.yml
                    ansible-playbook site.yml -i inventory/hosts.ini \
                      --ssh-common-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
                '''
            }
        }

       stage('Prepare Ansible (venv)') {
  steps {
    sh '''
      python3 -m venv .venv
      . .venv/bin/activate
      pip install --upgrade pip setuptools wheel
      pip install ansible
      ansible-galaxy --version
    '''
  }
}

stage('Install Valkey via Ansible (venv)') {
  steps {
    sh '''
      . .venv/bin/activate
      chmod 600 terraform/valkey-demo-key.pem || true
      cd ansible
      ansible-galaxy install -r requirements.yml
      ansible-playbook site.yml -i inventory/hosts.ini \
        --ssh-common-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    '''
  }
}


    post {
        success {
            echo "✔ Valkey HA Deployment Successful!"
        }
        failure {
            echo "❌ Pipeline FAILED! Check errors above."
        }
    }
}
