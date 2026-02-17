# Terraform Cost-Control (OSC-IS)

This directory now supports two operational layers:

1. Runtime controls (safe): ECS desired counts + EC2 instance start/stop.
2. Hybrid deep-sleep (optional): ALB/NLB/NAT/RDS hibernation with restore.

## Managed resources

- ECS task definitions (from templates)
- ECS services (Fargate, awsvpc)
- CloudWatch log groups `/ecs/<service-name>`
- EC2 runtime state (start/stop via `aws_ec2_instance_state`)
- Optional hybrid infra:
  - ALB + target group + listener (+ optional Route53 alias)
  - NLB + target group + listener (+ optional Route53 alias)
  - NAT Gateway + default routes (+ optional EIP)
  - RDS restore from snapshot + final snapshot on hibernate delete

## Prerequisites

- Terraform >= 1.5
- AWS provider >= 5.x
- Existing ECS cluster, VPC, subnets, and security groups
- For hybrid mode: import existing ALB/NLB/NAT/RDS resources (see `IMPORTS.md`)

## Modes

- `runtime_mode = "up" | "down"`
  - `up`: ECS services use configured `desired_count`, EC2 instances in `ec2_instance_ids` are running
  - `down`: ECS services scale to 0, EC2 instances stop

- `infra_mode = "active" | "hibernated"` (only when `manage_hybrid_infra = true`)
  - `active`: ALB/NLB/NAT/RDS resources exist
  - `hibernated`: resources are destroyed (destructive)
  - Safety: `allow_destroy = true` is required for `hibernated`

## Guardrails

- `protect_core_services = true` (default) sets `prevent_destroy` on ECS services, ECS task definitions, and log groups.
- `allow_destroy = true` is required to run destructive hibernation mode.

## Task definition templates

All app services are template-driven under `../task-defs`:

- `api-gateway.json.tmpl`
- `fabric-bridge.json.tmpl`
- `submission-worker.json.tmpl`
- `submission-listener.json.tmpl`
- `get-history-worker.json.tmpl`

Use `terraform.tfvars.example` as the full reference.

## Operator commands

From this `terraform/` directory:

### Bash / Make

```bash
make init
make down-runtime
make up-runtime
make down-hybrid
make up-hybrid
make verify-runtime
```

### PowerShell

```powershell
./scripts/power.ps1 -Action init
./scripts/power.ps1 -Action down-runtime
./scripts/power.ps1 -Action up-runtime
./scripts/power.ps1 -Action down-hybrid
./scripts/power.ps1 -Action up-hybrid
./scripts/power.ps1 -Action verify-runtime
```

## Standard workflow

```bash
terraform init
terraform plan
terraform apply
```

## Outputs

- ECS service ARNs
- Task definition ARNs
- Effective ECS desired counts
- Managed EC2 runtime states
- Optional ALB/NLB/NAT/RDS identifiers

## Import and ownership boundaries

Before using hybrid hibernation for existing infra, import resources into state.
See: `IMPORTS.md`.
