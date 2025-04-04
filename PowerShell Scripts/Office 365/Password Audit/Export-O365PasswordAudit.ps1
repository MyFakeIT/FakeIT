# Script: Export-O365PasswordAudit.ps1
# Purpose: Exports a password audit report for Office 365 users to a CSV file.
# Author: FakeIT (AI Assisted)
# Date: April 03, 2025

# Check if Microsoft.Graph module is installed; install if not
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Host "Microsoft.Graph module not found. Installing now..." -ForegroundColor Yellow
    try {
        Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "Microsoft.Graph module installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to install Microsoft.Graph module. Ensure you have internet access and proper permissions." -ForegroundColor Red
        exit
    }
}

# Import the Microsoft Graph Users module
try {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Write-Host "Microsoft Graph module loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to load Microsoft.Graph.Users module." -ForegroundColor Red
    exit
}

# Connect to Microsoft Graph with required scopes
try {
    Connect-MgGraph -Scopes "User.Read.All", "AuditLog.Read.All" -ErrorAction Stop
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to connect to Microsoft Graph. Ensure proper permissions." -ForegroundColor Red
    exit
}

# Define the output directory and file path using current date
$outputDir = "C:\PS"
$currentDate = Get-Date -Format "yyyy-MM-dd"
$filePath = "$outputDir\O365PasswordAudit-$currentDate.csv"

# Create the output directory if it doesn’t exist
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Get all users from Azure AD with relevant properties
$users = Get-MgUser -All -Property DisplayName, UserPrincipalName, Mail, AccountEnabled, PasswordPolicies, LastPasswordChangeDateTime, CreatedDateTime, SignInActivity

# Process the users and select audit-relevant properties
$auditData = $users | Select-Object -Property `
    @{Name = 'DisplayName'; Expression = {$_.DisplayName}},
    @{Name = 'UserPrincipalName'; Expression = {$_.UserPrincipalName}},
    @{Name = 'Mail'; Expression = {$_.Mail}},
    @{Name = 'AccountEnabled'; Expression = {$_.AccountEnabled}},
    @{Name = 'PasswordLastChanged'; Expression = {$_.LastPasswordChangeDateTime}},
    @{Name = 'PasswordAgeDays'; Expression = {
        if ($_.LastPasswordChangeDateTime) {
            (New-TimeSpan -Start $_.LastPasswordChangeDateTime -End (Get-Date)).Days
        } else {
            'N/A'
        }
    }},
    @{Name = 'PasswordPolicies'; Expression = {$_.PasswordPolicies}},
    @{Name = 'AccountCreated'; Expression = {$_.CreatedDateTime}},
    @{Name = 'LastSignIn'; Expression = {$_.SignInActivity.LastSignInDateTime}}

# Export the results to CSV
if ($auditData) {
    $auditData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    Write-Host "Password audit data exported to: $filePath" -ForegroundColor Green
} else {
    Write-Host "Warning: No user data retrieved from Azure AD. Check your permissions or connectivity." -ForegroundColor Yellow
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green
