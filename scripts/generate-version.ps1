# Feature Branch Versioning Script for PowerShell
# This script generates version information for feature branches and development

param(
    [string]$Branch = "",
    [string]$BaseVersion = "1.0.0",
    [ValidateSet("env", "json", "yaml", "export")]
    [string]$Format = "env",
    [string]$OutputFile = "",
    [switch]$ShowDockerTags = $false,
    [switch]$ShowK8sEnv = $false,
    [switch]$Help = $false
)

function Show-Usage {
    Write-Host "Feature Branch Versioning Script (PowerShell)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\generate-version.ps1 [OPTIONS]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Branch BRANCH          Specify branch name (default: current git branch)"
    Write-Host "  -BaseVersion VER        Specify base version (default: 1.0.0)"
    Write-Host "  -Format FORMAT          Output format: env|json|yaml|export (default: env)"
    Write-Host "  -OutputFile FILE        Output to file instead of stdout"
    Write-Host "  -ShowDockerTags         Show suggested Docker tags"
    Write-Host "  -ShowK8sEnv             Show Kubernetes environment variables"
    Write-Host "  -Help                   Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\generate-version.ps1                              # Generate version for current branch"
    Write-Host "  .\generate-version.ps1 -Branch feature/user-auth    # Generate version for specific branch"
    Write-Host "  .\generate-version.ps1 -Format json -OutputFile version.json  # Output JSON to file"
    Write-Host "  .\generate-version.ps1 -ShowDockerTags             # Show Docker tag suggestions"
    Write-Host "  .\generate-version.ps1 -ShowK8sEnv                 # Show K8s environment variables"
}

if ($Help) {
    Show-Usage
    exit 0
}

# Check if we're in a git repository
try {
    git rev-parse --is-inside-work-tree | Out-Null
} catch {
    Write-Error "Error: Not in a git repository"
    exit 1
}

# Get branch name if not specified
if ([string]::IsNullOrEmpty($Branch)) {
    try {
        $Branch = git branch --show-current
        if ([string]::IsNullOrEmpty($Branch)) {
            Write-Error "Error: Could not determine current branch"
            exit 1
        }
    } catch {
        Write-Error "Error: Could not determine current branch"
        exit 1
    }
}

# Get git information
$CommitSha = (git rev-parse HEAD).Substring(0, 7)
$CommitShaFull = git rev-parse HEAD
$CommitCount = git rev-list --count HEAD
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$IsDirty = if ((git diff --quiet) -and (git diff --cached --quiet)) { "false" } else { "true" }
$LastTag = try { git describe --tags --abbrev=0 2>$null } catch { "v0.0.0" }

# Normalize branch name for version (remove special characters)
$BranchNormalized = $Branch -replace '[^a-zA-Z0-9._-]', '-'
$BranchNormalized = $BranchNormalized.ToLower()

# Determine version strategy based on branch name
switch -Regex ($Branch) {
    '^(main|master)$' {
        $Version = $BaseVersion
        $VersionLabel = "v$BaseVersion-main-$CommitSha"
        $DeploymentType = "production"
        $Environment = "production"
    }
    '^(develop|development)$' {
        $Version = "$BaseVersion-dev-$CommitSha"
        $VersionLabel = "v$BaseVersion-dev-$CommitSha"
        $DeploymentType = "development"
        $Environment = "development"
    }
    '^release/' {
        $ReleaseVersion = $Branch -replace '^release/', ''
        $Version = "$ReleaseVersion-rc-$CommitSha"
        $VersionLabel = "v$ReleaseVersion-rc-$CommitSha"
        $DeploymentType = "release-candidate"
        $Environment = "staging"
    }
    '^hotfix/' {
        $HotfixVersion = $Branch -replace '^hotfix/', ''
        $Version = "$HotfixVersion-hotfix-$CommitSha"
        $VersionLabel = "v$HotfixVersion-hotfix-$CommitSha"
        $DeploymentType = "hotfix"
        $Environment = "staging"
    }
    '^(feature/|feat/)' {
        $FeatureName = $Branch -replace '^(feature/|feat/)', ''
        $Version = "$BaseVersion-feat-$FeatureName-$CommitSha"
        $VersionLabel = "v$BaseVersion-feat-$FeatureName-$CommitSha"
        $DeploymentType = "feature"
        $Environment = "development"
    }
    default {
        $Version = "$BaseVersion-$BranchNormalized-$CommitSha"
        $VersionLabel = "v$BaseVersion-$BranchNormalized-$CommitSha"
        $DeploymentType = "custom"
        $Environment = "development"
    }
}

# Add dirty suffix if working tree is dirty
if ($IsDirty -eq "true") {
    $Version = "$Version-dirty"
    $VersionLabel = "$VersionLabel-dirty"
}

# Generate Docker tags
$DockerTagPrimary = $Version
$DockerTagBranch = $BranchNormalized
$DockerTagCommit = $CommitSha
$DockerTagLatestBranch = "$BranchNormalized-latest"

# Generate output based on format
function Generate-Output {
    switch ($Format) {
        "env" {
            @"
# Version Information for Branch: $Branch
VERSION=$Version
VERSION_LABEL=$VersionLabel
OTEL_SERVICE_VERSION=$Version
COMMIT_SHA=$CommitSha
COMMIT_SHA_FULL=$CommitShaFull
COMMIT_COUNT=$CommitCount
BRANCH_NAME=$Branch
BRANCH_NORMALIZED=$BranchNormalized
DEPLOYMENT_TYPE=$DeploymentType
ENVIRONMENT=$Environment
BUILD_TIMESTAMP=$Timestamp
IS_DIRTY=$IsDirty
LAST_TAG=$LastTag
DOCKER_TAG_PRIMARY=$DockerTagPrimary
DOCKER_TAG_BRANCH=$DockerTagBranch
DOCKER_TAG_COMMIT=$DockerTagCommit
DOCKER_TAG_LATEST_BRANCH=$DockerTagLatestBranch
"@
        }
        "export" {
            @"
# Export version information for Branch: $Branch
`$env:VERSION="$Version"
`$env:VERSION_LABEL="$VersionLabel"
`$env:OTEL_SERVICE_VERSION="$Version"
`$env:COMMIT_SHA="$CommitSha"
`$env:COMMIT_SHA_FULL="$CommitShaFull"
`$env:COMMIT_COUNT="$CommitCount"
`$env:BRANCH_NAME="$Branch"
`$env:BRANCH_NORMALIZED="$BranchNormalized"
`$env:DEPLOYMENT_TYPE="$DeploymentType"
`$env:ENVIRONMENT="$Environment"
`$env:BUILD_TIMESTAMP="$Timestamp"
`$env:IS_DIRTY="$IsDirty"
`$env:LAST_TAG="$LastTag"
`$env:DOCKER_TAG_PRIMARY="$DockerTagPrimary"
`$env:DOCKER_TAG_BRANCH="$DockerTagBranch"
`$env:DOCKER_TAG_COMMIT="$DockerTagCommit"
`$env:DOCKER_TAG_LATEST_BRANCH="$DockerTagLatestBranch"
"@
        }
        "json" {
            @{
                version = $Version
                version_label = $VersionLabel
                otel_service_version = $Version
                git = @{
                    commit_sha = $CommitSha
                    commit_sha_full = $CommitShaFull
                    commit_count = [int]$CommitCount
                    branch_name = $Branch
                    branch_normalized = $BranchNormalized
                    is_dirty = [bool]($IsDirty -eq "true")
                    last_tag = $LastTag
                }
                deployment = @{
                    type = $DeploymentType
                    environment = $Environment
                }
                build = @{
                    timestamp = $Timestamp
                }
                docker_tags = @{
                    primary = $DockerTagPrimary
                    branch = $DockerTagBranch
                    commit = $DockerTagCommit
                    latest_branch = $DockerTagLatestBranch
                }
            } | ConvertTo-Json -Depth 10
        }
        "yaml" {
            @"
version: $Version
version_label: $VersionLabel
otel_service_version: $Version
git:
  commit_sha: $CommitSha
  commit_sha_full: $CommitShaFull
  commit_count: $CommitCount
  branch_name: $Branch
  branch_normalized: $BranchNormalized
  is_dirty: $IsDirty
  last_tag: $LastTag
deployment:
  type: $DeploymentType
  environment: $Environment
build:
  timestamp: $Timestamp
docker_tags:
  primary: $DockerTagPrimary
  branch: $DockerTagBranch
  commit: $DockerTagCommit
  latest_branch: $DockerTagLatestBranch
"@
        }
    }
}

# Output to file or stdout
$output = Generate-Output
if ($OutputFile) {
    $output | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Version information written to: $OutputFile" -ForegroundColor Green
} else {
    Write-Output $output
}

# Show Docker tags if requested
if ($ShowDockerTags) {
    Write-Host ""
    Write-Host " Suggested Docker Tags:" -ForegroundColor Blue
    Write-Host "  Primary: $DockerTagPrimary"
    Write-Host "  Branch:  $DockerTagBranch"
    Write-Host "  Commit:  $DockerTagCommit"
    Write-Host "  Latest:  $DockerTagLatestBranch"
    Write-Host ""
    Write-Host " Docker Build Commands:" -ForegroundColor Blue
    Write-Host "  docker build -t myregistry/observability-demo:$DockerTagPrimary ."
    Write-Host "  docker build -t myregistry/observability-demo:$DockerTagBranch ."
    Write-Host "  docker build -t myregistry/observability-demo:$DockerTagCommit ."
}

# Show Kubernetes environment variables if requested
if ($ShowK8sEnv) {
    Write-Host ""
    Write-Host "  Kubernetes Environment Variables:" -ForegroundColor Blue
    @"
        env:
        - name: VERSION_LABEL
          value: "$VersionLabel"
        - name: OTEL_SERVICE_VERSION
          value: "$Version"
        - name: COMMIT_SHA
          value: "$CommitSha"
        - name: BRANCH_NAME
          value: "$Branch"
        - name: DEPLOYMENT_TYPE
          value: "$DeploymentType"
        - name: ENVIRONMENT
          value: "$Environment"
        - name: BUILD_TIMESTAMP
          value: "$Timestamp"
"@
}

# Show summary if outputting to stdout
if (-not $OutputFile -and -not $ShowDockerTags -and -not $ShowK8sEnv) {
    Write-Host ""
    Write-Host " Version generated for branch: $Branch" -ForegroundColor Green
    Write-Host "   Version: $Version" -ForegroundColor Yellow
    Write-Host "   Label:   $VersionLabel" -ForegroundColor Yellow
    Write-Host "   Type:    $DeploymentType" -ForegroundColor Yellow
}
