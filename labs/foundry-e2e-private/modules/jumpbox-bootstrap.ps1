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
  [string]$ApimGatewayUrl = '',
  [string]$InferenceApiVersion = '2024-10-21',
  [string]$PrimaryApiPath = '',
  [string]$PrimaryModelDeployment = '',
  [string]$PrimarySubscriptionKey = '',
  [string]$CrossRegionApiPath = '',
  [string]$CrossRegionModelDeployment = '',
  [string]$CrossRegionSubscriptionKey = ''
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

# ---- 4. Install lab dependencies via uv ----
# The repo is managed with `uv` (https://docs.astral.sh/uv/). We install uv first,
# then run `uv sync` from the repo root to provision the .venv with everything
# pinned in pyproject.toml / uv.lock. Azure CLI is already installed system-wide
# as a native binary by Chocolatey above.
$pyprojectFile = Join-Path $repoPath 'pyproject.toml'
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
  $pythonExe = 'C:\Python312\python.exe'
  if (Test-Path $pythonExe) {
    $env:PATH = "C:\Python312;C:\Python312\Scripts;" + $env:PATH
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  }
}

# Install uv (idempotent — script no-ops if uv is already available)
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uvCmd) {
  Write-Host "---- Installing uv"
  try {
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
  } catch {
    Write-Warning "uv install via official script failed: $($_.Exception.Message)"
  }
  # uv installs to %USERPROFILE%\.local\bin by default
  $uvBin = Join-Path $env:USERPROFILE '.local\bin'
  if (Test-Path (Join-Path $uvBin 'uv.exe')) {
    $env:PATH = "$uvBin;" + $env:PATH
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
  }
}

if ($uvCmd -and (Test-Path $pyprojectFile)) {
  Write-Host "---- Running 'uv sync' in $repoPath"
  Push-Location $repoPath
  & uv sync
  if ($LASTEXITCODE -ne 0) { Write-Warning "uv sync exited with $LASTEXITCODE" }
  Pop-Location
} else {
  if (-not $uvCmd) { Write-Warning "uv not found on PATH; skipping dependency install" }
  if (-not (Test-Path $pyprojectFile)) { Write-Warning "pyproject.toml not found at $pyprojectFile; skipping dependency install" }
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
# right-click → Run with PowerShell to exercise the APIM AI Gateway directly
# with a scoped APIM subscription key (no Azure AD / managed identity needed
# from the caller). APIM still uses its own managed identity to authenticate
# to the Azure OpenAI backend behind the gateway.
try {
  if (-not [string]::IsNullOrWhiteSpace($ApimGatewayUrl)) {
    $publicDesktop = 'C:\Users\Public\Desktop'
    if (-not (Test-Path $publicDesktop)) { New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null }

    # Single-quoted here-string: contents are literal, no PS variable expansion.
    # Placeholders are substituted via String.Replace below before writing.
    $template = @'
<#
.SYNOPSIS
  Sends a test prompt through the APIM AI Gateway to an Azure OpenAI deployment
  using an APIM subscription key (no Azure AD sign-in required).
.DESCRIPTION
  Calls APIM at <gateway>/<api-path>/deployments/<model>/chat/completions using
  the openai Python SDK (AzureOpenAI) configured with `api_key` set to the
  scoped APIM subscription key. APIM in turn uses its system-assigned managed
  identity to authenticate to the Azure OpenAI backend.
  Note: this lab's APIM imports the stable Azure OpenAI inference OpenAPI
  spec (2024-10-21), which exposes chat.completions but not /responses.
#>
param(
  [string]$Prompt = 'Tell me one fun fact about Azure API Management.'
)

$ErrorActionPreference = 'Stop'

$gatewayUrl       = '__GATEWAY_URL__'
$apiPath          = '__API_PATH__'
$modelDeployment  = '__MODEL_DEPLOYMENT__'
$apiVersion       = '__API_VERSION__'
$subscriptionKey  = '__SUBSCRIPTION_KEY__'
$connectionLabel  = '__CONNECTION_LABEL__'

Write-Host "==== Test-AI-Gateway ($connectionLabel) ====" -ForegroundColor Cyan
Write-Host "Gateway URL : $gatewayUrl"
Write-Host "API path    : $apiPath"
Write-Host "Deployment  : $modelDeployment"
Write-Host "API version : $apiVersion"
Write-Host ""

# 1) Make sure python is on PATH
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  Write-Error 'python is not on PATH. Check C:\bootstrap.log and re-run the bootstrap.'
  Read-Host 'Press Enter to close'
  exit 1
}

# 2) Idempotently ensure the openai SDK is available.
#    Prefer `uv pip install` if uv is on PATH (the lab uses uv); otherwise
#    fall back to `python -m pip install`.
Write-Host 'Ensuring openai is installed...'
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($uvCmd) {
  & uv pip install --system --quiet --upgrade openai
} else {
  & python -m pip install --quiet --upgrade openai
}
if ($LASTEXITCODE -ne 0) {
  Write-Warning "openai install reported a non-zero exit code; continuing anyway."
}

# 3) Run the test inline via python stdin. Values flow through environment
#    variables, and stdin avoids Windows PowerShell native-command quote
#    rewriting that can strip Python string quotes from `python -c` arguments.
$py = @(
    'import os',
    'from openai import AzureOpenAI',
    '',
    'gateway_url = os.environ["AIGW_GATEWAY_URL"].rstrip("/")',
    'api_path    = os.environ["AIGW_API_PATH"].strip("/")',
    'model       = os.environ["AIGW_MODEL"]',
    'api_version = os.environ["AIGW_API_VERSION"]',
    'api_key     = os.environ["AIGW_KEY"]',
    'prompt      = os.environ["AIGW_PROMPT"]',
    '',
    'client = AzureOpenAI(',
    '    api_key=api_key,',
    '    api_version=api_version,',
    '    base_url=f"{gateway_url}/{api_path}",',
    ')',
    '',
    'completion = client.chat.completions.create(',
    '    model=model,',
    '    messages=[',
    '        {"role": "system", "content": "You are a helpful assistant routed through the APIM AI Gateway."},',
    '        {"role": "user", "content": prompt},',
    '    ],',
    ')',
    'choice = completion.choices[0]',
    'print(f"assistant: {choice.message.content}")',
    'print(f"Finish reason: {choice.finish_reason}")'
) -join [Environment]::NewLine

$env:AIGW_GATEWAY_URL = $gatewayUrl
$env:AIGW_API_PATH    = $apiPath
$env:AIGW_MODEL       = $modelDeployment
$env:AIGW_API_VERSION = $apiVersion
$env:AIGW_KEY         = $subscriptionKey
$env:AIGW_PROMPT      = $Prompt

try {
  $py | & python -
  $exit = $LASTEXITCODE
} finally {
  # Scrub the key from the environment as soon as the call returns.
  Remove-Item Env:AIGW_KEY -ErrorAction SilentlyContinue
}

Write-Host ''
if ($exit -eq 0) {
  Write-Host '==== Test completed successfully ====' -ForegroundColor Green
} else {
  Write-Host "==== Test failed with exit code $exit ====" -ForegroundColor Red
}

Read-Host 'Press Enter to close'
exit $exit
'@

    function Write-DesktopTest {
      param(
        [string]$FileName,
        [string]$ApiPath,
        [string]$ModelDeployment,
        [string]$SubscriptionKey,
        [string]$Label
      )
      $content = $template.
        Replace('__GATEWAY_URL__',       $ApimGatewayUrl).
        Replace('__API_PATH__',          $ApiPath).
        Replace('__MODEL_DEPLOYMENT__',  $ModelDeployment).
        Replace('__API_VERSION__',       $InferenceApiVersion).
        Replace('__SUBSCRIPTION_KEY__',  $SubscriptionKey).
        Replace('__CONNECTION_LABEL__',  $Label)
      $path = Join-Path $publicDesktop $FileName
      Set-Content -Path $path -Value $content -Encoding UTF8 -Force
      # Restrict the script to Administrators + SYSTEM only because it embeds
      # the APIM subscription key in cleartext.
      try {
        $acl = Get-Acl $path
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object { [void]$acl.RemoveAccessRule($_) }
        $admins = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'
        $system = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'
        $rights = [System.Security.AccessControl.FileSystemRights]'FullControl'
        $allow  = [System.Security.AccessControl.AccessControlType]'Allow'
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($admins, $rights, $allow)))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($system, $rights, $allow)))
        Set-Acl -Path $path -AclObject $acl
      } catch {
        Write-Warning "Failed to lock down ACL on $path : $_"
      }
      Write-Host "---- Wrote $FileName to public desktop ($Label -> $ApiPath/$ModelDeployment)"
    }

    if (-not [string]::IsNullOrWhiteSpace($PrimaryApiPath) -and `
        -not [string]::IsNullOrWhiteSpace($PrimaryModelDeployment) -and `
        -not [string]::IsNullOrWhiteSpace($PrimarySubscriptionKey)) {
      Write-DesktopTest -FileName 'Test-AI-Gateway-Primary.ps1' `
                        -ApiPath $PrimaryApiPath `
                        -ModelDeployment $PrimaryModelDeployment `
                        -SubscriptionKey $PrimarySubscriptionKey `
                        -Label 'primary'
    } else {
      Write-Host '---- Skipping Test-AI-Gateway-Primary.ps1 (primary path/model/key not provided)'
    }

    if (-not [string]::IsNullOrWhiteSpace($CrossRegionApiPath) -and `
        -not [string]::IsNullOrWhiteSpace($CrossRegionModelDeployment) -and `
        -not [string]::IsNullOrWhiteSpace($CrossRegionSubscriptionKey)) {
      Write-DesktopTest -FileName 'Test-AI-Gateway-CrossRegion.ps1' `
                        -ApiPath $CrossRegionApiPath `
                        -ModelDeployment $CrossRegionModelDeployment `
                        -SubscriptionKey $CrossRegionSubscriptionKey `
                        -Label 'cross-region'
    } else {
      Write-Host '---- Skipping Test-AI-Gateway-CrossRegion.ps1 (cross-region path/model/key not provided)'
    }
  } else {
    Write-Host '---- Skipping desktop test scripts (ApimGatewayUrl not provided)'
  }
} catch {
  Write-Warning "Failed to write desktop test scripts: $_"
}

Write-Host "==== Bootstrap finished $(Get-Date -Format o) ===="
Stop-Transcript | Out-Null
