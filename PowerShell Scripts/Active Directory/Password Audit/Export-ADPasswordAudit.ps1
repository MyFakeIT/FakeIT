# Script: Export-ADPasswordAudit.ps1
# Purpose: Exports a detailed password audit report for Active Directory users to a CSV file.
# Author: FakeIT (AI Assisted)
# Date: April 02, 2025
# Notes:
# - Requires ActiveDirectory module (available on systems with RSAT or AD PowerShell).
# - Must run with sufficient AD permissions (e.g., Domain Admin or equivalent).
# - Saves to C:\PS with a dynamic date (e.g., ADPasswordAudit-2025-04-02.csv).
# - Includes password policy/status and activity details for security auditing.

# Import the ActiveDirectory module to query AD user data


try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Host "Error: Failed to load ActiveDirectory module. Ensure RSAT is installed and you have appropriate permissions." -ForegroundColor Red
    exit
}

# Define the output directory and file path using current date
$outputDir = "C:\PS"
$currentDate = Get-Date -Format "yyyy-MM-dd"
$filePath = "$outputDir\ADPasswordAudit-$currentDate.csv"

# Create the output directory if it doesn't already exist
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Get the domain's password policy to calculate password expiration
$domainPolicy = Get-ADDefaultDomainPasswordPolicy
$maxPasswordAge = $domainPolicy.MaxPasswordAge


# Query all AD users and select relevant properties for auditing
$users = Get-ADUser -Filter * `
    -Properties PasswordLastSet, pwdLastSet, UserPrincipalName, Mail, Enabled, `
                LastLogonDate, Created, PasswordNeverExpires, AccountExpires, BadPwdCount, LockedOut, SamAccountName, whenChanged |
    Select-Object -Property `
        'Name',
        'SamAccountName',
        'UserPrincipalName',
        'Mail',


# Password Details
        @{Name = 'PasswordLastSet'; Expression = {$_.PasswordLastSet}},
        @{Name = 'PasswordAgeDays'; Expression = {
            if ($_.PasswordLastSet) {
                (New-TimeSpan -Start $_.PasswordLastSet -End (Get-Date)).Days
            } else {
                'N/A'
            }
        }},
        @{Name = 'ChangePasswordAtLogon'; Expression = {$_.pwdLastSet -eq 0}},
        @{Name = 'PasswordExpired'; Expression = {
            if ($_.PasswordLastSet -ne $null -and $_.PasswordNeverExpires -ne $true) {
                ($_.PasswordLastSet + $maxPasswordAge) -lt (Get-Date)
            } else {
                $false
            }
        }},
        @{Name = 'PasswordNeverExpires'; Expression = {$_.PasswordNeverExpires}},
        @{Name = 'BadPasswordAttempts'; Expression = {$_.BadPwdCount}},
        @{Name = 'AccountEnabled'; Expression = {$_.Enabled}},
        @{Name = 'AccountLockedOut'; Expression = {$_.LockedOut}},
        @{Name = 'AccountExpirationDate'; Expression = {$_.AccountExpires}},
        @{Name = 'LastLogonDate'; Expression = {$_.LastLogonDate}},
        @{Name = 'AccountCreated'; Expression = {$_.Created}},
        @{Name = 'LastModified'; Expression = {$_.whenChanged}}


# Export results to CSV file if users are returned
if ($users) {
# Export the data to CSV with UTF-8 encoding
    $users | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
    Write-Host "Password audit data exported to: $filePath" -ForegroundColor Green
} else {
# Display warning if no users were retrieved
    Write-Host "Warning: No user data retrieved from Active Directory. Check your permissions or AD connectivity." -ForegroundColor Yellow
}
