# Tag Creation Script for Bad Configuration Images
# Usage: .\create-bad-tag.ps1 -Version <version> [-ConfigType <type>]
# 
# Examples:
#   .\create-bad-tag.ps1 -Version 1.0.0 -ConfigType bad     # Creates v1.0.0-bad
#   .\create-bad-tag.ps1 -Version 1.0.0 -ConfigType chaos   # Creates v1.0.0-chaos  
#   .\create-bad-tag.ps1 -Version 1.0.0                     # Creates v1.0.0 (normal)

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("normal", "bad", "chaos")]
    [string]$ConfigType = "normal"
)

# Remove 'v' prefix if present
$Version = $Version -replace '^v', ''

# Determine tag name based on config type
switch ($ConfigType) {
    "bad" {
        $Tag = "v$Version-bad"
        Write-Host "🚨 Creating BAD configuration tag: $Tag" -ForegroundColor Yellow
        Write-Host "   - ERROR_RATE: 30%" -ForegroundColor Yellow
        Write-Host "   - LATENCY_SIMULATION: enabled" -ForegroundColor Yellow
        Write-Host "   - OUTAGE_SIMULATION: enabled" -ForegroundColor Yellow
        Write-Host "   - MAX_LATENCY: 3.0s" -ForegroundColor Yellow
    }
    "chaos" {
        $Tag = "v$Version-chaos"
        Write-Host "💥 Creating CHAOS configuration tag: $Tag" -ForegroundColor Red
        Write-Host "   - ERROR_RATE: 50%" -ForegroundColor Red
        Write-Host "   - LATENCY_SIMULATION: enabled" -ForegroundColor Red
        Write-Host "   - OUTAGE_SIMULATION: enabled" -ForegroundColor Red
        Write-Host "   - MAX_LATENCY: 5.0s" -ForegroundColor Red
    }
    default {
        $Tag = "v$Version"
        Write-Host "✅ Creating NORMAL configuration tag: $Tag" -ForegroundColor Green
        Write-Host "   - ERROR_RATE: 10%" -ForegroundColor Green
        Write-Host "   - LATENCY_SIMULATION: disabled" -ForegroundColor Green
        Write-Host "   - OUTAGE_SIMULATION: disabled" -ForegroundColor Green
        Write-Host "   - MAX_LATENCY: 1.0s" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "📋 This will:" -ForegroundColor Cyan
Write-Host "   1. Create git tag: $Tag"
Write-Host "   2. Push to origin"
Write-Host "   3. Trigger GitHub Actions build"
Write-Host "   4. Publish to DockerHub and GHCR"
Write-Host ""

# Check if tag already exists
$existingTags = git tag -l
if ($existingTags -contains $Tag) {
    Write-Host "⚠️  Warning: Tag $Tag already exists!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Do you want to delete the existing tag and recreate it? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Write-Host "🗑️  Deleting existing tag..." -ForegroundColor Yellow
        try {
            git tag -d $Tag
            git push origin ":refs/tags/$Tag"
        }
        catch {
            Write-Host "Note: Remote tag may not exist" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "❌ Aborted" -ForegroundColor Red
        exit 1
    }
}

# Confirm action
$confirm = Read-Host "Do you want to proceed? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "❌ Aborted" -ForegroundColor Red
    exit 1
}

try {
    # Create and push tag
    Write-Host "🏷️  Creating tag $Tag..." -ForegroundColor Cyan
    git tag $Tag

    Write-Host "📤 Pushing tag to origin..." -ForegroundColor Cyan
    git push origin $Tag

    Write-Host ""
    Write-Host "🎉 Success! Tag $Tag has been created and pushed." -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Monitor the build progress:" -ForegroundColor Cyan
    Write-Host "   GitHub Actions: https://github.com/knappmi/observability-demo-app/actions"
    Write-Host ""
    Write-Host "📦 Once built, images will be available at:" -ForegroundColor Cyan
    Write-Host "   DockerHub: knappmi14/observability-demo-app:$Tag"
    Write-Host "   GHCR: ghcr.io/knappmi/observability-demo-app:$Tag"
    Write-Host ""

    if ($ConfigType -eq "bad" -or $ConfigType -eq "chaos") {
        Write-Host "⚠️  WARNING: This image contains BAD SLO configuration!" -ForegroundColor Red
        Write-Host "   Only use for testing and demonstration purposes." -ForegroundColor Red
        Write-Host "   Never deploy in production environments." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "🚀 You can test locally once the build completes:" -ForegroundColor Cyan
    Write-Host "   docker run -p 5000:5000 knappmi14/observability-demo-app:$Tag"
    Write-Host "   Invoke-WebRequest http://localhost:5000/slo-config"
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
