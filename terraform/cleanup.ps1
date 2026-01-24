param(
  [string]$Region = "ap-south-1",
  [string]$App    = "devops-task"
)

$ErrorActionPreference = "SilentlyContinue"
$env:AWS_REGION = $Region

$Cluster   = "$App-cluster"
$Service   = "$App-svc"
$TaskFam   = "$App-task"
$Repo      = "$App-repo"
$LogGroup  = "/ecs/$App"
$SgName    = "$App-sg"

Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Cleaning resources for '$App'..." -ForegroundColor Cyan

# --- ECS Service ---
$svcStatus = (aws ecs describe-services --cluster $Cluster --services $Service --query 'services[0].status' --output text) 2>$null
if ($svcStatus -and $svcStatus -ne "None") {
  Write-Host "Scaling service to 0..." -ForegroundColor Yellow
  aws ecs update-service --cluster $Cluster --service $Service --desired-count 0 *> $null
  aws ecs wait services-stable --cluster $Cluster --services $Service

  Write-Host "Deleting ECS service $Service..." -ForegroundColor Yellow
  aws ecs delete-service --cluster $Cluster --service $Service --force *> $null

  for ($i=1; $i -le 12; $i++) {
    $check = (aws ecs describe-services --cluster $Cluster --services $Service --query 'services[0].status' --output text) 2>$null
    if (-not $check -or $check -eq "None") { break }
    Write-Host "  waiting service delete... ($i/12)"; Start-Sleep -Seconds 10
  }
}

# --- Task Definitions (all ACTIVE for family) ---
Write-Host "Deregistering task definitions for family $TaskFam (if any)..." -ForegroundColor Yellow
$td = (aws ecs list-task-definitions --family-prefix $TaskFam --status ACTIVE --query 'taskDefinitionArns' --output text) 2>$null
if ($td) {
  $td.Split() | ForEach-Object {
    Write-Host "  Deregister $_"
    aws ecs deregister-task-definition --task-definition $_ *> $null
  }
}

# --- ECS Cluster ---
$clStatus = (aws ecs describe-clusters --clusters $Cluster --query 'clusters[0].status' --output text) 2>$null
if ($clStatus -eq "ACTIVE") {
  Write-Host "Deleting ECS cluster $Cluster..." -ForegroundColor Yellow
  aws ecs delete-cluster --cluster $Cluster *> $null
}

# --- ECR Repo ---
$repoExists = (aws ecr describe-repositories --repository-names $Repo --query 'repositories[0].repositoryName' --output text) 2>$null
if ($repoExists -and $repoExists -ne "None") {
  Write-Host "Deleting ECR repo $Repo (force)..." -ForegroundColor Yellow
  aws ecr delete-repository --repository-name $Repo --force *> $null
}

# --- CloudWatch Logs ---
$lg = (aws logs describe-log-groups --log-group-name-prefix $LogGroup --query "logGroups[?logGroupName=='$LogGroup'].logGroupName" --output text)
if ($lg) {
  Write-Host "Deleting log group $LogGroup..." -ForegroundColor Yellow
  aws logs delete-log-group --log-group-name $LogGroup *> $null
}

# --- Security Group in Default VPC ---
$VpcId = (aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
$SgId  = (aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VpcId Name=group-name,Values=$SgName --query 'SecurityGroups[0].GroupId' --output text) 2>$null
if ($SgId -and $SgId -ne "None") {
  Write-Host "Deleting security group $SgName ($SgId)..." -ForegroundColor Yellow
  for ($i=1; $i -le 20; $i++) {
    aws ec2 delete-security-group --group-id $SgId *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "  SG deleted."; break }
    Write-Host "  SG still in use; retrying in 10s... ($i/20)"; Start-Sleep -Seconds 10
  }
}

# --- IAM Roles ---
Write-Host "Deleting IAM roles (if present)..." -ForegroundColor Yellow

# ecsTaskExecutionRole
$execRole = (aws iam get-role --role-name ecsTaskExecutionRole --query 'Role.RoleName' --output text) 2>$null
if ($execRole -and $execRole -ne "None") {
  aws iam detach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy *> $null
  aws iam delete-role --role-name ecsTaskExecutionRole *> $null
}

# app task role
$appRole = (aws iam get-role --role-name "$($App)-task-role" --query 'Role.RoleName' --output text) 2>$null
if ($appRole -and $appRole -ne "None") {
  aws iam delete-role --role-name "$($App)-task-role" *> $null
}

Write-Host ""
Write-Host "✅ Cleanup complete." -ForegroundColor Green
