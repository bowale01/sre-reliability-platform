terraform {
  required_version = ">= 1.5"
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.44"
    }
  }

  backend "s3" {
    key = "40-observability/terraform.tfstate"
    # bucket         = "<from 00-remote-state output>"
    # dynamodb_table = "<from 00-remote-state output>"
    # region         = "us-east-1"
    # encrypt        = true
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}/"
}
