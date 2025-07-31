# Test GHCR Access Script
# This script tests if we can access GitHub Container Registry

param(
    [string]$Username = "knappmi",
    [string]$Token = $env:GITHUB_TOKEN
)

Write-Host "🧪 Testing GHCR Access" -ForegroundColor Green
Write-Host ""

if (-not $Token) {
    Write-Host "❌ GITHUB_TOKEN environment variable not set" -ForegroundColor Red
    Write-Host "Please set GITHUB_TOKEN with a Personal Access Token that has 'packages:write' scope" -ForegroundColor Yellow
    exit 1
}

Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "   Username: $Username"
Write-Host "   Registry: ghcr.io"
Write-Host "   Token: $($Token.Substring(0, [Math]::Min(8, $Token.Length)))..."
Write-Host ""

# Test login to GHCR
Write-Host "🔐 Testing login to GHCR..." -ForegroundColor Yellow
try {
    echo $Token | docker login ghcr.io -u $Username --password-stdin
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully logged in to GHCR" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to login to GHCR" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error during GHCR login: $_" -ForegroundColor Red
    exit 1
}

# Test if we can pull a public image (to verify general access)
Write-Host "🐳 Testing pull access..." -ForegroundColor Yellow
try {
    docker pull ghcr.io/actions/runner:latest
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully pulled test image from GHCR" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Could not pull test image (may be normal)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Error pulling test image: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 GHCR access test completed" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. If login succeeded, GHCR access is working"
Write-Host "2. Make sure your repository has Packages enabled in Settings"
Write-Host "3. Ensure your GitHub token has 'packages:write' scope"
Write-Host "4. Try pushing a test image manually first"
