packer {
  required_plugins {
    huaweicloud = {
      version = ">=v1.0.0"
      source  = "github.com/huaweicloud/huaweicloud"
    }
  }
}

locals {
    timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "huaweicloud-ecs" "axiom" {
  access_key  = var.access_key
  secret_key  = var.secret_key
  region      = var.region
  project_id  = var.project_id

  source_image_name = "Ubuntu 20.04 server 64bit"
  instance_type     = "s6.small.1"
  ssh_username      = "root"
  
  vpc_id            = var.vpc_id
  subnet_id         = var.subnet_id
  security_group_id = var.security_group_id

  image_name = "axiom-${var.region}-${local.timestamp}"
}

build {
  sources = ["source.huaweicloud-ecs.axiom"]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait"
    ]
  }

  provisioner "file" {
    source      = "../configs/"
    destination = "/tmp/"
  }

  provisioner "shell" {
    script = "../provisioners/full.sh"
  }
}

// 变量定义
variable "access_key" {
    type = string
    description = "HuaweiCloud Access Key"
}

variable "secret_key" {
    type = string
    description = "HuaweiCloud Secret Key"
    sensitive = true
}

variable "region" {
    type = string
    description = "HuaweiCloud Region"
}

variable "project_id" {
    type = string
    description = "HuaweiCloud Project ID"
}

variable "vpc_id" {
    type = string
    description = "VPC ID"
}

variable "subnet_id" {
    type = string
    description = "Subnet ID"
}

variable "security_group_id" {
    type = string
    description = "Security Group ID"
} 