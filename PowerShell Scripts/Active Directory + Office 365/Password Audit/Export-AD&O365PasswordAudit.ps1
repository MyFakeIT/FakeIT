# Script: Export-AD&O365PasswordAudit.ps1
# Purpose: Exports a combined password audit report for AD and O365 users with inactivity probability.
# Author: FakeIT (AI Assisted)
# Date: April 03, 2025
# Requirements: ActiveDirectory and Microsoft.Graph.Users modules

# --- Connect to Microsoft Graph First ---
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Host "Microsoft.Graph module not found. Installing now..." -ForegroundColor Yellow
    try {
        Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "Microsoft.Graph module installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to install Microsoft.Graph module." -ForegroundColor Red
        exit
    }
}

try {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
    Write-Host "Microsoft Graph module loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to load Microsoft.Graph.Users module." -ForegroundColor Red
    exit
}

# Connect to Microsoft Graph with retry logic
$maxRetries = 3
$retryCount = 0
$connected = $false

while (-not $connected -and $retryCount -lt $maxRetries) {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "Attempting to connect to Microsoft Graph (Attempt $($retryCount + 1) of $maxRetries)..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes "User.Read.All", "AuditLog.Read.All" -NoWelcome -ErrorAction Stop
        Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
        $connected = $true
    } catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "Failed to connect: $_. Retrying in 30 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
        } else {
            Write-Host "Error: Failed to connect to Microsoft Graph after $maxRetries attempts. Details: $_" -ForegroundColor Red
            exit
        }
    }
}

if (-not $connected) { exit }

# --- AD Section ---
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Active Directory module loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to load ActiveDirectory module. Ensure RSAT is installed." -ForegroundColor Red
    exit
}

# Query AD users
Write-Host "Fetching AD user data..." -ForegroundColor Cyan
$adUsers = Get-ADUser -Filter * `
    -Properties PasswordLastSet, pwdLastSet, UserPrincipalName, Mail, Enabled, LastLogonDate, LastLogonTimestamp, LogonCount, BadPwdCount, Created, PasswordNeverExpires, AccountExpires, LockedOut, SamAccountName, whenChanged |
    Select-Object `
        @{Name = 'AD_UserPrincipalName'; Expression = {$_.UserPrincipalName}},
        @{Name = 'AD_SamAccountName'; Expression = {$_.SamAccountName}},
        @{Name = 'AD_Mail'; Expression = {$_.Mail}},
        @{Name = 'AD_PasswordLastSet'; Expression = {$_.PasswordLastSet}},
        @{Name = 'AD_pwdLastSet'; Expression = {$_.pwdLastSet}},
        @{Name = 'AD_PasswordAgeDays'; Expression = {
            if ($_.PasswordLastSet) { (New-TimeSpan -Start $_.PasswordLastSet -End (Get-Date)).Days } else { 'N/A' }
        }},
        @{Name = 'AD_PasswordNeverExpires'; Expression = {$_.PasswordNeverExpires}},
        @{Name = 'AD_Enabled'; Expression = {$_.Enabled}},
        @{Name = 'AD_LastLogonDate'; Expression = {$_.LastLogonDate}},
        @{Name = 'AD_LastLogonTimestamp'; Expression = {$_.LastLogonTimestamp}},
        @{Name = 'AD_LogonCount'; Expression = {$_.LogonCount}},
        @{Name = 'AD_BadPwdCount'; Expression = {$_.BadPwdCount}},
        @{Name = 'AD_Created'; Expression = {$_.Created}},
        @{Name = 'AD_AccountExpires'; Expression = {$_.AccountExpires}},
        @{Name = 'AD_LockedOut'; Expression = {$_.LockedOut}},
        @{Name = 'AD_whenChanged'; Expression = {$_.whenChanged}}
Write-Host "AD user data retrieved successfully." -ForegroundColor Green

# --- O365 Section ---
Write-Host "Fetching O365 user data..." -ForegroundColor Cyan
$o365Users = Get-MgUser -All -Property DisplayName, UserPrincipalName, Mail, AccountEnabled, PasswordPolicies, LastPasswordChangeDateTime, CreatedDateTime, SignInActivity |
    Select-Object `
        @{Name = 'O365_UserPrincipalName'; Expression = {$_.UserPrincipalName}},
        @{Name = 'O365_DisplayName'; Expression = {$_.DisplayName}},
        @{Name = 'O365_Mail'; Expression = {$_.Mail}},
        @{Name = 'O365_AccountEnabled'; Expression = {$_.AccountEnabled}},
        @{Name = 'O365_PasswordLastChanged'; Expression = {$_.LastPasswordChangeDateTime}},
        @{Name = 'O365_PasswordAgeDays'; Expression = {
            if ($_.LastPasswordChangeDateTime) { (New-TimeSpan -Start $_.LastPasswordChangeDateTime -End (Get-Date)).Days } else { 'N/A' }
        }},
        @{Name = 'O365_PasswordPolicies'; Expression = {$_.PasswordPolicies}},
        @{Name = 'O365_Created'; Expression = {$_.CreatedDateTime}},
        @{Name = 'O365_LastSignIn'; Expression = {$_.SignInActivity.LastSignInDateTime}},
        @{Name = 'O365_LastNonInteractiveSignIn'; Expression = {$_.SignInActivity.LastNonInteractiveSignInDateTime}}
Write-Host "O365 user data retrieved successfully." -ForegroundColor Green

# --- Optimize Merge with Hashtable ---
Write-Host "Building O365 hashtable for faster lookup..." -ForegroundColor Cyan
$o365Hash = @{}
foreach ($user in $o365Users) { $o365Hash[$user.O365_UserPrincipalName] = $user }
Write-Host "Hashtable built successfully." -ForegroundColor Green

Write-Host "Merging AD and O365 data..." -ForegroundColor Cyan
$combinedData = $adUsers | ForEach-Object {
    $adUser = $_
    # Skip if AD_UserPrincipalName is null
    if ($null -eq $adUser.AD_UserPrincipalName) {
        Write-Host "Skipping AD user with null UserPrincipalName: $($adUser.AD_SamAccountName)" -ForegroundColor Yellow
        return
    }
    $matchingO365User = $o365Hash[$adUser.AD_UserPrincipalName]
    if ($matchingO365User) {
        # Calculate Inactivity Probability Score
        $score = 0
        $ninetyDaysAgo = (Get-Date).AddDays(-90)

        # Immediate 100 if disabled in either system
        if (-not $adUser.AD_Enabled -or -not $matchingO365User.O365_AccountEnabled) {
            $score = 100
        } else {
            # Score for enabled accounts based on logon activity
            if ($null -eq $adUser.AD_LastLogonTimestamp -or $adUser.AD_LastLogonTimestamp -lt $ninetyDaysAgo) { $score += 50 }
            if ($null -eq $matchingO365User.O365_LastSignIn -or $matchingO365User.O365_LastSignIn -lt $ninetyDaysAgo) { $score += 50 }

            # Adjustments for recent activity
            if ($matchingO365User.O365_LastSignIn -gt $ninetyDaysAgo -or $matchingO365User.O365_LastNonInteractiveSignIn -gt $ninetyDaysAgo) { $score -= 50 }
            if ($adUser.AD_whenChanged -gt $ninetyDaysAgo) { $score -= 20 }

            # Ensure score stays between 0 and 100
            $score = [Math]::Max(0, [Math]::Min(100, $score))
        }

        [PSCustomObject]@{
            'AD_UserPrincipalName'          = $adUser.AD_UserPrincipalName
            'AD_SamAccountName'             = $adUser.AD_SamAccountName
            'AD_Mail'                       = $adUser.AD_Mail
            'AD_PasswordLastSet'            = $adUser.AD_PasswordLastSet
            'AD_pwdLastSet'                 = $adUser.AD_pwdLastSet
            'AD_PasswordAgeDays'            = $adUser.AD_PasswordAgeDays
            'AD_PasswordNeverExpires'       = $adUser.AD_PasswordNeverExpires
            'AD_Enabled'                    = $adUser.AD_Enabled
            'AD_LastLogonDate'              = $adUser.AD_LastLogonDate
            'AD_LastLogonTimestamp'         = $adUser.AD_LastLogonTimestamp
            'AD_LogonCount'                 = $adUser.AD_LogonCount
            'AD_BadPwdCount'                = $adUser.AD_BadPwdCount
            'AD_Created'                    = $adUser.AD_Created
            'AD_AccountExpires'             = $adUser.AD_AccountExpires
            'AD_LockedOut'                  = $adUser.AD_LockedOut
            'AD_whenChanged'                = $adUser.AD_whenChanged
            'O365_DisplayName'              = $matchingO365User.O365_DisplayName
            'O365_Mail'                     = $matchingO365User.O365_Mail
            'O365_AccountEnabled'           = $matchingO365User.O365_AccountEnabled
            'O365_PasswordLastChanged'      = $matchingO365User.O365_PasswordLastChanged
            'O365_PasswordAgeDays'          = $matchingO365User.O365_PasswordAgeDays
            'O365_PasswordPolicies'         = $matchingO365User.O365_PasswordPolicies
            'O365_Created'                  = $matchingO365User.O365_Created
            'O365_LastSignIn'               = $matchingO365User.O365_LastSignIn
            'O365_LastNonInteractiveSignIn' = $matchingO365User.O365_LastNonInteractiveSignIn
            'InactivityProbabilityScore'    = $score
        }
    }
}
Write-Host "Data merged successfully." -ForegroundColor Green

# --- Export to CSV ---
$outputDir = "C:\PS"
$currentDate = Get-Date -Format "yyyy-MM-dd"
$filePath = "$outputDir\AD&O365PasswordAudit-$currentDate.csv"

if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if ($combinedData) {
    $combinedData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    Write-Host "Hybrid password audit data exported to: $filePath" -ForegroundColor Green
} else {
    Write-Host "Warning: No matching user data found between AD and O365." -ForegroundColor Yellow
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green
