# Script: Reprocess-AllO365Licenses.ps1
# Purpose: Triggers license reprocessing for all users in Microsoft 365 to resolve license assignment errors.
# Author: FakeIT (AI Assisted)
# Date: May 27, 2025
# Notes:
# - Useful for clearing licensing errors across the tenant after making changes to individual or group licenses.
# - Does not assign or remove licenses, only re-evaluates them for each user.
# - Requires Microsoft.Graph module and appropriate permissions.
# - Use cautiously in large environments — may take time to process all users.

# Connect to Microsoft Graph
Write-Host ""
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# Retrieve all users
Write-Host ""
Write-Host "Retrieving all users from Microsoft 365..." -ForegroundColor Yellow
$users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName

Write-Host ""
Write-Host "Total users found: $($users.Count)" -ForegroundColor Cyan

# Reprocess license assignments for each user
foreach ($user in $users) {
    Write-Host ""
    Write-Host "Reprocessing licenses for $($user.DisplayName) <$($user.UserPrincipalName)>..." -ForegroundColor White

    try {
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/reprocessLicenseAssignment"

        Write-Host "   License reprocessing triggered successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "License reprocessing completed for all users." -ForegroundColor Green
Write-Host ""
