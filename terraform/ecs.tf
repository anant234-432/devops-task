resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
  tags = { Project = var.app_name }
}

# Starter image so the service can be created before CI pushes
locals {
  starter_image = "public.ecr.aws/docker/library/nginx:alpine"
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.task_family
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = local.starter_image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = var.app_name
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = { Project = var.app_name }
}

resource "aws_ecs_service" "app" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  deployment_controller { type = "ECS" }

  propagate_tags = "SERVICE"
  tags           = { Project = var.app_name }

  lifecycle {
    ignore_changes = [task_definition] # CI will register new revisions
  }
}
