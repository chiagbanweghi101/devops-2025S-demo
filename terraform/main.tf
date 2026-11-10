data "aws_caller_identity" "current" {}

# Customer-managed key so the registry passes CKV_AWS_136.
# Rotation is on so the key itself does not fail the rotation check.
resource "aws_kms_key" "ecr" {
  description             = "Encrypts images in the class ECR repository"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEcrToUseTheKey"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# This is the "blueprint" for our container registry
resource "aws_ecr_repository" "devops_repo" {
  # The name for your repository
  name = "devops-repo"

  # This setting makes sure you can't accidentally overwrite an image tag
  image_tag_mutability = "IMMUTABLE"

  # This block enables vulnerability scanning when you push an image
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  # Tags are good practice for organization
  tags = {
    Environment = "Testing"
    ManagedBy   = "DevOps Class"
  }
}

# This "output" block will print the registry's URL after it's created
output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.devops_repo.repository_url
}
