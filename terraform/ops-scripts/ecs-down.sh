#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-west-2}"
CLUSTER="${CLUSTER:-osc-staging}"
WAIT_FOR_STOPPED="${WAIT_FOR_STOPPED:-false}"
INSTANCE_IDS="${INSTANCE_IDS:-}"

echo "Listing ECS services in cluster '${CLUSTER}' (${REGION})..."
SERVICE_ARNS="$(aws ecs list-services --region "${REGION}" --cluster "${CLUSTER}" --query 'serviceArns' --output text || true)"

if [[ -z "${SERVICE_ARNS// }" ]]; then
  echo "No ECS services found in cluster '${CLUSTER}'."
else
  for arn in ${SERVICE_ARNS}; do
    service="${arn##*/}"
    echo "Scaling down ${service} to 0..."
    aws ecs update-service --region "${REGION}" --cluster "${CLUSTER}" --service "${service}" --desired-count 0 >/dev/null
  done

  echo "Current ECS desired/running counts:"
  aws ecs describe-services \
    --region "${REGION}" \
    --cluster "${CLUSTER}" \
    --services ${SERVICE_ARNS} \
    --query "services[].{name:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount,status:status}" \
    --output table
fi

if [[ -n "${INSTANCE_IDS// }" ]]; then
  echo "Stopping EC2 instances: ${INSTANCE_IDS}"
  aws ec2 stop-instances --region "${REGION}" --instance-ids ${INSTANCE_IDS} >/dev/null

  if [[ "${WAIT_FOR_STOPPED}" == "true" ]]; then
    echo "Waiting for instances to stop..."
    aws ec2 wait instance-stopped --region "${REGION}" --instance-ids ${INSTANCE_IDS}
  fi

  aws ec2 describe-instances \
    --region "${REGION}" \
    --instance-ids ${INSTANCE_IDS} \
    --query "Reservations[].Instances[].{id:InstanceId,state:State.Name}" \
    --output table
fi

echo "Done."
