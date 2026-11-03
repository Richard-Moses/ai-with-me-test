# Local backend: state is kept in terraform.tfstate next to these files (git-ignored).
# To use Terraform Cloud or S3 for remote state instead, replace this block.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
