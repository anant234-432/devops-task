pipeline {
  agent any
  options { timestamps() }
  triggers { githubPush() } // webhook will trigger builds
  environment {
    AWS_REGION        = 'ap-south-1'
    AWS_CREDENTIALS   = 'aws-creds'

    // names used by terraform (fall back if outputs are missing)
    REPO_NAME         = 'devops-task-repo'
    CLUSTER_NAME      = 'devops-task-cluster'
    SERVICE_NAME      = 'devops-task-svc'
    DEFAULT_TASK_FAMILY = 'devops-task-task'

    IMAGE_TAG         = "dev-${env.BUILD_NUMBER}"
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
        withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
          sh '''
            set -e
            export TF_IN_AUTOMATION=1
            terraform -chdir=terraform init -upgrade
            terraform -chdir=terraform apply -auto-approve

            # capture outputs with fallbacks
            TASK_FAMILY=$(terraform -chdir=terraform output -raw task_family 2>/dev/null || echo "${DEFAULT_TASK_FAMILY}")
            echo -n "$TASK_FAMILY" > task_family.txt

            REPO_URI=$(terraform -chdir=terraform output -raw repo_url 2>/dev/null || \
              aws ecr describe-repositories --repository-names "${REPO_NAME}" \
                --query "repositories[0].repositoryUri" --output text)
            echo -n "$REPO_URI" > repo_uri.txt
          '''
        }
      }
    }

    stage('Dockerize & Push') {
      steps {
        withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
          sh '''
            set -e
            REPO_URI=$(cat repo_uri.txt)
            REGISTRY="${REPO_URI%%/*}"
            IMAGE="${REPO_URI}:${IMAGE_TAG}"

            aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"
            docker build -t "${REPO_NAME}:${IMAGE_TAG}" .
            docker tag  "${REPO_NAME}:${IMAGE_TAG}" "$IMAGE"
            docker push "$IMAGE"
            echo -n "$IMAGE" > image.txt
          '''
        }
      }
    }

    stage('Deploy to ECS') {
      steps {
        withAWS(credentials: "${AWS_CREDENTIALS}", region: "${AWS_REGION}") {
          sh '''
            set -e
            TASK_FAMILY=$(cat task_family.txt || echo "${DEFAULT_TASK_FAMILY}")
            IMAGE=$(cat image.txt)
            CLUSTER="${CLUSTER_NAME}"
            SERVICE="${SERVICE_NAME}"

            # find current task def (service first, else latest ACTIVE of family)
            CURRENT_TD=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
                         --query "services[0].taskDefinition" --output text 2>/dev/null || true)
            if [ "$CURRENT_TD" = "None" ] || [ -z "$CURRENT_TD" ]; then
              CURRENT_TD=$(aws ecs list-task-definitions --family-prefix "$TASK_FAMILY" --status ACTIVE \
                         --sort DESC --max-items 1 --query "taskDefinitionArns[0]" --output text)
            fi

            aws ecs describe-task-definition --task-definition "$CURRENT_TD" \
              --query taskDefinition --output json > td.json

            # update image & clean fields
            cat td.json | jq 'del(.revision,.status,.requiresAttributes,.compatibilities,.taskDefinitionArn,.registeredAt,.registeredBy)
                               | .containerDefinitions[0].image=env.IMAGE
                               | .family=env.TASK_FAMILY' > new-td.json

            NEW_TD_ARN=$(aws ecs register-task-definition --cli-input-json file://new-td.json \
                          --query taskDefinition.taskDefinitionArn --output text)

            aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --task-definition "$NEW_TD_ARN"
            aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"
            echo "$NEW_TD_ARN" > new_td_arn.txt
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'repo_uri.txt, image.txt, task_family.txt, new_td_arn.txt', onlyIfSuccessful: false
    }
  }
}
