# Imports and Ownership Boundaries

This module controls two layers:

1. **Core runtime** (`main.tf`): ECS services/task definitions/log groups + EC2 runtime state.
2. **Hybrid infra hibernation** (`infra_hibernation.tf`): ALB/NLB/NAT/RDS — destroyed when hibernated, recreated when active.

## Remote state backend

State is stored in S3 with DynamoDB locking. Both resources exist in `us-west-2`.

- S3 bucket: defined in `versions.tf` (`backend "s3"` block)
- State key: `osc-staging/terraform.tfstate`

Run `terraform init` after cloning — Terraform will pull state from S3 automatically.

## Step 0 — Gather IDs

Before importing, collect the following from the AWS console or CLI:

```bash
# ECS cluster services
aws ecs list-services --cluster <cluster-name> --region us-west-2

# Load balancers
aws elbv2 describe-load-balancers --region us-west-2 --query "LoadBalancers[*].{Name:LoadBalancerName,ARN:LoadBalancerArn}"

# Target groups
aws elbv2 describe-target-groups --region us-west-2 --query "TargetGroups[*].{Name:TargetGroupName,ARN:TargetGroupArn}"

# Listeners (replace <lb-arn> with the ALB/NLB ARN)
aws elbv2 describe-listeners --load-balancer-arn <lb-arn> --region us-west-2

# NAT Gateways
aws ec2 describe-nat-gateways --region us-west-2 --query "NatGateways[?State=='available'].NatGatewayId"

# Private route tables (look for tables NOT associated with public subnets)
aws ec2 describe-route-tables --region us-west-2 --filters "Name=vpc-id,Values=<vpc-id>"

# RDS identifier
aws rds describe-db-instances --region us-west-2 --query "DBInstances[*].DBInstanceIdentifier"
```

## Step 1 — Import core ECS services

```bash
terraform import 'aws_ecs_service.this["<service-name>"]' \
  arn:aws:ecs:<region>:<account-id>:service/<cluster-name>/<service-name>
```

Repeat for each service in `terraform.tfvars` → `services` map:
- `osc-api-blue`
- `osc-adapter`
- `osc-submission-worker`
- `osc-submission-listener`
- `osc-get-history-worker`

> Note: `osc-fabric-bridge` is no longer managed. Decommission it manually:
> set desired_count=0 then delete the ECS service via console or CLI.

## Step 2 — Import EC2 runtime state

```bash
terraform import 'aws_ec2_instance_state.runtime["<instance-id>"]' <instance-id>
```

Import each instance ID listed in `ec2_instance_ids` in `terraform.tfvars`.

## Step 3 — Import hybrid infra resources (required for hibernation to work)

Run these only after setting `manage_hybrid_infra = true` in your tfvars.

### ALB

```bash
terraform import 'aws_lb.alb[0]'              <alb-arn>
terraform import 'aws_lb_target_group.alb[0]' <alb-target-group-arn>
terraform import 'aws_lb_listener.alb[0]'     <alb-listener-arn>
```

### NLB

```bash
terraform import 'aws_lb.nlb[0]'              <nlb-arn>
terraform import 'aws_lb_target_group.nlb[0]' <nlb-target-group-arn>
terraform import 'aws_lb_listener.nlb[0]'     <nlb-listener-arn>
```

### NAT Gateway

```bash
terraform import 'aws_nat_gateway.this[0]' <nat-gateway-id>
```

### NAT Routes (one per private route table)

```bash
terraform import 'aws_route.private_default_ipv4["<rtb-id>"]' <rtb-id>_0.0.0.0/0
```

Repeat for each route table ID in `nat.private_route_table_ids`.

### RDS

```bash
terraform import 'aws_db_instance.this[0]' <db-identifier>
```

## Power operations

After imports are complete:

```bash
# Shut everything down (~$0/day)
make down-hybrid

# Bring everything back up (restores RDS from latest snapshot)
make up-hybrid

# Just stop ECS + EC2, keep ALB/NLB/NAT/RDS running
make down-runtime

# Start ECS + EC2 only
make up-runtime

# Check current ECS desired counts and EC2 states
make verify-runtime
```

## Safety notes

- Keep `protect_core_services = true` at all times in production.
- `infra_mode = "hibernated"` requires `allow_destroy = true` — this is intentional friction.
- For RDS hibernation, `final_snapshot_identifier` is set deterministically in `terraform.tfvars` to avoid naming conflicts on repeated hibernate/restore cycles.
- The NAT Gateway EIP is recreated on each `up-hybrid`. DNS for the on-prem VM connection should use the NLB or ALB DNS, not the EIP directly.
- **`terraform.tfvars` is gitignored** — it contains real resource IDs, ARNs, and configuration. Never commit it.
