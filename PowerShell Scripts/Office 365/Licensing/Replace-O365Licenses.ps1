# Script: Replace-O365Licenses.ps1
# Purpose: Removes all directly assigned Microsoft 365 licenses for users in a CSV and assigns new license(s) defined in the script.
# Author: FakeIT (AI Assisted)
# Date: May 27, 2025
# Notes:
# - Designed for bulk license replacement or standardization scenarios.
# - Removes only direct license assignments — group-based licenses are unaffected.
# - Triggers reprocessing after assignment to refresh licensing state and clear errors.
# - Requires Microsoft.Graph module and admin permissions.
# - Input CSV must contain a 'UserPrincipalName' column.
# - To find available SKUs and their IDs, run:
#     Get-MgSubscribedSku | Select SkuPartNumber, SkuId

# Connect to Microsoft Graph
Write-Host ""
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# Specify license SKU(s) to assign after removal
$skuToAssign = @(
    "94763226-9b3c-4e75-a931-5c89701abe66"  # Example: STANDARDWOFFPACK_FACULTY (Microsoft 365 A1 Faculty)
)

# Path to input CSV
$csvPath = "C:\PS\replacelicenses.csv"
Write-Host ""
Write-Host "Processing users from: $csvPath" -ForegroundColor Yellow

# Process each user
Import-Csv $csvPath | ForEach-Object {
    $userId = $_.UserPrincipalName
    Write-Host ""
    Write-Host "Processing $userId..." -ForegroundColor White

    try {
        # Get current assigned licenses (direct)
        $user = Get-MgUser -UserId $userId -Property AssignedLicenses
        $currentSkus = $user.AssignedLicenses.SkuId

        # Build license update body
        $licenseUpdate = @{
            RemoveLicenses = $currentSkus
            AddLicenses    = @($skuToAssign | ForEach-Object { @{ SkuId = $_ } })
        }

        # Apply license update
        Set-MgUserLicense -UserId $userId -BodyParameter $licenseUpdate
        Write-Host "   Replaced direct licenses with: $($skuToAssign -join ', ')" -ForegroundColor Green

        # Reprocess license assignment
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users/$userId/reprocessLicenseAssignment"

        Write-Host "   License assignment reprocessed." -ForegroundColor Cyan
    }
    catch {
        Write-Host "   ERROR with $userId: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Green
Write-Host ""
