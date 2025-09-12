# DevOps Task — Logo Server

A simple Express.js web server that serves the **Swayatt logo** and is deployed using a **CI/CD pipeline** with Jenkins, Docker, and Terraform on AWS/GCP.

---

## What is this App?

This is a lightweight **Node.js** application built with **Express.js**.  
It serves a single logo image (`logoswayatt.png`) when accessed in the browser.

- **Framework**: Express.js  
- **Port**: 3000  
- **Endpoint**: GET `/` → Serves `logoswayatt.png`

---

## Prerequisites

- Node.js (v12 or higher)  
- npm (Node Package Manager)  
- Docker installed  
- Terraform installed  
- Jenkins setup with GitHub webhook  

---

## Installation

1. Clone or download this repository
   ```bash
   git clone <repo-url>
   cd devops-task
---

## LIVE LINK
1. http://13.202.73.21:3000/
---


## Project Structure
├── app.js              # Application code
├── logoswayatt.png     # Logo image
├── Dockerfile          # Docker container config
├── Jenkinsfile         # CI/CD pipeline definition
├── package.json        # Node.js dependencies
├── package-lock.json
├── .gitignore
├── .dockerignore
├── README.md           # Documentation
├── deployment-proof/   # Proof of deployment (URL or screenshots)
└── terraform/          # Infrastructure as Code (Terraform configs)


## Tools & Services Used

- **Version Control & Collaboration**
  - GitHub → Source code hosting, branching strategy, pull requests
  - GitHub Webhooks → Trigger Jenkins pipeline on code changes

- **CI/CD Pipeline**
  - Jenkins → Automates build, Dockerize, push, and deploy stages
  - Jenkinsfile → Declarative pipeline definition for reproducibility

- **Application & Runtime**
  - Node.js → Express.js server to serve the logo
  - npm → Dependency management and build scripts

- **Containerization**
  - Docker → Build and run containers for the Node.js app
  - Amazon Elastic Container Registry (ECR) → Stores Docker images

- **Cloud Infrastructure (AWS)**
  - Amazon ECS (Fargate) → Container orchestration and serverless deployment
  - IAM → Role-based access control for ECS tasks and ECR push/pull
  - VPC, Subnets, Security Groups → Networking and isolation for ECS services

- **Infrastructure as Code**
  - Terraform → Provisions AWS resources (ECR, ECS, IAM, networking, logs)
  - cleanup.ps1 → Script for destroying AWS resources safely

- **Monitoring & Logging**
  - Amazon CloudWatch → Centralized logging, metrics, and ECS task monitoring


  ## Challenges Faced & Solutions

1. **Jenkins Setup on WSL**  
   - *Challenge:* Jenkins was running inside WSL and commands like `npm` and `terraform` were not available.  
   - *Solution:* Installed Node.js, npm, Docker, and Terraform inside WSL, ensuring Jenkins agents had all required tools.  

2. **Pipeline Build Failures**  
   - *Challenge:* The initial pipeline failed because `npm test` was missing and Docker wasn’t configured.  
   - *Solution:* Adjusted the Jenkinsfile to gracefully skip tests if not defined and configured Docker with proper permissions.  

3. **Terraform Resource Conflicts**  
   - *Challenge:* Terraform apply failed due to pre-existing AWS resources (ECR repo, IAM roles, SG).  
   - *Solution:* Cleaned up conflicting resources manually and used `terraform import` where needed to align state.  

4. **ECS Service Networking Issues**  
   - *Challenge:* Tasks deployed to ECS Fargate did not expose a public IP initially.  
   - *Solution:* Updated ECS service to run in public subnets with `assignPublicIp=ENABLED` and ensured security groups allowed port `3000`.  

5. **Application Accessibility**  
   - *Challenge:* Even after deployment, the app was unreachable due to missing inbound rules on the ECS security group.  
   - *Solution:* Added inbound rule for port `3000` (TCP) from `0.0.0.0/0`, after which the service became accessible via public IP.  

---

## Possible Improvements

1. **Use an Application Load Balancer (ALB)**  
   - Instead of exposing ECS tasks directly with public IPs, deploy behind an ALB for better scalability, routing, and HTTPS support.  

2. **Automated Testing**  
   - Add real unit/integration tests to the Node.js app so the `npm test` stage in Jenkins validates code quality before deployment.  

3. **Blue-Green or Rolling Deployments**  
   - Implement safer deployment strategies in ECS (via CodeDeploy or ALB target groups) to avoid downtime during updates.  

4. **Secret Management**  
   - Integrate AWS Secrets Manager or SSM Parameter Store for storing credentials instead of Jenkins credentials directly.  

5. **Enhanced Monitoring & Alerts**  
   - Extend CloudWatch with custom metrics, dashboards, and SNS-based alerting for proactive monitoring of ECS tasks and pipeline health.  

