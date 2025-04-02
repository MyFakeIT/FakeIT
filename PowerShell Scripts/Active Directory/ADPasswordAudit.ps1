<#
.SYNOPSIS
    Exports a detailed password audit report for Active Directory users to a CSV file.
.DESCRIPTION
    Retrieves key user account attributes from Active Directory related to password management,
    account status, and activity. Outputs the data to a CSV file with a dynamic date in the filename.
    Intended for auditing password policy compliance and identifying potential security risks.
.NOTES
    Author: FakeIT
    Date: April 2, 2025
    Requires: ActiveDirectory module, appropriate AD permissions (e.g., Domain Admin)
.EXAMPLE
    .\ADPasswordAudit.ps1
    Generates a CSV file like "C:\PS\ADPasswordAudit-2025-04-02.csv" with user audit data.
#>

# Ensure the ActiveDirectory module is available
Import-Module ActiveDirectory -ErrorAction Stop

# Define the output directory and dynamic file name
$outputDir = "C:\PS"
$currentDate = Get-Date -Format "yyyy-MM-dd"  # Format date as YYYY-MM-DD (e.g., 2025-04-02)
$filePath = "$outputDir\ADPasswordAudit-$currentDate.csv"

# Create the output directory if it doesn't exist
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Retrieve AD user data with specific properties for the password audit
Get-ADUser -Filter * `
    -Properties PasswordLastSet, UserPrincipalName, Mail, PasswordExpired, Enabled, `
                LastLogonDate, Created, PasswordNeverExpires, AccountExpires, BadPwdCount, LockedOut `
    | Select-Object -Property `
        # User identification fields
        Name,                                    # Display name of the user
        UserPrincipalName,                       # Unique UPN (e.g., user@domain.com)
        Mail,                                    # Email address of the user
        # Password-related fields
        @{Name = 'PasswordLastSet'; Expression = {$_.PasswordLastSet}},          # Date password was last changed
        @{Name = 'PasswordExpired'; Expression = {$_.PasswordExpired}},          # True if password has expired
        @{Name = 'PasswordNeverExpires'; Expression = {$_.PasswordNeverExpires}},# True if password is set to never expire
        # Account status fields
        @{Name = 'AccountEnabled'; Expression = {$_.Enabled}},                   # True if account is active
        @{Name = 'AccountExpirationDate'; Expression = {$_.AccountExpires}},     # Date account expires (if set)
        @{Name = 'AccountLockedOut'; Expression = {$_.LockedOut}},               # True if account is locked out
        # Activity and security fields
        @{Name = 'LastLogonDate'; Expression = {$_.LastLogonDate}},              # Last replicated logon date
        @{Name = 'AccountCreated'; Expression = {$_.Created}},                   # Date account was created
        @{Name = 'BadPasswordAttempts'; Expression = {$_.BadPwdCount}}           # Number of bad password attempts
    | Export-Csv -Path $filePath -NoTypeInformation  # Export to CSV without extra metadata

# Output confirmation to the console
Write-Host "Password audit data exported to: $filePath"
