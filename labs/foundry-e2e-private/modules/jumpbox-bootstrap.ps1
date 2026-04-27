<#
.SYNOPSIS
  First-boot bootstrap for the AI-Gateway foundry-e2e-private lab jump-box.

.DESCRIPTION
  Installs the dev tooling needed to run the lab notebooks from inside the
  private VNet (Python 3.12, Azure CLI, Git, VS Code, PowerShell 7,
  Windows Terminal), clones the AI-Gateway repo, installs Python and VS Code
  dependencies, and writes a transcript to C:\bootstrap.log.

  Designed to run via the VM Run Command (Managed) under the SYSTEM account.
  Uses Chocolatey for installs because winget is per-user/AppX based and is not
  available in the SYSTEM context. Re-running is safe (every step is idempotent).
#>

param(
  [string]$ProjectEndpoint = '',
  [string]$PrimaryAgentModel = '',
  [string]$CrossRegionAgentModel = ''
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$logPath = 'C:\bootstrap.log'
Start-Transcript -Path $logPath -Append -Force | Out-Null
Write-Host "==== Bootstrap started $(Get-Date -Format o) ===="

function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('PATH', 'User')
  $env:PATH = ($machine, $user | Where-Object { $_ }) -join ';'
}

# ---- 1. Bootstrap Chocolatey ----
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Host "---- Installing Chocolatey"
  Set-ExecutionPolicy Bypass -Scope Process -Force
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  Refresh-Path
} else {
  Write-Host "---- Chocolatey already installed: $(choco --version)"
}

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Error "Chocolatey installation failed; aborting."
  Stop-Transcript | Out-Null
  exit 1
}

# Make Chocolatey unattended for the rest of the script
choco feature enable -n=allowGlobalConfirmation | Out-Null

# ---- 2. Install dev tooling via Chocolatey ----
$packages = @(
  'python312',         # Python 3.12 (also adds python.exe + pip to PATH machine-wide)
  'azure-cli',         # Azure CLI
  'git',               # Git for Windows
  'vscode',            # Visual Studio Code (system install)
  'powershell-core',   # PowerShell 7
  'microsoft-windows-terminal'
)

foreach ($p in $packages) {
  Write-Host "---- choco install $p"
  choco install $p -y --no-progress --limit-output
  if ($LASTEXITCODE -notin 0, 1641, 3010) {
    Write-Warning "choco install $p exited with $LASTEXITCODE"
  }
}

Refresh-Path

# ---- 3. Clone the AI-Gateway repo ----
$repoRoot = 'C:\Git'
$repoPath = Join-Path $repoRoot 'AI-Gateway'
if (-not (Test-Path $repoRoot)) { New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null }

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
  # choco may install to a path that needs explicit lookup
  $gitExe = 'C:\Program Files\Git\cmd\git.exe'
  if (Test-Path $gitExe) {
    $env:PATH = "C:\Program Files\Git\cmd;" + $env:PATH
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  }
}

if ($gitCmd) {
  if (Test-Path (Join-Path $repoPath '.git')) {
    Write-Host "---- AI-Gateway already cloned at $repoPath, pulling latest"
    Push-Location $repoPath
    & git pull --ff-only
    Pop-Location
  } else {
    Write-Host "---- Cloning AI-Gateway to $repoPath"
    & git clone https://github.com/Azure-Samples/AI-Gateway.git $repoPath
  }
} else {
  Write-Warning "git not found on PATH after install; skipping clone"
}

# ---- 4. pip install lab requirements ----
# We install from a filtered copy of requirements.txt that drops the `azure-cli`
# Python package because it pins old versions of azure-* libraries that conflict
# with the newer azure-ai-projects / azure-ai-agents pinned later in the file
# and sends pip's resolver into hours of backtracking. Azure CLI is already
# installed system-wide as a native binary by Chocolatey above.
$reqFile = Join-Path $repoPath 'requirements.txt'
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
  $pythonExe = 'C:\Python312\python.exe'
  if (Test-Path $pythonExe) {
    $env:PATH = "C:\Python312;C:\Python312\Scripts;" + $env:PATH
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  }
}

if ($pythonCmd -and (Test-Path $reqFile)) {
  Write-Host "---- Installing Python requirements from $reqFile (azure-cli filtered out)"
  $filtered = Join-Path $env:TEMP 'requirements-bootstrap.txt'
  Get-Content $reqFile | Where-Object { $_ -notmatch '^\s*azure-cli\s*$' } | Set-Content $filtered
  & python -m pip install --upgrade pip
  & python -m pip install --use-deprecated=legacy-resolver -r $filtered
  if ($LASTEXITCODE -ne 0) { Write-Warning "pip install -r exited with $LASTEXITCODE" }
} else {
  if (-not $pythonCmd) { Write-Warning "python not found on PATH; skipping pip install" }
  if (-not (Test-Path $reqFile)) { Write-Warning "requirements.txt not found at $reqFile; skipping pip install" }
}

# ---- 5. VS Code extensions ----
Write-Host "---- Installing VS Code extensions"
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
if (-not $codeCmd) {
  $codeBin = 'C:\Program Files\Microsoft VS Code\bin\code.cmd'
  if (Test-Path $codeBin) {
    $env:PATH = "C:\Program Files\Microsoft VS Code\bin;" + $env:PATH
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
  }
}
if ($codeCmd) {
  & code --install-extension ms-python.python      --force
  & code --install-extension ms-toolsai.jupyter    --force
  & code --install-extension ms-azuretools.vscode-bicep --force
} else {
  Write-Warning "VS Code 'code' CLI not on PATH; skipping extension install"
}

# ---- 6. Public-Desktop shortcut to the AI-Gateway repo root ----
# Falls back to the labs/ folder, then the repo root, depending on what exists.
try {
  $candidates = @(
    (Join-Path $repoPath 'labs\foundry-e2e-private'),
    (Join-Path $repoPath 'labs'),
    $repoPath
  )
  $labFolder = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

  $shortcut  = 'C:\Users\Public\Desktop\AI-Gateway Lab.lnk'
  $codeBin = (Get-Command code -ErrorAction SilentlyContinue).Source
  if (-not $codeBin) { $codeBin = 'C:\Program Files\Microsoft VS Code\bin\code.cmd' }
  if ($labFolder -and (Test-Path $codeBin)) {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($shortcut)
    $sc.TargetPath = $codeBin
    $sc.Arguments  = "`"$labFolder`""
    $sc.WorkingDirectory = $labFolder
    $sc.Save()
    Write-Host "---- Desktop shortcut created at $shortcut -> $labFolder"
  } else {
    Write-Warning "Skipped desktop shortcut (labFolder=$labFolder, code=$codeBin)"
  }
} catch {
  Write-Warning "Failed to create desktop shortcut: $_"
}

# ---- 7. Public-Desktop test scripts (Test-AI-Gateway-*.ps1) ----
# Drop ready-to-run PowerShell scripts on the Public Desktop so users can
# right-click → Run with PowerShell to exercise the APIM AI Gateway through
# the Foundry agent SDK without copy/pasting from the notebook.
try {
  if (-not [string]::IsNullOrWhiteSpace($ProjectEndpoint) -and -not [string]::IsNullOrWhiteSpace($PrimaryAgentModel)) {
    $publicDesktop = 'C:\Users\Public\Desktop'
    if (-not (Test-Path $publicDesktop)) { New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null }

    # Single-quoted here-string: contents are literal, no PS variable expansion.
    # Placeholders are substituted via String.Replace below before writing.
    $template = @'
<#
.SYNOPSIS
  Sends a test prompt through the APIM AI Gateway to a Foundry project.
.DESCRIPTION
  Uses azure-ai-projects (>= 2.0) and azure-identity (DefaultAzureCredential)
  to call the Chat Completions API on the Foundry project, targeting the
  model exposed via the APIM gateway connection. Prints the assistant
  response and the run status.
  Run `az login` once before invoking this script.
  Note: this lab's APIM imports the stable Azure OpenAI inference OpenAPI
  spec (2024-10-21), which exposes chat.completions but not /responses.
  To use openai_client.responses.create(...) instead, update the API import
  in modules/apim-gateway-connection.bicep to a preview spec that includes
  /responses (e.g. preview/2025-03-01-preview or later).
#>
param(
  [string]$Prompt = 'Tell me one fun fact about Azure API Management.'
)

$ErrorActionPreference = 'Stop'

$projectEndpoint = '__PROJECT_ENDPOINT__'
$agentModel      = '__AGENT_MODEL__'
$connectionLabel = '__CONNECTION_LABEL__'

Write-Host "==== Test-AI-Gateway ($connectionLabel) ====" -ForegroundColor Cyan
Write-Host "Project endpoint: $projectEndpoint"
Write-Host "Agent model    : $agentModel"
Write-Host ""

# 1) Make sure az + python are on PATH
foreach ($cmd in @('az','python')) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Error "$cmd is not on PATH. Check C:\bootstrap.log and re-run the bootstrap."
    Read-Host 'Press Enter to close'
    exit 1
  }
}

# 2) Make sure the user is signed in to Azure CLI
& az account show *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Not signed in to Azure CLI. Launching az login..." -ForegroundColor Yellow
  & az login | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Error 'az login failed.'
    Read-Host 'Press Enter to close'
    exit 1
  }
}

# 3) Idempotently install the SDKs we need.
#    Uses the latest azure-ai-projects (>= 2.0) which exposes the Responses API
#    via project_client.get_openai_client() and replaces the older
#    agents.create_agent / threads / messages / runs API.
Write-Host "Ensuring azure-ai-projects + azure-identity are installed..."
& python -m pip install --quiet --upgrade "azure-ai-projects>=2.0" azure-identity
if ($LASTEXITCODE -ne 0) {
  Write-Warning "pip install reported a non-zero exit code; continuing anyway."
}

# 4) Run the test inline via python -c using chat.completions, which is the
#    operation exposed by the current APIM import (stable/2024-10-21 spec).
#    Values are passed in via environment variables to avoid PS-vs-Python
#    quoting headaches. The Python source is built as a string array (instead
#    of a here-string) so this template file itself can be embedded inside
#    another PowerShell here-string without conflicting line-0 terminators.
$py = @(
    'import os',
    'from azure.ai.projects import AIProjectClient',
    'from azure.identity import DefaultAzureCredential',
    '',
    'endpoint = os.environ["AIGW_ENDPOINT"]',
    'model    = os.environ["AIGW_MODEL"]',
    'prompt   = os.environ["AIGW_PROMPT"]',
    '',
    'with (',
    '    DefaultAzureCredential() as credential,',
    '    AIProjectClient(endpoint=endpoint, credential=credential) as project,',
    '):',
    '    with project.get_openai_client() as openai_client:',
    '        completion = openai_client.chat.completions.create(',
    '            model=model,',
    '            messages=[',
    '                {"role": "system", "content": "You are a helpful assistant routed through the APIM AI Gateway."},',
    '                {"role": "user", "content": prompt},',
    '            ],',
    '        )',
    '        choice = completion.choices[0]',
    '        print(f"assistant: {choice.message.content}")',
    '        print(f"Finish reason: {choice.finish_reason}")'
) -join [Environment]::NewLine

$env:AIGW_ENDPOINT = $projectEndpoint
$env:AIGW_MODEL    = $agentModel
$env:AIGW_PROMPT   = $Prompt

& python -c $py
$exit = $LASTEXITCODE

Write-Host ""
if ($exit -eq 0) {
  Write-Host "==== Test completed successfully ====" -ForegroundColor Green
} else {
  Write-Host "==== Test failed with exit code $exit ====" -ForegroundColor Red
}

Read-Host 'Press Enter to close'
exit $exit
'@

    function Write-DesktopTest {
      param([string]$FileName, [string]$Model, [string]$Label)
      $content = $template.Replace('__PROJECT_ENDPOINT__', $ProjectEndpoint).Replace('__AGENT_MODEL__', $Model).Replace('__CONNECTION_LABEL__', $Label)
      $path = Join-Path $publicDesktop $FileName
      Set-Content -Path $path -Value $content -Encoding UTF8 -Force
      Write-Host "---- Wrote $FileName to public desktop ($Label -> $Model)"
    }

    Write-DesktopTest -FileName 'Test-AI-Gateway-Primary.ps1'     -Model $PrimaryAgentModel     -Label 'primary'

    if (-not [string]::IsNullOrWhiteSpace($CrossRegionAgentModel)) {
      Write-DesktopTest -FileName 'Test-AI-Gateway-CrossRegion.ps1' -Model $CrossRegionAgentModel -Label 'cross-region'
    } else {
      Write-Host "---- Skipping Test-AI-Gateway-CrossRegion.ps1 (CrossRegionAgentModel not set)"
    }
  } else {
    Write-Host "---- Skipping desktop test scripts (ProjectEndpoint or PrimaryAgentModel not provided)"
  }
} catch {
  Write-Warning "Failed to write desktop test scripts: $_"
}

Write-Host "==== Bootstrap finished $(Get-Date -Format o) ===="
Stop-Transcript | Out-Null
