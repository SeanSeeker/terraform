terraform {
  required_providers {
    volcengine = {
      source = "volcengine/volcengine"
      version = "0.0.161"
    }
  }
}

provider "volcengine" {
  region = var.region
}
