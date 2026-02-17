param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("init", "plan", "apply", "down-runtime", "up-runtime", "down-hybrid", "up-hybrid", "verify-runtime")]
  [string]$Action
)

$ErrorActionPreference = "Stop"

function Invoke-Terraform($args) {
  Write-Host "terraform $args"
  Invoke-Expression "terraform $args"
}

switch ($Action) {
  "init" {
    Invoke-Terraform "init"
  }
  "plan" {
    Invoke-Terraform "plan"
  }
  "apply" {
    Invoke-Terraform "apply"
  }
  "down-runtime" {
    Invoke-Terraform "plan -var runtime_mode=down -var manage_hybrid_infra=false"
    Invoke-Terraform "apply -auto-approve -var runtime_mode=down -var manage_hybrid_infra=false"
  }
  "up-runtime" {
    Invoke-Terraform "plan -var runtime_mode=up -var manage_hybrid_infra=false"
    Invoke-Terraform "apply -auto-approve -var runtime_mode=up -var manage_hybrid_infra=false"
  }
  "down-hybrid" {
    Invoke-Terraform "plan -var runtime_mode=down -var manage_hybrid_infra=true -var infra_mode=hibernated -var allow_destroy=true"
    Invoke-Terraform "apply -auto-approve -var runtime_mode=down -var manage_hybrid_infra=true -var infra_mode=hibernated -var allow_destroy=true"
  }
  "up-hybrid" {
    Invoke-Terraform "plan -var runtime_mode=up -var manage_hybrid_infra=true -var infra_mode=active"
    Invoke-Terraform "apply -auto-approve -var runtime_mode=up -var manage_hybrid_infra=true -var infra_mode=active"
  }
  "verify-runtime" {
    Invoke-Terraform "output ecs_desired_counts"
    Invoke-Terraform "output managed_ec2_instance_state"
  }
}
