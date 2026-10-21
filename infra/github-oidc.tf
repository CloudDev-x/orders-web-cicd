# Trusts GitHub's OIDC issuer so workflows can request short-lived AWS credentials.
# No thumbprint is set: AWS validates this issuer with its trusted CA library.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Only the main branch of this one repository can assume this role.
resource "aws_iam_role" "github_deploy" {
  name = "${var.app_name}-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:CloudDev-x@183810638/orders-web-cicd@1428183615:ref:refs/heads/main"
        }
      }
    }]
  })
}

# Push-only access to this one repository. GetAuthorizationToken has no resource-level
# scoping, so it must use "*".
resource "aws_iam_role_policy" "github_ecr_push" {
  name = "ecr-push-${var.app_name}"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

output "github_deploy_role_arn" {
  description = "Value for the AWS_ROLE_ARN repository variable in GitHub"
  value       = aws_iam_role.github_deploy.arn
}

# Deploy role: trusted only for jobs running in the "production" environment,
# so the required-reviewer approval gates the token itself.
resource "aws_iam_role" "github_deploy_prod" {
  name = "${var.app_name}-github-deploy-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:CloudDev-x@183810638/orders-web-cicd@1428183615:environment:production"
        }
      }
    }]
  })
}

# Only what a deploy needs: register a task revision, update this one service, and pass
# the two task roles to ECS. RegisterTaskDefinition has no resource-level scoping.
resource "aws_iam_role_policy" "github_ecs_deploy" {
  name = "ecs-deploy-${var.app_name}"
  role = aws_iam_role.github_deploy_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:UpdateService"]
        Resource = aws_ecs_service.app.id
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      }
    ]
  })
}

output "github_deploy_prod_role_arn" {
  description = "Value for the AWS_DEPLOY_ROLE_ARN repository variable in GitHub"
  value       = aws_iam_role.github_deploy_prod.arn
}
