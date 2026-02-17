#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"

if [[ -z "$ACTION" ]]; then
  echo "Usage: ./scripts/power.sh <init|plan|apply|down-runtime|up-runtime|down-hybrid|up-hybrid|verify-runtime>"
  exit 1
fi

run_tf() {
  echo "terraform $*"
  terraform "$@"
}

case "$ACTION" in
  init)
    run_tf init
    ;;
  plan)
    run_tf plan
    ;;
  apply)
    run_tf apply
    ;;
  down-runtime)
    run_tf plan -var runtime_mode=down -var manage_hybrid_infra=false
    run_tf apply -auto-approve -var runtime_mode=down -var manage_hybrid_infra=false
    ;;
  up-runtime)
    run_tf plan -var runtime_mode=up -var manage_hybrid_infra=false
    run_tf apply -auto-approve -var runtime_mode=up -var manage_hybrid_infra=false
    ;;
  down-hybrid)
    run_tf plan -var runtime_mode=down -var manage_hybrid_infra=true -var infra_mode=hibernated -var allow_destroy=true
    run_tf apply -auto-approve -var runtime_mode=down -var manage_hybrid_infra=true -var infra_mode=hibernated -var allow_destroy=true
    ;;
  up-hybrid)
    run_tf plan -var runtime_mode=up -var manage_hybrid_infra=true -var infra_mode=active
    run_tf apply -auto-approve -var runtime_mode=up -var manage_hybrid_infra=true -var infra_mode=active
    ;;
  verify-runtime)
    run_tf output ecs_desired_counts
    run_tf output managed_ec2_instance_state
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
