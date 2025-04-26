terraform {
  backend "s3" {
    bucket         = "hackathon-devops-tfstate-bucket-101"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hackathon-devops-terraform-locks"
  }
}
