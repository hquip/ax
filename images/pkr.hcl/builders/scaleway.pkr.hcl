variable "golang_version" {
  type = string
}

variable "variant" {
  type = string
}

variable "op_random_password" {
  type = string
}

variable "snapshot_name" {
  type = string
}

source "scaleway" "packer" {
  project_id = var.default_project_id
  access_key = var.access_key
  secret_key = var.secret_key
  image = "ubuntu_focal"
  zone = var.region
  commercial_type = var.default_size
  ssh_username = "root"
  image_name = var.snapshot_name
  snapshot_name = var.snapshot_name
  remove_volume = "true"
}

build {
  sources = [
    "source.scaleway.packer"
  ]
