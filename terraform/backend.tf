terraform {
  backend "s3" {
    bucket       = "taskflow-obs-tfstate-713923090919"
    key          = "observability/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
