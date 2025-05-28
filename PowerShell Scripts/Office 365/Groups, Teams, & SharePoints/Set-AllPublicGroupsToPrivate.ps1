# Script: Set-AllPublicGroupsToPrivate.ps1
# Purpose: Changes all Public Microsoft 365 Groups to Private in an Office 365 tenant.
# Author: FakeIT (AI Assisted)
# Date: March 06, 2025
# Notes: 
# - Requires ExchangeOnlineManagement module (Install-Module -Name ExchangeOnlineManagement).
# - Must run with Exchange Admin or Global Admin permissions.
# - Sets groups to Private, allowing self-joining requests with owner approval (SubscriptionEnabled unchanged).
# - Does not affect sharing settings or SharePoint site permissions.

# Connect to Exchange Online service to manage Microsoft 365 Groups
# This establishes a session with Exchange Online using modern authentication
Connect-ExchangeOnline

# Retrieve all Public Microsoft 365 Groups and prepare to switch them to Private
# -ResultSize Unlimited ensures all groups are fetched, bypassing default limits (e.g., 1000)
Write-Host "Identifying and switching all Public groups to Private..."
$publicGroups = Get-UnifiedGroup -ResultSize Unlimited | 
    Where-Object { $_.AccessType -eq "Public" }

# Check if any Public groups were found in the tenant
# If $publicGroups is not empty, proceed with changes; otherwise, notify and exit
if ($publicGroups) {
    # Display the total number of Public groups found for user feedback
    Write-Host "Found $($publicGroups.Count) Public groups. Switching to Private..."
    
    # Iterate through each Public group to apply the Private setting
    foreach ($group in $publicGroups) {
        # Set the group to Private using its unique Identity
        # -AccessType Private restricts visibility and access to members only
        # Self-joining requests are still allowed (if SubscriptionEnabled is $true), requiring owner approval
        Set-UnifiedGroup -Identity $group.Identity -AccessType Private
        
        # Confirm each change with the group's display name for logging/visibility
        Write-Host "Changed $($group.DisplayName) to Private"
    }
    
    # Notify completion of the operation
    Write-Host "All Public groups switched to Private."
} else {
    # If no Public groups exist, inform the user to avoid confusion
    Write-Host "No Public groups found in the tenant."
}

# Disconnect from Exchange Online session
# -Confirm:$false skips the confirmation prompt for a clean exit
Disconnect-ExchangeOnline -Confirm:$false
