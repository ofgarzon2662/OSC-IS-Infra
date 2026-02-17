output "task_definition_arns" {
  value = {
    for name, td in aws_ecs_task_definition.this :
    name => td.arn
  }
}

output "service_arns" {
  value = {
    for name, svc in aws_ecs_service.this :
    name => svc.arn
  }
}

output "ecs_desired_counts" {
  value = {
    for name, svc in aws_ecs_service.this :
    name => svc.desired_count
  }
}

output "managed_ec2_instance_state" {
  value = {
    for id, state in aws_ec2_instance_state.runtime :
    id => state.state
  }
}

output "alb_dns_name" {
  value = try(aws_lb.alb[0].dns_name, null)
}

output "nlb_dns_name" {
  value = try(aws_lb.nlb[0].dns_name, null)
}

output "nat_gateway_id" {
  value = try(aws_nat_gateway.this[0].id, null)
}

output "rds_instance_identifier" {
  value = try(aws_db_instance.this[0].identifier, null)
}
