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

source "hcloud" "packer" {
  image       = "ubuntu-24.04"
  server_type = var.default_size
  location    = var.region
  token       = var.hetzner_key
  ssh_username = "root"
  snapshot_name = var.snapshot_name
}

build {
  sources = ["source.hcloud.packer"]
