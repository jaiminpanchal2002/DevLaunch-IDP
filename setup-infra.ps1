# setup-infra.ps1
# Sets up local Kubernetes (Kind) and installs ArgoCD, Prometheus, and Grafana.

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Green
Write-Host "   IDP Local Infrastructure Provisioning      " -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

# 1. Install prerequisites using winget
function Install-Dependency {
    param (
        [string]$Name,
        [string]$WingetId,
        [string]$CommandName
    )
    
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "[✓] $Name is already installed." -ForegroundColor Cyan
    } else {
        Write-Host "[!] $Name is not found. Installing via winget..." -ForegroundColor Yellow
        winget install --id $WingetId --accept-package-agreements --accept-source-agreements
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            Write-Error "Failed to install $Name. Please install it manually or add it to PATH."
        }
    }
}

Install-Dependency "Kind (Kubernetes in Docker)" "Kubernetes.Kind" "kind"
Install-Dependency "Helm" "Helm.Helm" "helm"

# 2. Check Docker is running
Write-Host "`nChecking if Docker is running..." -ForegroundColor Cyan
& docker info >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not running! Please start Docker Desktop and try again."
}
Write-Host "[✓] Docker is running." -ForegroundColor Green

# 3. Create Kind cluster if it doesn't exist
Write-Host "`nSetting up Kubernetes Cluster (Kind)..." -ForegroundColor Cyan
$clusters = kind get clusters
if ($clusters -contains "idp-demo") {
    Write-Host "[✓] Kind cluster 'idp-demo' already exists." -ForegroundColor Green
    kind export kubeconfig --name idp-demo
} else {
    Write-Host "Creating Kind cluster 'idp-demo'..." -ForegroundColor Yellow
    
    # Create cluster config to expose ports for local ingress/testing
    $config = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 80
    protocol: TCP
  - containerPort: 30001
    hostPort: 443
    protocol: TCP
"@
    $config | Out-File -FilePath "$PSScriptRoot/kind-config.yaml" -Encoding utf8
    kind create cluster --name idp-demo --config "$PSScriptRoot/kind-config.yaml"
    Remove-Item -Path "$PSScriptRoot/kind-config.yaml" -Force
}

# Ensure we are using the correct context
kubectl config use-context kind-idp-demo

# 4. Install ArgoCD
Write-Host "`nInstalling ArgoCD..." -ForegroundColor Cyan
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --set server.extraArgs={--insecure}

# 5. Install Prometheus + Grafana (kube-prometheus-stack)
Write-Host "`nInstalling Monitoring Stack (Prometheus + Grafana)..." -ForegroundColor Cyan
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --set grafana.adminPassword=admin

# 6. Success and instructions
Write-Host "`n==============================================" -ForegroundColor Green
Write-Host " Infrastructure Setup Completed successfully! " -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host "Access Instructions:"
Write-Host "1. ArgoCD Dashboard:"
Write-Host "   Command: kubectl port-forward -n argocd svc/argocd-server 8080:443"
Write-Host "   URL: http://localhost:8080 (Username: admin, retrieve password with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$`_)))"
Write-Host "2. Grafana Dashboard:"
Write-Host "   Command: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80"
Write-Host "   URL: http://localhost:3001 (Username: admin, Password: admin)"
Write-Host "3. Prometheus UI:"
Write-Host "   Command: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
Write-Host "   URL: http://localhost:9090"
