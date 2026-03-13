param(
  [string]$Region = "us-west-2",
  [string]$Cluster = "osc-staging",
  [string[]]$InstanceIds = @(),
  [int]$DefaultDesiredCount = 1,
  [int]$SubmissionWorkerDesiredCount = 1,
  [switch]$SkipWait
)

$ErrorActionPreference = "Stop"

if ($InstanceIds.Count -gt 0) {
  Write-Host "Starting EC2 instances: $($InstanceIds -join ', ')"
  aws ec2 start-instances --region $Region --instance-ids $InstanceIds | Out-Null

  if (-not $SkipWait) {
    Write-Host "Waiting for instances to be running..."
    aws ec2 wait instance-running --region $Region --instance-ids $InstanceIds
  }

  aws ec2 describe-instances `
    --region $Region `
    --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].{id:InstanceId,state:State.Name}" `
    --output table
}

Write-Host "Listing ECS services in cluster '$Cluster' ($Region)..."
$serviceArnsRaw = aws ecs list-services `
  --region $Region `
  --cluster $Cluster `
  --query "serviceArns" `
  --output text

if ([string]::IsNullOrWhiteSpace($serviceArnsRaw)) {
  Write-Host "No ECS services found in cluster '$Cluster'."
  exit 0
}

$serviceNames = $serviceArnsRaw -split "\s+" | Where-Object { $_ } | ForEach-Object { ($_ -split "/")[-1] }

foreach ($service in $serviceNames) {
  $desired = $DefaultDesiredCount
  if ($service -eq "osc-submission-worker") {
    $desired = $SubmissionWorkerDesiredCount
  }

  Write-Host "Scaling up $service to $desired..."
  aws ecs update-service `
    --region $Region `
    --cluster $Cluster `
    --service $service `
    --desired-count $desired | Out-Null
}

if (-not $SkipWait) {
  Write-Host "Waiting for ECS services to stabilize..."
  foreach ($service in $serviceNames) {
    aws ecs wait services-stable `
      --region $Region `
      --cluster $Cluster `
      --services $service
  }
}

Write-Host "Current ECS desired/running counts:"
aws ecs describe-services `
  --region $Region `
  --cluster $Cluster `
  --services $serviceNames `
  --query "services[].{name:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount,status:status}" `
  --output table

Write-Host "Done."
