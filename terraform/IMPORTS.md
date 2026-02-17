# Imports and Ownership Boundaries

This module can control two layers:

1. Core runtime (`main.tf`): ECS services/task definitions/log groups + EC2 runtime state.
2. Hybrid infra hibernation (`infra_hibernation.tf`): ALB/NLB/NAT/RDS.

## Recommended ownership boundary

- Keep always-managed:
  - `aws_ecs_service.this`
  - `aws_ecs_task_definition.this`
  - `aws_cloudwatch_log_group.ecs`
  - `aws_ec2_instance_state.runtime`
- Optional/manage carefully:
  - `aws_lb.*`
  - `aws_lb_target_group.*`
  - `aws_lb_listener.*`
  - `aws_nat_gateway.this`
  - `aws_route.private_default_ipv4`
  - `aws_db_instance.this`
  - `aws_db_subnet_group.this`
  - `aws_route53_record.*`

## Import examples

Run from `terraform/`:

```bash
terraform init
```

Core services:

```bash
terraform import 'aws_ecs_service.this["osc-api"]' <ecs-service-arn>
terraform import 'aws_ecs_service.this["osc-fabric-bridge"]' <ecs-service-arn>
terraform import 'aws_ecs_service.this["osc-submission-worker"]' <ecs-service-arn>
terraform import 'aws_ecs_service.this["osc-submission-listener"]' <ecs-service-arn>
terraform import 'aws_ecs_service.this["osc-get-history-worker"]' <ecs-service-arn>
```

Hybrid resources (only if you plan to hibernate them):

```bash
terraform import aws_lb.alb[0] <alb-arn>
terraform import aws_lb_target_group.alb[0] <alb-target-group-arn>
terraform import aws_lb_listener.alb[0] <alb-listener-arn>

terraform import aws_lb.nlb[0] <nlb-arn>
terraform import aws_lb_target_group.nlb[0] <nlb-target-group-arn>
terraform import aws_lb_listener.nlb[0] <nlb-listener-arn>

terraform import aws_nat_gateway.this[0] <nat-gateway-id>
terraform import aws_db_instance.this[0] <db-identifier>
```

For routes and Route53 aliases, import IDs are provider-specific; use:

```bash
terraform state list
terraform import -help
```

## Safety notes

- Keep `protect_core_services = true` unless intentionally decommissioning ECS.
- For destructive hibernation:
  - set `infra_mode = "hibernated"`
  - set `allow_destroy = true`
- For RDS hibernation, set a deterministic `rds.final_snapshot_identifier`.
