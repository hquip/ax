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

source "digitalocean" "packer" {
  ssh_username  = "root"
  snapshot_name = var.snapshot_name
  api_token     = var.do_key
  image         = "ubuntu-20-04-x64"
  region        = var.region
  size          = var.default_size
}

build {
  sources = [
    "source.digitalocean.packer"
  ]

