provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

variable "gcp_project_id" {
  description = "The ID of the Google Cloud project"
}

variable "gcp_region" {
  description = "The ID of the Google Cloud project"
}