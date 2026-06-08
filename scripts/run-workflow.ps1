<#
.SYNOPSIS
  Install GitHub CLI if needed, authenticate, trigger the workflow and fetch logs.

.DESCRIPTION
  Attempts to install `gh` via winget if not present, runs `gh auth login --web`
  to authenticate, triggers `.github/workflows/auto-deploy.yml` on `main`,
  then fetches and streams the latest run logs.

USAGE
  .\run-workflow.ps1

#>

Param(
    [string]$WorkflowFile = '.github/workflows/auto-deploy.yml',
    [string]$Ref = 'main'
)

function Ensure-Gh {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "gh found: $(gh --version | Select-Object -First 1)"
        return $true
    }

    Write-Host "gh CLI not found. Attempting install with winget..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install --id GitHub.cli -e --silent
        } catch {
            Write-Warning "winget install failed. Please install gh manually: https://github.com/cli/cli/releases"
            return $false
        }
        Start-Sleep -Seconds 2
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            Write-Host "gh installed successfully"
            return $true
        }
    }

    Write-Warning "Could not install gh automatically. Install it and re-run this script."
    return $false
}

if (-not (Ensure-Gh)) { exit 2 }

Write-Host "Starting GitHub authentication (opens browser). Follow prompts to authenticate."
gh auth status 2>$null
gh auth login --web

Write-Host "Triggering workflow: $WorkflowFile on ref $Ref"
$runOutput = gh workflow run $WorkflowFile --ref $Ref 2>&1
Write-Host $runOutput

# Give GitHub a moment to register the run
Start-Sleep -Seconds 5

# Get latest run id for workflow
$latestId = gh run list --workflow=$(Split-Path $WorkflowFile -Leaf) --limit 1 --json databaseId --jq '.[0].databaseId' 2>$null
if (-not $latestId) {
    Write-Warning "Unable to determine run id. Use 'gh run list' to inspect recent runs."
    exit 0
}

Write-Host "Latest run id: $latestId"

Write-Host "Fetching logs (stream):"
gh run view $latestId --log

# Output run URL
$runUrl = gh run view $latestId --json htmlUrl --jq '.htmlUrl' 2>$null
if ($runUrl) { Write-Host "Run URL: $runUrl" }

Write-Host "Done. If logs show auth errors, paste them here and I'll help debug."
