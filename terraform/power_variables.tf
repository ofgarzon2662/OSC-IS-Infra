variable "protect_core_services" {
  type        = bool
  description = "When true, prevents destroy of ECS services/task definitions/log groups managed by this module."
  default     = true
}

variable "manage_hybrid_infra" {
  type        = bool
  description = "When true, this module manages ALB/NLB/NAT/RDS power-state resources."
  default     = false
}

variable "infra_mode" {
  type        = string
  description = "Hybrid infrastructure mode: active (create/keep) or hibernated (destroy expensive resources)."
  default     = "active"

  validation {
    condition     = contains(["active", "hibernated"], lower(var.infra_mode))
    error_message = "infra_mode must be one of: active, hibernated."
  }
}

variable "allow_destroy" {
  type        = bool
  description = "Safety acknowledgment required for hibernated mode destructive actions."
  default     = false
}

variable "alb" {
  description = "Optional ALB configuration for hybrid hibernation control."
  type = object({
    name                       = string
    internal                   = bool
    security_group_ids         = list(string)
    subnet_ids                 = list(string)
    idle_timeout               = optional(number, 60)
    enable_deletion_protection = optional(bool, false)
    listener_port              = optional(number, 443)
    listener_protocol          = optional(string, "HTTPS")
    certificate_arn            = optional(string)
    target_group = object({
      name              = string
      port              = number
      protocol          = string
      target_type       = optional(string, "ip")
      health_check_path = optional(string, "/")
    })
    route53_record_name = optional(string)
    route53_zone_id     = optional(string)
    tags                = optional(map(string), {})
  })
  default = null
}

variable "nlb" {
  description = "Optional NLB configuration for hybrid hibernation control."
  type = object({
    name              = string
    internal          = bool
    subnet_ids        = list(string)
    listener_port     = optional(number, 5672)
    listener_protocol = optional(string, "TCP")
    target_group = object({
      name        = string
      port        = number
      protocol    = string
      target_type = optional(string, "ip")
    })
    route53_record_name = optional(string)
    route53_zone_id     = optional(string)
    tags                = optional(map(string), {})
  })
  default = null
}

variable "nat" {
  description = "Optional NAT Gateway configuration for hybrid hibernation control."
  type = object({
    subnet_id               = string
    private_route_table_ids = list(string)
    allocation_id           = optional(string)
    create_eip              = optional(bool, true)
    eip_tags                = optional(map(string), {})
    nat_tags                = optional(map(string), {})
  })
  default = null
}

variable "rds" {
  description = "Optional RDS restore/delete configuration for hybrid hibernation control."
  type = object({
    identifier                      = string
    instance_class                  = string
    db_subnet_ids                   = list(string)
    vpc_security_group_ids          = list(string)
    publicly_accessible             = optional(bool, false)
    multi_az                        = optional(bool, false)
    deletion_protection             = optional(bool, false)
    apply_immediately               = optional(bool, true)
    source_instance_identifier      = optional(string)
    restore_from_latest_snapshot    = optional(bool, true)
    restore_snapshot_identifier     = optional(string)
    final_snapshot_identifier       = optional(string)
    db_subnet_group_name            = optional(string)
    tags                            = optional(map(string), {})
  })
  default = null
}
