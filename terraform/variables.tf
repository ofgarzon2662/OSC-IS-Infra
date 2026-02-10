variable "region" {
  type        = string
  description = "AWS region for deployment."
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID that ECS tasks run in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for ECS tasks (awsvpc)."
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for ECS tasks."
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign public IPs to tasks (awsvpc)."
  default     = false
}

variable "services" {
  type = map(object({
    task_def_path = string
    desired_count = number
    enable_exec   = optional(bool, true)
  }))
  description = "Map of service names to task definition JSON paths."
}

variable "log_retention_in_days" {
  type        = number
  description = "Retention in days for /ecs/* log groups."
  default     = 30
}
