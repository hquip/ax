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

source "azure-arm" "packer" {
  client_id                     = var.client_id
  client_secret                 = var.client_secret
  tenant_id                     = var.tenant_id
  subscription_id               = var.subscription_id

  managed_image_resource_group_name = var.resource_group
  managed_image_name                = var.snapshot_name

  build_resource_group_name = var.resource_group  # Use your existing resource group name

  os_type           = "Linux"
  image_publisher   = "Canonical"
  image_offer       = "0001-com-ubuntu-server-focal-daily"
  image_sku         = "20_04-daily-lts-gen2"
  vm_size           = var.default_size

}

build {
  sources = [
    "source.azure-arm.packer"
  ]

