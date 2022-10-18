variable "region" {
  description = "Name of the region to deploy to"
  type        = string
  default     = "eu-west-2"
  validation {
    condition     = can(regex("(us(-gov)?|ap|ca|cn|eu|sa)-(central|(north|south)?(east|west)?)-\\d", var.region))
    error_message = "The value of variable 'region' is not valid."
  }
}

variable "vpc_cidr" {
  description = "CIDR Block to allocate to the VPCs"
  type        = string
  default     = "10.0.0.0/8"
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(\\/([0-9]|[1-2][0-9]|3[0-2]))?$", var.vpc_cidr))
    error_message = "The value of variable 'vpc_cidr' must be a valid network CIDR: a.b.c.d/m."
  }
}

variable "az_count" {
  description = "Number of availability zones to create VPC subnets in"
  type        = number
  default     = 3
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 6
    error_message = "The value of variable 'az_count' must be between 1 and 6."
  }
}

variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "sandbox"
  }
}
