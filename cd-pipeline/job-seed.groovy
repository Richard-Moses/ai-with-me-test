// Optional: creates both Jenkins jobs automatically with the Job DSL plugin.
// In Jenkins: New Item > Freestyle project > Build > "Process Job DSLs" > paste this file, then Build.
// Edit the repository URL below first.

def repoUrl = 'https://github.com/YOUR_GITHUB_USER/YOUR_REPO.git'

// Task 4: build, test, push, deploy the microservice
pipelineJob('oeson-microservice') {
    description('Build, test, push and deploy the microservice')
    definition {
        cpsScm {
            scm {
                git {
                    remote { url(repoUrl) }
                    branches('*/main')
                }
            }
            scriptPath('Jenkinsfile')
        }
    }
}

// Task 6: Terraform + Ansible + kubectl + monitoring (run manually, it can create AWS resources)
pipelineJob('oeson-infrastructure') {
    description('Provision AWS, configure servers, deploy the app and monitoring')
    definition {
        cpsScm {
            scm {
                git {
                    remote { url(repoUrl) }
                    branches('*/main')
                }
            }
            scriptPath('cd-pipeline/Jenkinsfile')
        }
    }
}
