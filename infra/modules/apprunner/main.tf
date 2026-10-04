resource "aws_apprunner_service" "app" {
  service_name = var.app_name

  source_configuration {
    image_repository {
      image_identifier      = "${var.repository_url}:latest"
      image_repository_type = "ECR"

      image_configuration {
        port = "8080"
      }
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_role.arn
    }

    auto_deployments_enabled = false
  }

  instance_configuration {
    instance_role_arn = aws_iam_role.instance_role.arn
  }
}

resource "aws_iam_role" "apprunner_role" {
  name = "${var.app_name}-apprunner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "build.apprunner.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role" "instance_role" {
  name = "${var.app_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "tasks.apprunner.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr" {
  role       = aws_iam_role.apprunner_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_readonly" {
  role       = aws_iam_role.apprunner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "instance_secrets" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

output "service_url" {
  value = aws_apprunner_service.app.service_url
}

variable "app_name" {
  type = string
}

variable "repository_url" {
  type = string
}
