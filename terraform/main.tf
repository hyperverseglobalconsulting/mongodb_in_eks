terraform {
  backend "s3" {
    bucket = "mongodb-on-eks"
    key    = "terraform/terraform.tfstate"
    region = "us-east-2"
  }
}
