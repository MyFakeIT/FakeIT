# Script: Export-PublicGroupsToCSV.ps1
# Purpose: Identifies all Public Microsoft 365 Groups in an Office 365 tenant and exports them to a CSV file.
# Author: FakeIT (AI Assisted)
# Date: March 06, 2025
# Notes:
# - Requires ExchangeOnlineManagement module (Install-Module -Name ExchangeOnlineManagement).
# - Must run with Exchange Admin or Global Admin permissions.
# - Saves to Desktop as PublicGroups.csv for easy access and later use.
# - Includes group details for tracking and modification purposes.

# Connect to Exchange Online service to manage Microsoft 365 Groups
# Uses modern authentication to establish the session
Connect-ExchangeOnline

# Retrieve all Public Microsoft 365 Groups and prepare for export
# -ResultSize Unlimited ensures all groups are fetched, bypassing default limits (e.g., 1000)
Write-Host "Identifying all Public groups..."
$publicGroups = Get-UnifiedGroup -ResultSize Unlimited | 
    Where-Object { $_.AccessType -eq "Public" } | 
    Select-Object DisplayName, PrimarySmtpAddress, AccessType, Identity

# Check if any Public groups were found in the tenant
# If $publicGroups has data, export to CSV; otherwise, notify the user
if ($publicGroups) {
    # Define the CSV save path on the user's Desktop for consistency
    $csvPath = "$env:USERPROFILE\Desktop\PublicGroups.csv"
    
    # Export group details to CSV without type info for cleaner output
    # Columns: DisplayName, PrimarySmtpAddress, AccessType, Identity
    $publicGroups | Export-Csv -Path $csvPath -NoTypeInformation
    
    # Provide feedback with count and file location
    Write-Host "Found $($publicGroups.Count) Public groups. Details saved to $csvPath"
    
    # Optional: Display a sample of the first 5 groups for verification
    Write-Host "Sample of groups found:"
    $publicGroups | Select-Object -First 5 | Format-Table -AutoSize
} else {
    # Inform the user if no Public groups exist to avoid confusion
    Write-Host "No Public groups found in the tenant."
}

# Disconnect from Exchange Online session
# -Confirm:$false skips the confirmation prompt for a smooth exit
Disconnect-ExchangeOnline -Confirm:$false
