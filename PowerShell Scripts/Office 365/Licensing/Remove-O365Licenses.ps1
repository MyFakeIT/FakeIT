# Script: Remove-O365Licenses.ps1
# Purpose: Removes directly assigned Microsoft 365 licenses by SKU and reprocesses group-based license assignments.
# Author: FakeIT (AI Assisted)
# Date: May 27, 2025
# Notes:
# - Designed to remove any Microsoft 365 license(s) based on SKU ID(s).
# - Default behavior targets Microsoft 365 A1 Student licenses (STANDARDWOFFPACK_STUDENT and IW variant).
# - Reprocesses group licensing for each user to correct license state.
# - Must run with appropriate Microsoft Graph permissions (User Administrator or Global Admin).
# - Input CSV must contain a column: 'UserPrincipalName'.
# - To find available licenses and their SKU IDs, run:
#     Get-MgSubscribedSku | Select SkuPartNumber, SkuId

# Connect to Microsoft Graph
Write-Host ""
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# Default: Microsoft 365 A1 Student SKUs
# Modify this array to target other license SKUs
$skuToRemove = @(
    "314c4481-f395-4525-be8b-2ec4bb1e9d91",  # STANDARDWOFFPACK_STUDENT
    "e82ae690-a2d5-4d76-8d30-7c6e01e6022e"   # STANDARDWOFFPACK_IW_STUDENT
)

# Path to the input CSV file
$csvPath = "C:\PS\removelicenses.csv"
Write-Host ""
Write-Host "Processing users from: $csvPath" -ForegroundColor Yellow

# Process each user in the CSV
Import-Csv $csvPath | ForEach-Object {
    $userId = $_.UserPrincipalName
    Write-Host ""
    Write-Host "Processing $userId..." -ForegroundColor White

    try {
        # Get user's current license assignments
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
            Write-Host "   No matching directly assigned license(s) found to remove." -ForegroundColor DarkYellow
        }

        # Reprocess license assignments to apply group-based changes
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users/$userId/reprocessLicenseAssignment"

        Write-Host "   Group license assignment reprocessed." -ForegroundColor Cyan
    }
    catch {
        Write-Host "   ERROR with $($userId): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Green
Write-Host ""
