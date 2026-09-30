output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = module.ecr.repository_url
}

output "app_runner_url" {
  description = "App Runner service URL"
  value       = module.apprunner.service_url
}
