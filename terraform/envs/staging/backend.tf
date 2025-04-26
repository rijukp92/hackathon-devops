terraform {
  backend "s3" {
    bucket         = "hackathon-tfstate-bucket-101"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
