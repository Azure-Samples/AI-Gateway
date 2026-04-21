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

Write-Host "==== Bootstrap finished $(Get-Date -Format o) ===="
Stop-Transcript | Out-Null
