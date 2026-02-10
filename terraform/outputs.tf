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
