output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "task_family" {
  value = aws_ecs_task_definition.app.family
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "security_group_id" {
  value = aws_security_group.ecs.id
}
