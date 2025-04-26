resource "aws_s3_bucket" "tf_state" {
  bucket = "hackathon-devops-riju-tfstate-bucket-101"
}

resource "aws_dynamodb_table" "tf_lock" {
  name           = "hackathon-devops-riju-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
