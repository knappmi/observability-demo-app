# Local Docker Build and Test Script (PowerShell)
# This script builds the Docker image locally and runs basic tests

param(
    [switch]$SkipTests = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host "Local Docker Build and Test Script (PowerShell)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\test-docker-build.ps1 [OPTIONS]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -SkipTests    Skip endpoint testing after build"
    Write-Host "  -Help         Show this help message"
    exit 0
}

Write-Host "🚀 Local Docker Build and Test Script" -ForegroundColor Green
Write-Host ""

# Generate version information
Write-Host "📋 Generating version information..." -ForegroundColor Yellow
if (Test-Path "scripts\generate-version.ps1") {
    $versionInfo = & .\scripts\generate-version.ps1 -Format json | ConvertFrom-Json
    $Version = $versionInfo.version
    $VersionLabel = $versionInfo.version_label
    $CommitSha = $versionInfo.git.commit_sha
    $BuildTimestamp = $versionInfo.build.timestamp
    Write-Host "   Version: $Version"
    Write-Host "   Label: $VersionLabel"
} else {
    # Fallback if script doesn't exist
    $Version = "1.0.0-local"
    $VersionLabel = "v1.0.0-local-test"
    $CommitSha = "local"
    $BuildTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Write-Host "   Using fallback version: $Version" -ForegroundColor Yellow
}

# Build Docker image
Write-Host "🐳 Building Docker image..." -ForegroundColor Yellow
try {
    docker build `
        --build-arg VERSION="$Version" `
        --build-arg VERSION_LABEL="$VersionLabel" `
        --build-arg COMMIT_SHA="$CommitSha" `
        --build-arg BUILD_TIMESTAMP="$BuildTimestamp" `
        -t observability-demo:$Version `
        -t observability-demo:latest `
        .\web-app

    Write-Host "✅ Docker image built successfully!" -ForegroundColor Green
} catch {
    Write-Error "❌ Docker build failed: $_"
    exit 1
}

if ($SkipTests) {
    Write-Host "⏭️  Skipping tests as requested" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 To run the container manually:" -ForegroundColor Yellow
    Write-Host "   docker run -p 5000:5000 observability-demo:$Version"
    exit 0
}

# Test the image
Write-Host "🧪 Testing the Docker image..." -ForegroundColor Yellow

try {
    # Start container in background
    $ContainerId = docker run -d -p 5000:5000 `
        -e VERSION_LABEL="$VersionLabel" `
        -e OTEL_SERVICE_VERSION="$Version" `
        -e SIM_BAD=false `
        observability-demo:$Version

    Write-Host "   Container started: $ContainerId"

    # Wait for container to be ready
    Write-Host "   Waiting for container to be ready..."
    Start-Sleep -Seconds 5

    # Test endpoints
    Write-Host "   Testing endpoints..."

    # Test health endpoint
    try {
        $healthResponse = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -TimeoutSec 10
        if ($healthResponse.StatusCode -eq 200) {
            Write-Host "   ✅ Health endpoint: OK" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Health endpoint: FAILED (Status: $($healthResponse.StatusCode))" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Health endpoint: FAILED ($_)" -ForegroundColor Red
    }

    # Test root endpoint
    try {
        $rootResponse = Invoke-WebRequest -Uri "http://localhost:5000/" -UseBasicParsing -TimeoutSec 10
        if ($rootResponse.StatusCode -eq 200) {
            Write-Host "   ✅ Root endpoint: OK" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Root endpoint: FAILED (Status: $($rootResponse.StatusCode))" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Root endpoint: FAILED ($_)" -ForegroundColor Red
    }

    # Test version endpoint
    try {
        $versionResponse = Invoke-RestMethod -Uri "http://localhost:5000/version" -TimeoutSec 10
        Write-Host "   ✅ Version endpoint: OK" -ForegroundColor Green
        Write-Host "   Response: $($versionResponse | ConvertTo-Json -Compress)"
    } catch {
        Write-Host "   ❌ Version endpoint: FAILED ($_)" -ForegroundColor Red
    }

} catch {
    Write-Error "❌ Testing failed: $_"
} finally {
    # Cleanup
    if ($ContainerId) {
        Write-Host "🧹 Cleaning up..." -ForegroundColor Yellow
        docker stop $ContainerId | Out-Null
        docker rm $ContainerId | Out-Null
    }
}

Write-Host "✅ All tests completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 To run the container manually:" -ForegroundColor Yellow
Write-Host "   docker run -p 5000:5000 observability-demo:$Version"
Write-Host ""
Write-Host "📝 To test with SLO simulation:" -ForegroundColor Yellow
Write-Host "   docker run -p 5000:5000 -e SIM_BAD=true -e ERROR_RATE=0.2 observability-demo:$Version"
