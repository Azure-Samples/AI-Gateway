<#
.SYNOPSIS
    Creates the Microsoft Purview DLP policy that this lab enforces.

.DESCRIPTION
    Scopes a DLP policy to the lab's Entra "AI Gateway" app registration and
    blocks Credit Card + U.S. Social Security Number in either UploadText (Gate 1)
    or DownloadText (Gate 3) `processContent` activities. This is what makes
    `X-Purview-Blocked=1` fire on the two demo prompts.

    This is a lab-configured wrapper around the shared sample
    https://github.com/microsoft/purview-api-samples/tree/main/DLPforCustomAIApps

.PREREQUISITES
    - PowerShell 7+
    - ExchangeOnlineManagement module
    - Compliance Administrator (or Global Administrator) in the target tenant
#>

$ErrorActionPreference = 'Stop'

# ---- Configuration (edit before running) -----------------------------------
# Replace these placeholders with values from your own tenant.  The AppId must
# match the Entra app registration you created for the lab (README section 2).
$DlpPolicyName = 'APIM AI Gateway lab - Block sensitive data'
$DlpRuleName   = 'Block CC/SSN in prompts and responses'
$PolicyMode    = 'Enable'
$RestrictAction = 'Block'   # Block | Audit

$Applications = @(
    @{
        AppId   = '<lab-entra-app-id>'
        AppName = 'APIM AI Gateway (apim-purview-dlp lab)'
    }
)

$AlertRecipients     = @('<compliance-admin@contoso.onmicrosoft.com>')
$IncidentRecipients  = @('<compliance-admin@contoso.onmicrosoft.com>')
$NotifyRecipients    = @('<compliance-admin@contoso.onmicrosoft.com>')
$ReportSeverityLevel = 'High'

$SensitiveTypes = @(
    @{ Name = 'Credit Card Number';                minCount = '1' },
    @{ Name = 'U.S. Social Security Number (SSN)'; minCount = '1' }
)

# ---- Connect ---------------------------------------------------------------
Write-Host 'Connecting to Security & Compliance PowerShell...' -ForegroundColor Cyan
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession

# ---- Locations JSON --------------------------------------------------------
$LocationsObject = @(foreach ($app in $Applications) {
    @{
        Workload            = 'Applications'
        Location            = $app.AppId
        LocationDisplayName = $app.AppName
        LocationSource      = 'Entra'
        LocationType        = 'Individual'
        Inclusions          = @(@{ Type = 'Tenant'; Identity = 'All' })
    }
})
$LocationsJson = ConvertTo-Json -InputObject $LocationsObject -Depth 6 -Compress
if ($LocationsJson -notmatch '^\s*\[') { $LocationsJson = "[$LocationsJson]" }

# ---- Policy ----------------------------------------------------------------
Write-Host "Ensuring DLP policy '$DlpPolicyName'..." -ForegroundColor Yellow
$existingPolicy = Get-DlpCompliancePolicy -Identity $DlpPolicyName -ErrorAction SilentlyContinue
if (-not $existingPolicy) {
    New-DlpCompliancePolicy `
        -Name              $DlpPolicyName `
        -Comment           'apim-purview-dlp lab: blocks CC/SSN in prompts and responses.' `
        -Locations         $LocationsJson `
        -EnforcementPlanes @('Application') `
        -Mode              $PolicyMode | Out-Null
    Write-Host 'DLP policy created.' -ForegroundColor Green
}
else {
    Set-DlpCompliancePolicy `
        -Identity          $DlpPolicyName `
        -Locations         $LocationsJson `
        -EnforcementPlanes @('Application') `
        -Mode              $PolicyMode | Out-Null
    Write-Host 'DLP policy updated.' -ForegroundColor Green
}

# ---- Rule ------------------------------------------------------------------
Write-Host "Ensuring DLP rule '$DlpRuleName'..." -ForegroundColor Yellow
$existingRule = Get-DlpComplianceRule -Identity $DlpRuleName -ErrorAction SilentlyContinue

$ruleParams = @{
    ContentContainsSensitiveInformation = $SensitiveTypes
    GenerateAlert                       = $AlertRecipients
    GenerateIncidentReport              = $IncidentRecipients
    IncidentReportContent               = @('Default','Detections','DetectionDetails','MatchedItem','RulesMatched','Service','Severity','Title')
    NotifyUser                          = $NotifyRecipients
    ReportSeverityLevel                 = $ReportSeverityLevel
    RestrictAccess                      = @(
        @{ Setting = 'UploadText';   Value = $RestrictAction },
        @{ Setting = 'DownloadText'; Value = $RestrictAction }
    )
    Comment                             = 'apim-purview-dlp lab rule.'
}

if (-not $existingRule) {
    New-DlpComplianceRule -Name $DlpRuleName -Policy $DlpPolicyName @ruleParams | Out-Null
    Write-Host 'DLP rule created.' -ForegroundColor Green
}
else {
    Set-DlpComplianceRule -Identity $DlpRuleName @ruleParams | Out-Null
    Write-Host 'DLP rule updated.' -ForegroundColor Green
}

# ---- Verify ----------------------------------------------------------------
Write-Host ''; Write-Host 'Verification:' -ForegroundColor Cyan
Get-DlpCompliancePolicy -Identity $DlpPolicyName | Format-List Name, Mode, EnforcementPlanes, Locations
Get-DlpComplianceRule   -Identity $DlpRuleName   | Format-List Name, Policy, RestrictAccess, ReportSeverityLevel
