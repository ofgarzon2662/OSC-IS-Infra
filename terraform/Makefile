TF ?= terraform

# Mode flags
_UP_VARS   := -var 'infra_mode=active'     -var 'runtime_mode=up'   -var 'allow_destroy=false'
_DOWN_VARS := -var 'infra_mode=hibernated' -var 'runtime_mode=down' -var 'allow_destroy=true'

.PHONY: init fmt validate \
        plan-up up \
        plan-down down \
        status \
        up-runtime down-runtime up-hybrid down-hybrid verify-runtime

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

# ---------------------------------------------------------------------------
# Bring everything UP  (ALB · NLB · NAT · RDS · ECS services · EC2)
# ---------------------------------------------------------------------------
plan-up:
	$(TF) plan $(_UP_VARS)

up:
	$(TF) apply -auto-approve $(_UP_VARS)

# ---------------------------------------------------------------------------
# Bring everything DOWN  (destroys ALB · NLB · NAT · RDS; stops ECS + EC2)
# ECS task defs and log groups are preserved (free resources, fast revival).
# ---------------------------------------------------------------------------
plan-down:
	$(TF) plan $(_DOWN_VARS)

down:
	$(TF) apply -auto-approve $(_DOWN_VARS)

# ---------------------------------------------------------------------------
# Status / outputs
# ---------------------------------------------------------------------------
status:
	@echo "=== Desired counts ==="
	@$(TF) output -json ecs_desired_counts 2>/dev/null || true
	@echo "=== EC2 state ==="
	@$(TF) output -json managed_ec2_instance_state 2>/dev/null || true
	@echo "=== Endpoints ==="
	@$(TF) output db_private_fqdn 2>/dev/null || true
	@$(TF) output rabbitmq_private_fqdn 2>/dev/null || true
	@$(TF) output alb_dns_name 2>/dev/null || true
	@$(TF) output rds_master_secret_arn 2>/dev/null || true

# ---------------------------------------------------------------------------
# Legacy aliases (kept for backward compatibility)
# ---------------------------------------------------------------------------
up-runtime:
	$(TF) apply -auto-approve -var 'runtime_mode=up'   -var 'manage_hybrid_infra=false'

down-runtime:
	$(TF) apply -auto-approve -var 'runtime_mode=down' -var 'manage_hybrid_infra=false'

up-hybrid:
	$(TF) apply -auto-approve $(_UP_VARS)

down-hybrid:
	$(TF) apply -auto-approve $(_DOWN_VARS)

verify-runtime:
	$(TF) output ecs_desired_counts
	$(TF) output managed_ec2_instance_state
