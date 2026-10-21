output "ecr_repository_url" {
  description = "Image URL prefix for docker push"
  value       = aws_ecr_repository.app.repository_url
}
