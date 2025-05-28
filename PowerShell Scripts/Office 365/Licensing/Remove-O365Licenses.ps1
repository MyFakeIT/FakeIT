# Script: Remove-O365Licenses.ps1
# Purpose: Removes directly assigned Microsoft 365 licenses by SKU and reprocesses group-based license assignments per user.
# Author: FakeIT (AI Assisted)
# Date: May 27, 2025
# Notes:
# - Removes licenses only for users listed in the input CSV.
# - Only direct (user-level) license assignments are removed; group-based license assignments are not affected or removed.
# - After removal, the script reprocesses group license assignments to resolve any licensing conflicts or errors.
# - To find SKU IDs for Microsoft 365 licenses, run:
#     Get-MgSubscribedSku | Select SkuPartNumber, SkuId
# - CSV input must contain a column: 'UserPrincipalName'
# - Requires Microsoft.Graph module and appropriate admin permissions.

# Connect to Microsoft Graph
Write-Host ""
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# Default: Microsoft 365 A1 Student SKUs
# You may replace these with other SKU IDs as needed
$skuToRemove = @(
    "314c4481-f395-4525-be8b-2ec4bb1e9d91",  # STANDARDWOFFPACK_STUDENT
    "e82ae690-a2d5-4d76-8d30-7c6e01e6022e"   # STANDARDWOFFPACK_IW_STUDENT
)

# Path to the input CSV file
$csvPath = "C:\PS\removelicenses.csv"
Write-Host ""
Write-Host "Processing users from: $csvPath" -ForegroundColor Yellow

# Process each user
Import-Csv $csvPath | ForEach-Object {
    $userId = $_.UserPrincipalName
    Write-Host ""
    Write-Host "Processing $userId..." -ForegroundColor White

    try {
        # Get license details
        $licenseDetails = Get-MgUserLicenseDetail -UserId $userId
        $matchedSkus = $licenseDetails | Where-Object { $skuToRemove -contains $_.SkuId }

        if ($matchedSkus) {
            $removal = @{
                AddLicenses    = @()
                RemoveLicenses = $matchedSkus.SkuId
            }

            Set-MgUserLicense -UserId $userId -BodyParameter $removal
            Write-Host "   Removed directly assigned license(s): $($matchedSkus.SkuId -join ', ')" -ForegroundColor Green
        }
        else {
            Write-Host "   No matching directly assigned license(s) found." -ForegroundColor DarkYellow
        }

        # Reprocess license assignments to refresh group-based licenses (if any)
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users/$userId/reprocessLicenseAssignment"

        Write-Host "   Triggered license reprocessing for $userId." -ForegroundColor Cyan
    }
    catch {
        Write-Host "   ERROR with $($userId): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Green
Write-Host ""
