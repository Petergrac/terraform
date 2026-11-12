provider "aws" {
  region = "af-south-1"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-up-and-running-2929229" # Must be unique on all aws customers

  # Prevents accidental deletion of this s3 bucket
  lifecycle {
    prevent_destroy = true
  }
}
# Enabled so you can see the full history of the state files
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"

  }
}
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {} # Applied to the whole bucket
    noncurrent_version_expiration {
      noncurrent_days           = 60
      newer_noncurrent_versions = 10 # Always keep the 10 most recent old versions
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  depends_on = [aws_s3_bucket_versioning.enabled]
}
# Enable server side encryption so each data stored in s3 is encrypted by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
# Explicitly block all public access to the s3 bucket
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure terraform to now actually store the state files in the s3 bucket
# Make sure to run terraform init again to configure this backend
terraform {
  backend "s3" {
    bucket = "terraform-up-and-running-2929229" # The actual name of the bucket
    key    = "global/s3/terraform.tfstate"      # The file path in s3 where to store the state file
    region = "af-south-1"

    use_lockfile = true
    encrypt      = true # Encrypt the state file again here
  }
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "The ARN of the s3 bucket"
}
