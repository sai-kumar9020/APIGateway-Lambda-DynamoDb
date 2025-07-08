
terraform {
  backend "s3" {
    bucket       = "api-gateway-lambda-ses"
    key          = "api-gateway-lambda-ses"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
