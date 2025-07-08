
terraform {
  backend "s3" {
    bucket       = "api-gateway-lambda"
    key          = "api-gateway-lambda"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}