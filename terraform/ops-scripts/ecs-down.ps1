param(
  [string]$Region = "us-west-2",
  [string]$Cluster = "osc-staging",
  [string[]]$InstanceIds = @(),
  [switch]$WaitForStopped
)

$ErrorActionPreference = "Stop"

Write-Host "Listing ECS services in cluster '$Cluster' ($Region)..."
$serviceArnsRaw = aws ecs list-services `
  --region $Region `
  --cluster $Cluster `
  --query "serviceArns" `
  --output text

if ([string]::IsNullOrWhiteSpace($serviceArnsRaw)) {
  Write-Host "No ECS services found in cluster '$Cluster'."
} else {
  $serviceNames = $serviceArnsRaw -split "\s+" | Where-Object { $_ } | ForEach-Object { ($_ -split "/")[-1] }

  foreach ($service in $serviceNames) {
    Write-Host "Scaling down $service to 0..."
    aws ecs update-service `
      --region $Region `
      --cluster $Cluster `
      --service $service `
      --desired-count 0 | Out-Null
  }

  Write-Host "Current ECS desired/running counts:"
  aws ecs describe-services `
    --region $Region `
    --cluster $Cluster `
    --services $serviceNames `
    --query "services[].{name:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount,status:status}" `
    --output table
}

if ($InstanceIds.Count -gt 0) {
  Write-Host "Stopping EC2 instances: $($InstanceIds -join ', ')"
  aws ec2 stop-instances --region $Region --instance-ids $InstanceIds | Out-Null

  if ($WaitForStopped) {
    Write-Host "Waiting for instances to stop..."
    aws ec2 wait instance-stopped --region $Region --instance-ids $InstanceIds
  }

  aws ec2 describe-instances `
    --region $Region `
    --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].{id:InstanceId,state:State.Name}" `
    --output table
}

Write-Host "Done."
