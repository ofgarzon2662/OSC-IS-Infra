#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-west-2}"
CLUSTER="${CLUSTER:-osc-staging}"
DEFAULT_DESIRED_COUNT="${DEFAULT_DESIRED_COUNT:-1}"
SUBMISSION_WORKER_DESIRED_COUNT="${SUBMISSION_WORKER_DESIRED_COUNT:-1}"
SKIP_WAIT="${SKIP_WAIT:-false}"
INSTANCE_IDS="${INSTANCE_IDS:-}"

if [[ -n "${INSTANCE_IDS// }" ]]; then
  echo "Starting EC2 instances: ${INSTANCE_IDS}"
  aws ec2 start-instances --region "${REGION}" --instance-ids ${INSTANCE_IDS} >/dev/null

  if [[ "${SKIP_WAIT}" != "true" ]]; then
    echo "Waiting for instances to be running..."
    aws ec2 wait instance-running --region "${REGION}" --instance-ids ${INSTANCE_IDS}
  fi

  aws ec2 describe-instances \
    --region "${REGION}" \
    --instance-ids ${INSTANCE_IDS} \
    --query "Reservations[].Instances[].{id:InstanceId,state:State.Name}" \
    --output table
fi

echo "Listing ECS services in cluster '${CLUSTER}' (${REGION})..."
SERVICE_ARNS="$(aws ecs list-services --region "${REGION}" --cluster "${CLUSTER}" --query 'serviceArns' --output text || true)"

if [[ -z "${SERVICE_ARNS// }" ]]; then
  echo "No ECS services found in cluster '${CLUSTER}'."
  exit 0
fi

for arn in ${SERVICE_ARNS}; do
  service="${arn##*/}"
  desired="${DEFAULT_DESIRED_COUNT}"
  if [[ "${service}" == "osc-submission-worker" ]]; then
    desired="${SUBMISSION_WORKER_DESIRED_COUNT}"
  fi

  echo "Scaling up ${service} to ${desired}..."
  aws ecs update-service --region "${REGION}" --cluster "${CLUSTER}" --service "${service}" --desired-count "${desired}" >/dev/null
done

if [[ "${SKIP_WAIT}" != "true" ]]; then
  echo "Waiting for ECS services to stabilize..."
  for arn in ${SERVICE_ARNS}; do
    service="${arn##*/}"
    aws ecs wait services-stable --region "${REGION}" --cluster "${CLUSTER}" --services "${service}"
  done
fi

echo "Current ECS desired/running counts:"
aws ecs describe-services \
  --region "${REGION}" \
  --cluster "${CLUSTER}" \
  --services ${SERVICE_ARNS} \
  --query "services[].{name:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount,status:status}" \
  --output table

echo "Done."
