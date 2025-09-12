pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        REPO_NAME  = 'devops-task-repo'
        CLUSTER    = 'devops-task-cluster'
        SERVICE    = 'devops-task-svc'
    }

    stages {
        stage('Build') {
            steps {
                sh '''
                  set -e
                  npm ci
                  npm test || echo "no tests"
                '''
            }
        }

        stage('Terraform (init+apply & outputs)') {
            steps {
                withAWS(region: "${AWS_REGION}", credentials: 'aws-creds') {
                    sh '''
                      set -e
                      export TF_IN_AUTOMATION=1
                      terraform -chdir=terraform init -upgrade
                      terraform -chdir=terraform apply -auto-approve
                      terraform -chdir=terraform output -json > tf_outputs.json
                    '''
                }
            }
        }

        stage('Dockerize & Push') {
            steps {
                withAWS(region: "${AWS_REGION}", credentials: 'aws-creds') {
                    sh '''
                      set -e
                      IMAGE_TAG=dev-${BUILD_NUMBER}
                      REPO_URI=$(aws ecr describe-repositories --repository-names $REPO_NAME \
                                --query "repositories[0].repositoryUri" --output text 2>/dev/null || \
                                aws ecr create-repository --repository-name $REPO_NAME \
                                --query "repository.repositoryUri" --output text)

                      echo $REPO_URI > repo_uri.txt

                      aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URI
                      docker build -t $REPO_NAME:$IMAGE_TAG .
                      docker tag $REPO_NAME:$IMAGE_TAG $REPO_URI:$IMAGE_TAG
                      docker push $REPO_URI:$IMAGE_TAG
                    '''
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                withAWS(region: "${AWS_REGION}", credentials: 'aws-creds') {
                    sh '''
                      set -e
                      REPO_URI=$(cat repo_uri.txt)
                      IMAGE=$REPO_URI:dev-${BUILD_NUMBER}

                      TASK_DEF=$(aws ecs describe-task-definition \
                                --task-definition devops-task-task \
                                --query taskDefinition.taskDefinitionArn \
                                --output text)

                      aws ecs update-service \
                          --cluster $CLUSTER \
                          --service $SERVICE \
                          --force-new-deployment \
                          --region $AWS_REGION
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/tf_outputs.json', onlyIfSuccessful: true
        }
    }
}
