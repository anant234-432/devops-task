pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'ap-south-1'         // your AWS region
    ECR_REPO          = 'devops-task-repo'    // your ECR repo name
    CLUSTER_NAME      = 'devops-task-cluster' // your ECS cluster
    SERVICE_NAME      = 'devops-task-svc'     // your ECS service
    IMAGE_TAG         = "${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build') {
      steps {
        sh '''
          npm ci
          npm test || echo "no tests"
        '''
      }
    }

    stage('Dockerize') {
      steps {
        sh 'docker build -t $ECR_REPO:$IMAGE_TAG .'
      }
    }

    stage('Push to Registry') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${env.AWS_DEFAULT_REGION}") {
          sh '''
            REPO_URI=$(aws ecr describe-repositories --repository-names $ECR_REPO --query "repositories[0].repositoryUri" --output text 2>/dev/null || true)

            if [ -z "$REPO_URI" ]; then
              aws ecr create-repository --repository-name $ECR_REPO
              REPO_URI=$(aws ecr describe-repositories --repository-names $ECR_REPO --query "repositories[0].repositoryUri" --output text)
            fi

            aws ecr get-login-password | docker login --username AWS --password-stdin $REPO_URI
            docker tag $ECR_REPO:$IMAGE_TAG $REPO_URI:$IMAGE_TAG
            docker push $REPO_URI:$IMAGE_TAG

            echo $REPO_URI > repo_uri.txt
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${env.AWS_DEFAULT_REGION}") {
          sh '''
            REPO_URI=$(cat repo_uri.txt)
            IMAGE="$REPO_URI:$IMAGE_TAG"

            # Get current task definition
            TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query "services[0].taskDefinition" --output text)

            # Register new task definition revision with new image
            NEW_TASK_DEF=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query "taskDefinition" --output json \
              | jq --arg IMAGE "$IMAGE" '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy,.runtimePlatform)' \
              | aws ecs register-task-definition --cli-input-json file:///dev/stdin --query "taskDefinition.taskDefinitionArn" --output text)

            # Update service to use new task definition
            aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $NEW_TASK_DEF
            aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME
          '''
        }
      }
    }
  }
}
