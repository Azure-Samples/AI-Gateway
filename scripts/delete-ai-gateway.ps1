# Script steps for humans:
# 1. Call ARM to list every resource link that points at the Cognitive Service, then delete each link.
# 2. If those links point to other AI resources, chase them and delete their links too so nothing is left behind.
# 3. When DeleteApimEntities is on, remove the APIM API and backend that were created for this AI account.
# 4. Watch for APIM product links; for each one, first remove its subscriptions and then delete the product itself.
# 5. Return a summary so you can see which links, APIs/backends, products, and subscriptions were touched.
param(
    # [Parameter(Mandatory = $true)]
    [string]$Token = "<Bearer token>",
    [string]$AiServiceId="/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<ai-service-name>",

    [string]$ArmEndpoint = "https://management.azure.com",
    [string]$ApiVersion = "2016-09-01",
    [bool]$DeleteApimEntities = $true,
    [bool]$DeleteLegacy=$true
)

function Get-AuthorizationHeader {
    param(
        [string]$TokenValue
    )

    if ($TokenValue -match "^\s*Bearer\s+") {
        return $TokenValue.Trim()
    }

    return "Bearer $TokenValue".Trim()
}

function Normalize-ResourceId {
    param(
        [string]$Id
    )

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return $null
    }

    return $Id.TrimEnd('/')
}

function Get-AiAccountNameFromId {
    param(
        [string]$ResourceId
    )

    $normalized = Normalize-ResourceId -Id $ResourceId
    if (-not $normalized) {
        return $null
    }

    $segments = $normalized.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
    if (-not $segments) {
        return $null
    }

    $index = [Array]::IndexOf($segments, 'accounts')
    if ($index -ge 0 -and $segments.Length -gt ($index + 1)) {
        return $segments[$index + 1]
    }

    return $segments[$segments.Length - 1]
}

function Add-AiAccountCandidate {
    param(
        [string]$ResourceId
    )

    if (-not $script:AiAccountResourceIds) {
        $script:AiAccountResourceIds = [System.Collections.Generic.HashSet[string]]::new()
    }

    if ([string]::IsNullOrWhiteSpace($ResourceId)) {
        return
    }

    $normalized = Normalize-ResourceId -Id $ResourceId
    if (-not $normalized) {
        return
    }

    if ($normalized -match '/providers/Microsoft\.CognitiveServices/accounts/') {
        [void]$script:AiAccountResourceIds.Add($normalized)
    }
}

$script:ProductsToDelete = [System.Collections.Generic.HashSet[string]]::new()
$script:ApimServiceIds = [System.Collections.Generic.HashSet[string]]::new()

function Get-ApimServiceIdFromResourceId {
    param(
        [string]$ResourceId
    )

    $normalized = Normalize-ResourceId -Id $ResourceId
    if (-not $normalized) {
        return $null
    }

    $match = [regex]::Match($normalized, '(?i)^(.+?/providers/Microsoft\.ApiManagement/service/[^/]+)')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}
$headers = @{
    Authorization = Get-AuthorizationHeader -TokenValue $Token
}

$armBase = $ArmEndpoint.TrimEnd('/')
$normalizedAiServiceId = Normalize-ResourceId -Id $AiServiceId
$apimPreviewApiVersion = "2023-09-01-preview"
$apimProductApiVersion = "2024-05-01"

if (-not $normalizedAiServiceId) {
    throw "AiServiceId is required when running Delete-resource-association-legacy.ps1."
}

Add-AiAccountCandidate -ResourceId $normalizedAiServiceId

function Add-ProductForDeletion {
    param(
        [string]$ProductId
    )

    if (-not $DeleteApimEntities) {
        Write-Verbose "DeleteApimEntities disabled; ignoring product candidate $ProductId"
        return
    }

    if ([string]::IsNullOrWhiteSpace($ProductId)) {
        Write-Verbose "Product candidate is empty; skipping"
        return
    }

    Write-Host "Evaluating link target for APIM product deletion: $ProductId"
    $normalizedProductId = Normalize-ResourceId -Id $ProductId

    if (-not $normalizedProductId) {
        Write-Host "Unable to normalize product ID $ProductId"
        return
    }

    if ($normalizedProductId.IndexOf('/products/', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        Write-Host "Link target is not an APIM product: $normalizedProductId"
        return
    }

    $serviceId = Get-ApimServiceIdFromResourceId -ResourceId $normalizedProductId
    if (-not $serviceId) {
        Write-Host "Product $normalizedProductId does not map to an APIM service"
        return
    }

    if (-not $script:ApimServiceIds) {
        $script:ApimServiceIds = [System.Collections.Generic.HashSet[string]]::new()
    }

    [void]$script:ApimServiceIds.Add($serviceId)

    if ($script:ProductsToDelete.Contains($normalizedProductId)) {
        Write-Host "Product $normalizedProductId already queued for deletion"
        return
    }

    [void]$script:ProductsToDelete.Add($normalizedProductId)
    Write-Host "Queued APIM product for deletion: $normalizedProductId"
}

function New-DeleteHeaders {
    $copy = @{}
    foreach ($entry in $headers.GetEnumerator()) {
        $copy[$entry.Key] = $entry.Value
    }

    $copy['If-Match'] = '*'
    return $copy
}

function Get-HttpErrorDetail {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    if (-not $ErrorRecord) {
        return $null
    }

    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        return $ErrorRecord.ErrorDetails.Message.Trim()
    }

    $exception = $ErrorRecord.Exception
    if (-not $exception) {
        return $null
    }

    $responseProperty = $exception.PSObject.Properties["Response"]
    if (-not $responseProperty) {
        return $null
    }

    $response = $responseProperty.Value
    if (-not $response) {
        return $null
    }

    try {
        if ($response -is [System.Net.HttpWebResponse]) {
            $stream = $response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $content = $reader.ReadToEnd()
                $reader.Dispose()
                return $content.Trim()
            }
        }

        if ($response.PSObject.Properties["Content"]) {
            $content = $response.Content.ReadAsStringAsync().Result
            return $content.Trim()
        }
    } catch {
        return $null
    }

    return $null
}

function Remove-ResourceLinksForResource {
    param(
        [string]$ResourceId
    )

    if (-not $ResourceId) {
        Write-Verbose "No resource ID provided to Remove-ResourceLinksForResource"
        return @()
    }

    Add-AiAccountCandidate -ResourceId $ResourceId

    Write-Host "Retrieving links for ${ResourceId}"
    $resourceLinksUri = "$armBase$ResourceId/providers/Microsoft.Resources/links?api-version=$ApiVersion"

    try {
    Write-Host "GET $resourceLinksUri"
        $resourceLinks = Invoke-RestMethod -Method Get -Uri $resourceLinksUri -Headers $headers
    } catch {
    Write-Warning "Failed to retrieve links for ${ResourceId}: $($_.Exception.Message)"
        return @([pscustomobject]@{
                LinkId   = $null
                SourceId = $ResourceId
                TargetId = $ResourceId
                Status   = "Failed to retrieve links: $($_.Exception.Message)"
            })
    }

    $linksToProcess = @()

    if ($resourceLinks.value) {
        $linksToProcess = $resourceLinks.value
    } elseif ($resourceLinks.id) {
        $linksToProcess = @($resourceLinks)
    }

    $linksToProcess = @($linksToProcess) | Where-Object { $_ }
    $linkCount = ($linksToProcess | Measure-Object).Count

    Write-Host "Found $linkCount link(s) for ${ResourceId}"
    $deleteResults = @()

    foreach ($link in $linksToProcess) {
        if (-not $link.id) {
            Write-Warning "Skipping link without ID for $ResourceId"
            continue
        }

        $deleteUri = "$armBase$($link.id)?api-version=$ApiVersion"

        if ($link.properties.targetId) {
            Add-ProductForDeletion -ProductId $link.properties.targetId
            Add-AiAccountCandidate -ResourceId $link.properties.targetId
        }

        try {
            Write-Host "Deleting link $($link.id)"
            Invoke-RestMethod -Method Delete -Uri $deleteUri -Headers $headers -ErrorAction Stop
            $status = "Deleted"
        } catch {
            Write-Warning "Failed to delete link $($link.id): $($_.Exception.Message)"
            $status = "Failed: $($_.Exception.Message)"
        }

        $deleteResults += [pscustomobject]@{
            LinkId = $link.id
            SourceId = $link.properties.sourceId
            TargetId = $link.properties.targetId
            Status  = $status
        }
    }

    return $deleteResults
}

Write-Host "Discovering APIM services linked to $normalizedAiServiceId"
$aiDiscoveryUri = "$armBase$normalizedAiServiceId/providers/Microsoft.Resources/links?api-version=$ApiVersion"
$aiLinksResponse = $null

try {
    Write-Host "GET $aiDiscoveryUri"
    $aiLinksResponse = Invoke-RestMethod -Method Get -Uri $aiDiscoveryUri -Headers $headers -ErrorAction Stop
} catch {
    Write-Warning "Failed to retrieve discovery links for ${normalizedAiServiceId}: $($_.Exception.Message)"
}

$aiLinkedResources = @()
if ($aiLinksResponse) {
    if ($aiLinksResponse.value) {
        $aiLinkedResources = $aiLinksResponse.value
    } elseif ($aiLinksResponse.id) {
        $aiLinkedResources = @($aiLinksResponse)
    }
}

foreach ($link in $aiLinkedResources) {
    foreach ($candidate in @($link.properties.sourceId, $link.properties.targetId)) {
        if (-not $candidate) {
            continue
        }

        $serviceId = Get-ApimServiceIdFromResourceId -ResourceId $candidate
        if ($serviceId) {
            [void]$script:ApimServiceIds.Add($serviceId)
        }
    }
}

if ($script:ApimServiceIds.Count -gt 0) {
    Write-Host "Discovered APIM service scope(s): $($script:ApimServiceIds -join ', ')"
}

if ($DeleteApimEntities -and $script:ApimServiceIds.Count -eq 0) {
    Write-Warning "DeleteApimEntities requested but no APIM service link was found for $normalizedAiServiceId."
}

$apimDeleteResults = @()
$targetsForFollowUp = [System.Collections.Generic.HashSet[string]]::new()

foreach ($apimServiceId in $script:ApimServiceIds) {
    $apimLinksUri = "$armBase$apimServiceId/providers/Microsoft.Resources/links?api-version=$ApiVersion"

    $apimLinksResponse = $null
    try {
        Write-Host "Retrieving APIM links from $apimLinksUri"
        $apimLinksResponse = Invoke-RestMethod -Method Get -Uri $apimLinksUri -Headers $headers -ErrorAction Stop
    } catch {
        Write-Warning "Failed to retrieve resource links for ${apimServiceId}: $($_.Exception.Message)"
        continue
    }

    $apimLinks = @()
    if ($apimLinksResponse.value) {
        $apimLinks = $apimLinksResponse.value
    } elseif ($apimLinksResponse.id) {
        $apimLinks = @($apimLinksResponse)
    }

    $targetLinks = @()
    Write-Host "Filtering links targeting $normalizedAiServiceId on $apimServiceId"
    $targetLinks = $apimLinks | Where-Object { (Normalize-ResourceId -Id $_.properties.targetId) -eq $normalizedAiServiceId }

    $targetLinks = @($targetLinks) | Where-Object { $_ }
    $targetLinkCount = ($targetLinks | Measure-Object).Count

    Write-Host "Found $targetLinkCount link(s) to delete from APIM service $apimServiceId"

    foreach ($link in $targetLinks) {
        if (-not $link.id) {
            Write-Warning "Skipping APIM link without ID"
            continue
        }

        $deleteUri = "$armBase$($link.id)?api-version=$ApiVersion"

        if ($link.properties.targetId) {
            Add-ProductForDeletion -ProductId $link.properties.targetId
            Add-AiAccountCandidate -ResourceId $link.properties.targetId
        }

        $status = "Unknown"
        try {
            Write-Host "Deleting APIM link $($link.id)"
            Invoke-RestMethod -Method Delete -Uri $deleteUri -Headers $headers -ErrorAction Stop
            $status = "Deleted"
            if ($link.properties.targetId) {
                $normalizedTarget = Normalize-ResourceId -Id $link.properties.targetId
                if ($normalizedTarget) {
                    [void]$targetsForFollowUp.Add($normalizedTarget)
                    Add-AiAccountCandidate -ResourceId $normalizedTarget
                }
            }
        } catch {
            Write-Warning "Failed to delete APIM link $($link.id): $($_.Exception.Message)"
            $status = "Failed: $($_.Exception.Message)"
        }

        $apimDeleteResults += [pscustomobject]@{
            ApimServiceId = $apimServiceId
            LinkId        = $link.id
            SourceId      = $link.properties.sourceId
            TargetId      = $link.properties.targetId
            Status        = $status
        }
    }
}

if ($normalizedAiServiceId -and -not $targetsForFollowUp.Contains($normalizedAiServiceId)) {
    [void]$targetsForFollowUp.Add($normalizedAiServiceId)
}

$followUpResults = @()

foreach ($targetId in $targetsForFollowUp) {
    Write-Host "Processing follow-up deletions for $targetId"
    $followUpResults += [pscustomobject]@{
        AiServiceId = $targetId
        Deletions   = Remove-ResourceLinksForResource -ResourceId $targetId
    }
}

$apimEntityResults = @()

if ($DeleteApimEntities) {
    if (-not $script:AiAccountResourceIds) {
        $script:AiAccountResourceIds = [System.Collections.Generic.HashSet[string]]::new()
    }

    $aiAccountMap = @{}

    foreach ($aiResourceId in $script:AiAccountResourceIds) {
        $accountName = Get-AiAccountNameFromId -ResourceId $aiResourceId
        if ($accountName -and -not $aiAccountMap.ContainsKey($accountName)) {
            $aiAccountMap[$accountName] = $aiResourceId
        }
    }

    if ($aiAccountMap.Count -eq 0) {
        Write-Warning "DeleteApimEntities requested but no AI account name could be derived; skipping APIM entity deletion."
    } else {
        if (-not $script:ApimServiceIds -or $script:ApimServiceIds.Count -eq 0) {
            Write-Warning "DeleteApimEntities requested but no APIM service scope was discovered; skipping APIM entity deletion."
        }

        foreach ($apimServiceId in $script:ApimServiceIds) {
            foreach ($entry in $aiAccountMap.GetEnumerator()) {
                $aiAccountName = $entry.Key
                $sourceResourceId = $entry.Value

                $apimApiResourceId = "$apimServiceId/apis/$aiAccountName"
                $apimApiUri = "{0}{1}?api-version={2}" -f $armBase, $apimApiResourceId, $apimPreviewApiVersion
                Write-Host "Deleting APIM API $apimApiResourceId (derived from $sourceResourceId)"
                Write-Host "DELETE $apimApiUri"
                try {
                    Invoke-RestMethod -Method Delete -Uri $apimApiUri -Headers $headers -ErrorAction Stop
                    $apiStatus = "Deleted"
                } catch {
                    Write-Warning "Failed to delete APIM API ${apimApiResourceId}: $($_.Exception.Message)"
                    $apiStatus = "Failed: $($_.Exception.Message)"
                }

                $apimEntityResults += [pscustomobject]@{
                    Entity           = "Api"
                    ResourceId       = $apimApiResourceId
                    ApimServiceId    = $apimServiceId
                    SourceAiResource = $sourceResourceId
                    Status           = $apiStatus
                }

                $apimBackendResourceId = "$apimServiceId/backends/$aiAccountName"
                $apimBackendUri = "{0}{1}?api-version={2}" -f $armBase, $apimBackendResourceId, $apimPreviewApiVersion
                Write-Host "Deleting APIM backend $apimBackendResourceId (derived from $sourceResourceId)"
                Write-Host "DELETE $apimBackendUri"
                try {
                    Invoke-RestMethod -Method Delete -Uri $apimBackendUri -Headers $headers -ErrorAction Stop
                    $backendStatus = "Deleted"
                } catch {
                    Write-Warning "Failed to delete APIM backend ${apimBackendResourceId}: $($_.Exception.Message)"
                    $backendStatus = "Failed: $($_.Exception.Message)"
                }

                $apimEntityResults += [pscustomobject]@{
                    Entity           = "Backend"
                    ResourceId       = $apimBackendResourceId
                    ApimServiceId    = $apimServiceId
                    SourceAiResource = $sourceResourceId
                    Status           = $backendStatus
                }
            }
        }
    }
}

if ($DeleteApimEntities) {
    Write-Host "APIM products queued for deletion: $($script:ProductsToDelete.Count)"
}

$productDeletionResults = @()

if ($DeleteApimEntities -and $script:ProductsToDelete.Count -gt 0) {
    foreach ($productId in $script:ProductsToDelete) {
        Write-Host "Processing APIM product cleanup for $productId"

        $productServiceId = Get-ApimServiceIdFromResourceId -ResourceId $productId
        if (-not $productServiceId) {
            Write-Warning "Unable to determine APIM service scope for product ${productId}; skipping."
            continue
        }

        [void]$script:ApimServiceIds.Add($productServiceId)

        $subscriptionListStatus = "None"
        $subscriptionDeletionResults = @()
        $subscriptionsUri = "{0}{1}/subscriptions?api-version={2}" -f $armBase, $productId, $apimProductApiVersion
        $subscriptionsResponse = $null

        try {
            Write-Host "GET $subscriptionsUri"
            $subscriptionsResponse = Invoke-RestMethod -Method Get -Uri $subscriptionsUri -Headers $headers -ErrorAction Stop
            $subscriptionListStatus = "Retrieved"
        } catch {
            $detail = Get-HttpErrorDetail -ErrorRecord $_
            if ($detail) {
                Write-Warning "Failed to retrieve subscriptions for ${productId}: $($_.Exception.Message)`nResponse: $detail"
                $subscriptionListStatus = "Failed: $($_.Exception.Message) | $detail"
            } else {
                Write-Warning "Failed to retrieve subscriptions for ${productId}: $($_.Exception.Message)"
                $subscriptionListStatus = "Failed: $($_.Exception.Message)"
            }
        }

        $subscriptions = @()

        if ($subscriptionsResponse -and $subscriptionsResponse.value) {
            $subscriptions = $subscriptionsResponse.value
        }

        foreach ($subscription in $subscriptions) {
            if (-not $subscription.id) {
                continue
            }

            $subscriptionId = Normalize-ResourceId -Id $subscription.id
            if (-not $subscriptionId) {
                continue
            }

            $subscriptionName = if ($subscription.name) { $subscription.name } else { ($subscriptionId -split '/')[-1] }
            if (-not $subscriptionName) {
                Write-Warning "Unable to determine subscription name for $subscriptionId"
                continue
            }

            $subscriptionResourceId = "$productServiceId/subscriptions/$subscriptionName"
            $subscriptionDeleteUri = "{0}{1}?api-version={2}" -f $armBase, $subscriptionResourceId, $apimProductApiVersion
            Write-Host "Deleting APIM subscription $subscriptionResourceId (source: $subscriptionId)"
            Write-Host "DELETE $subscriptionDeleteUri"

            $deleteHeaders = New-DeleteHeaders

            try {
                Invoke-RestMethod -Method Delete -Uri $subscriptionDeleteUri -Headers $deleteHeaders -ErrorAction Stop
                $subscriptionStatus = "Deleted"
            } catch {
                $detail = Get-HttpErrorDetail -ErrorRecord $_
                if ($detail) {
                    Write-Warning "Failed to delete subscription ${subscriptionId}: $($_.Exception.Message)`nResponse: $detail"
                    $subscriptionStatus = "Failed: $($_.Exception.Message) | $detail"
                } else {
                    Write-Warning "Failed to delete subscription ${subscriptionId}: $($_.Exception.Message)"
                    $subscriptionStatus = "Failed: $($_.Exception.Message)"
                }
            }

            $subscriptionDeletionResults += [pscustomobject]@{
                SubscriptionId = $subscriptionResourceId
                SourceId       = $subscriptionId
                Status         = $subscriptionStatus
            }
        }

        $productDeleteHeaders = New-DeleteHeaders
        $productDeleteUri = "{0}{1}?api-version={2}" -f $armBase, $productId, $apimProductApiVersion
        Write-Host "Deleting APIM product $productId"
        Write-Host "DELETE $productDeleteUri"

        try {
            Invoke-RestMethod -Method Delete -Uri $productDeleteUri -Headers $productDeleteHeaders -ErrorAction Stop
            $productStatus = "Deleted"
        } catch {
            $detail = Get-HttpErrorDetail -ErrorRecord $_
            if ($detail) {
                Write-Warning "Failed to delete product ${productId}: $($_.Exception.Message)`nResponse: $detail"
                $productStatus = "Failed: $($_.Exception.Message) | $detail"
            } else {
                Write-Warning "Failed to delete product ${productId}: $($_.Exception.Message)"
                $productStatus = "Failed: $($_.Exception.Message)"
            }
        }

        $productDeletionResults += [pscustomobject]@{
            ProductId              = $productId
            ApimServiceId          = $productServiceId
            SubscriptionListStatus = $subscriptionListStatus
            SubscriptionDeletions  = $subscriptionDeletionResults
            ProductDeletionStatus  = $productStatus
        }
    }
}

return [pscustomobject]@{
    ApimLinkDeletion   = $apimDeleteResults
    TargetLinkDeletion = $followUpResults
    ApimEntitiesDeletion = $apimEntityResults
    ApimProductDeletion  = $productDeletionResults
}