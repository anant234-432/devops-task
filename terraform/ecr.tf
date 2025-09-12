resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = false }

  tags = { Project = var.app_name }
}
