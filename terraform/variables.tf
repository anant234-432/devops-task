variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "app_name" {
  type    = string
  default = "devops-task"
}

variable "ecr_repo_name" {
  type    = string
  default = "devops-task-repo"
}

variable "cluster_name" {
  type    = string
  default = "devops-task-cluster"
}

variable "service_name" {
  type    = string
  default = "devops-task-svc"
}

variable "task_family" {
  type    = string
  default = "devops-task-task"
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "desired_count" {
  type    = number
  default = 1
}
