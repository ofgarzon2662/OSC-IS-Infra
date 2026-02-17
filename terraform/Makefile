TF ?= terraform

.PHONY: init fmt validate plan apply destroy \
        up-runtime down-runtime up-hybrid down-hybrid verify-runtime

init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

plan:
	$(TF) plan

apply:
	$(TF) apply

destroy:
	$(TF) destroy

up-runtime:
	$(TF) plan -var 'runtime_mode=up' -var 'manage_hybrid_infra=false'
	$(TF) apply -auto-approve -var 'runtime_mode=up' -var 'manage_hybrid_infra=false'

down-runtime:
	$(TF) plan -var 'runtime_mode=down' -var 'manage_hybrid_infra=false'
	$(TF) apply -auto-approve -var 'runtime_mode=down' -var 'manage_hybrid_infra=false'

up-hybrid:
	$(TF) plan -var 'runtime_mode=up' -var 'manage_hybrid_infra=true' -var 'infra_mode=active'
	$(TF) apply -auto-approve -var 'runtime_mode=up' -var 'manage_hybrid_infra=true' -var 'infra_mode=active'

down-hybrid:
	$(TF) plan -var 'runtime_mode=down' -var 'manage_hybrid_infra=true' -var 'infra_mode=hibernated' -var 'allow_destroy=true'
	$(TF) apply -auto-approve -var 'runtime_mode=down' -var 'manage_hybrid_infra=true' -var 'infra_mode=hibernated' -var 'allow_destroy=true'

verify-runtime:
	$(TF) output ecs_desired_counts
	$(TF) output managed_ec2_instance_state
