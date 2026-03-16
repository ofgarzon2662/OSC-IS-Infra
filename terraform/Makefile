TF ?= terraform
S3_CONFIG := s3://osc-is-terraform-state/osc-staging/config

# Mode flags
_UP_VARS   := -var 'infra_mode=active'     -var 'runtime_mode=up'   -var 'allow_destroy=false'
_DOWN_VARS := -var 'infra_mode=hibernated' -var 'runtime_mode=down' -var 'allow_destroy=true'

.PHONY: init fmt validate \
        plan-up up \
        plan-down down \
        status \
        backup-config restore-config \
        up-runtime down-runtime up-hybrid down-hybrid verify-runtime \
        security-check

# ---------------------------------------------------------------------------
# Security scanning  (run before make up)
# ---------------------------------------------------------------------------
security-check:
	@echo "=== Running tfsec ==="
	docker run --rm -v "$(CURDIR):/src" aquasecurity/tfsec /src --no-color || true
	@echo "=== Running checkov ==="
	docker run --rm -v "$(CURDIR):/src" bridgecrew/checkov -d /src --framework terraform --compact --quiet || true
	@echo "=== Security scan complete ==="

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
# Config backup / restore  (S3 — AES-256 encrypted, versioned)
# Backs up terraform.tfvars and this Makefile — gitignored files that must
# not be lost. Restore pulls the latest version back to the working directory.
# ---------------------------------------------------------------------------
backup-config:
	aws s3 cp terraform.tfvars $(S3_CONFIG)/terraform.tfvars
	aws s3 cp Makefile         $(S3_CONFIG)/Makefile
	@echo "Backed up to $(S3_CONFIG)"

restore-config:
	aws s3 cp $(S3_CONFIG)/terraform.tfvars terraform.tfvars
	aws s3 cp $(S3_CONFIG)/Makefile         Makefile
	@echo "Restored from $(S3_CONFIG)"

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
