# Terraform baseline (OSC-IS)

This folder provides a baseline for managing ECS services and CloudWatch log groups
from the existing task definition JSON files in the repo.

## What this manages

- ECS task definitions (parsed from JSON files)
- ECS services (Fargate, awsvpc)
- CloudWatch log groups `/ecs/<service-name>`

## Prereqs

- Terraform >= 1.5
- AWS credentials with ECS, CloudWatch permissions
- Existing VPC, subnets, and security groups

## Example `terraform.tfvars`

```
region           = "us-west-2"
ecs_cluster_name = "osc-staging"
vpc_id           = "vpc-xxxxxxxx"
subnet_ids       = ["subnet-aaaa", "subnet-bbbb"]
security_group_ids = ["sg-xxxxxxxx"]
assign_public_ip = false

services = {
  osc-fabric-bridge = {
    task_def_path = "${path.module}/../../fabric-bridge-task-definition.json"
    desired_count = 1
  }
  osc-submission-worker = {
    task_def_path = "${path.module}/../../submission-worker-task-def-v5.json"
    desired_count = 3
  }
  osc-submission-listener = {
    task_def_path = "${path.module}/../../submission-listener-task-definition.json"
    desired_count = 1
  }
  osc-api = {
    task_def_path = "${path.module}/../../api-gateway-updated-task-def.json"
    desired_count = 1
  }
  osc-get-history-worker = {
    task_def_path = "${path.module}/../../OSC-Artifact-Submission/get_history_worker/ghw-task-def.json"
    desired_count = 1
  }
}
```

## Workflow

```
terraform init
terraform plan
terraform apply
```

If any of the ECS services already exist, import them before `apply`:

```
terraform import aws_ecs_service.this["osc-fabric-bridge"] <service-arn>
```
