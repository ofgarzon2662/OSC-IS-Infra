provider "aws" {
  region = var.region
}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

locals {
  runtime_mode = lower(var.runtime_mode)

  desired_counts = {
    for name, cfg in var.services :
    name => local.runtime_mode == "down" ? 0 : cfg.desired_count
  }

  ec2_runtime_state = local.runtime_mode == "down" ? "stopped" : "running"

  managed_ec2_instances = var.manage_ec2_runtime_state ? {
    for id in var.ec2_instance_ids : id => id
  } : {}

  service_defs = {
    for name, cfg in var.services :
    name => jsondecode(
      (
        try(
          templatefile(cfg.task_def_template_path, cfg.task_def_vars),
          ""
        ) != ""
      ) ? templatefile(cfg.task_def_template_path, cfg.task_def_vars) : file(cfg.task_def_path)
    )
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  for_each          = var.services
  name              = "/ecs/${each.key}"
  retention_in_days = var.log_retention_in_days

  lifecycle {
    prevent_destroy = var.protect_core_services
  }
}

resource "aws_ecs_task_definition" "this" {
  for_each = local.service_defs

  family                   = each.value.family
  network_mode             = each.value.networkMode
  requires_compatibilities = each.value.requiresCompatibilities
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  execution_role_arn       = each.value.executionRoleArn
  task_role_arn            = each.value.taskRoleArn
  container_definitions    = jsonencode(each.value.containerDefinitions)

  lifecycle {
    prevent_destroy = var.protect_core_services
  }
}

resource "aws_ecs_service" "this" {
  for_each = var.services

  name                   = each.key
  cluster                = data.aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.this[each.key].arn
  desired_count          = local.desired_counts[each.key]
  launch_type            = "FARGATE"
  enable_execute_command = each.value.enable_exec

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  lifecycle {
    prevent_destroy = var.protect_core_services
  }
}

resource "aws_ec2_instance_state" "runtime" {
  for_each    = local.managed_ec2_instances
  instance_id = each.value
  state       = local.ec2_runtime_state
}
