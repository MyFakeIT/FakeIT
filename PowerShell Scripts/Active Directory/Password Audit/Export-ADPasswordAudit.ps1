# Script: Export-ADPasswordAudit.ps1
# Purpose: Exports a detailed password audit report for Active Directory users to a CSV file.
# Author: FakeIT (AI Assisted)
# Date: April 02, 2025
# Notes:
# - Requires ActiveDirectory module (available on systems with RSAT or AD PowerShell).
# - Must run with sufficient AD permissions (e.g., Domain Admin or equivalent).
# - Saves to C:\PS with a dynamic date (e.g., ADPasswordAudit-2025-04-02.csv).
# - Includes password, status, and activity details for security auditing.

# Import the ActiveDirectory module to query AD user data
Import-Module ActiveDirectory -ErrorAction Stop

# Set up the output file path with a dynamic date
$outputDir = "C:\PS"
$currentDate = Get-Date -Format "yyyy-MM-dd"  # Format as YYYY-MM-DD
$filePath = "$outputDir\ADPasswordAudit-$currentDate.csv"

# Create the output directory if it doesn’t exist
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Query AD users and select key properties for the password audit
Get-ADUser -Filter * `
    -Properties PasswordLastSet, UserPrincipalName, Mail, PasswordExpired, Enabled, `
                LastLogonDate, Created, PasswordNeverExpires, AccountExpires, BadPwdCount, LockedOut, SamAccountName `
    | Select-Object -Property `
        Name,                                    # User’s display name
        SamAccountName,                          # User’s SamAccount name
        UserPrincipalName,                       # Unique UPN
        Mail,                                    # Email address
        @{Name = 'PasswordLastSet'; Expression = {$_.PasswordLastSet}},          # Last password change
        @{Name = 'PasswordExpired'; Expression = {$_.PasswordExpired}},          # Password expiration status
        @{Name = 'PasswordNeverExpires'; Expression = {$_.PasswordNeverExpires}},# Password never expires flag
        @{Name = 'AccountEnabled'; Expression = {$_.Enabled}},                   # Account active status
        @{Name = 'AccountExpirationDate'; Expression = {$_.AccountExpires}},     # Account expiration date
        @{Name = 'AccountLockedOut'; Expression = {$_.LockedOut}},               # Account lockout status
        @{Name = 'LastLogonDate'; Expression = {$_.LastLogonDate}},              # Last logon date
        @{Name = 'AccountCreated'; Expression = {$_.Created}},                   # Account creation date
        @{Name = 'BadPasswordAttempts'; Expression = {$_.BadPwdCount}}           # Failed login attempts
    | Export-Csv -Path $filePath -NoTypeInformation  # Export to CSV without metadata

# Confirm export completion
Write-Host "Password audit data exported to: $filePath"
