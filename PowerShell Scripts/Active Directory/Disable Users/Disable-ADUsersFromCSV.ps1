# Script: Disable-ADUsersFromCSV.ps1
# Purpose: Disables AD accounts from a CSV, sets random passwords, and configures password policies.
# Author: FakeIT (AI Assisted)
# Date: April 02, 2025
# Notes:
# - Requires ActiveDirectory module.
# - CSV must have a 'Username' column; accepts SamAccountName (e.g., user1) or UserPrincipalName (e.g., user1@domain.com).
# - Default CSV path and file: C:\PS\ADUsersToDisable.csv
# - Must run with sufficient AD permissions (e.g., Domain Admin).
# - Random passwords include letters, numbers, mixed case, and symbols (!@#$%^&*).
# - Optional: Uncomment group addition or password expiration sections as needed.

# Import the ActiveDirectory module
Import-Module ActiveDirectory -ErrorAction Stop

# Define the CSV file path
$csvPath = "C:\PS\ADUsersToDisable.csv"

# Optional: Define an AD group to add users to (uncomment to use)
$groupName = "PW-Cleanup-2025"  #  Group to add users to

# Get the current domain name for UPN construction
$domain = (Get-ADDomain).DNSRoot  # e.g., "example.com"

# Function to generate a random password with a length between 12 and 15 characters
function New-RandomPassword {
    $minLength = 12
    $maxLength = 15
    $length = Get-Random -Minimum $minLength -Maximum ($maxLength + 1)  # Maximum is exclusive
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    $password = -join ((0..($length - 1)) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Validate the group if specified
if ($groupName) {
    try {
        $group = Get-ADGroup -Identity $groupName -ErrorAction Stop
        $groupDN = $group.DistinguishedName
        Write-Host "Group found: $groupDN"
    } catch {
        Write-Error "Group '$groupName' not found or inaccessible. Aborting group addition."
        $groupDN = $null
    }
}

# Read the CSV and process each user
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    # Ensure the CSV has a valid Username column
    if (-not $user.Username) {
        Write-Warning "Missing 'Username' in one of the CSV rows. Skipping..."
        continue
    }

    $inputName = $user.Username
    
    # Determine if the input includes a domain; if not, append the current domain for UPN construction
    if ($inputName -notmatch "@") {
        $upn = "$inputName@$domain"  # e.g., user1 -> user1@example.com
        $lookupName = $inputName     # Use as SamAccountName (e.g., user1)
    } else {
        $upn = $inputName            # e.g., user1@example.com
        $lookupName = ($inputName -split "@")[0]  # Extract SamAccountName (e.g., user1)
    }
    
    # Escape single quotes in both UPN and SamAccountName for the filter
    $upnEscaped = $upn -replace "'", "''"  
    $lookupNameEscaped = $lookupName -replace "'", "''"  
    
    try {
        # Try to get the AD user by UPN first, then fall back to SamAccountName
        $adUser = Get-ADUser -Filter "UserPrincipalName -eq '$upnEscaped'" -ErrorAction SilentlyContinue
        if (-not $adUser) {
            $adUser = Get-ADUser -Filter "SamAccountName -eq '$lookupNameEscaped'" -ErrorAction SilentlyContinue
        }
        
        if ($adUser) {
            # Use the AD user's UPN for display (if available)
            $displayName = $adUser.UserPrincipalName
            if (-not $displayName) {
                $displayName = $adUser.SamAccountName
            }

            # Generate a random password (length between 12 and 15 characters)
            $newPassword = New-RandomPassword
            $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force
            
            # Disable the account
            Disable-ADAccount -Identity $adUser -ErrorAction Stop
            Write-Host "Disabled account: $displayName"
            
            # Set the new random password
            Set-ADAccountPassword -Identity $adUser -NewPassword $securePassword -Reset -ErrorAction Stop
            Write-Host "Set random password for: $displayName"
            
            # Uncheck "Password never expires" and enforce "User must change password at next logon"
            try {
                Set-ADUser -Identity $adUser `
                           -PasswordNeverExpires $false `
                           -ChangePasswordAtLogon $true `
                           -ErrorAction Stop
                
                # Verify the "User must change password at next logon" setting
                $updatedUser = Get-ADUser -Identity $adUser -Properties pwdLastSet -ErrorAction Stop
                if ($updatedUser.pwdLastSet -eq 0) {
                    Write-Host "Confirmed: 'User must change password at next logon' is set for $displayName"
                } else {
                    Write-Warning "'User must change password at next logon' NOT set for $displayName (pwdLastSet: $($updatedUser.pwdLastSet))"
                }
            } catch {
                Write-Error "Failed to set password policies for $displayName : $_"
                continue
            }
            
            Write-Host "Configured password policies for: $displayName (Password: $newPassword)"
            
            # Optional: Force password to expire immediately (uncomment to enable)
            # Set-ADUser -Identity $adUser -Replace @{pwdLastSet = 0} -ErrorAction Stop
            # Write-Host "Forced password expiration for: $displayName"
            
            # Optional: Add user to a specified group (uncomment to enable)
            if ($groupDN) {
                Add-ADGroupMember -Identity $groupDN -Members $adUser -ErrorAction Stop
                Write-Host "Added $displayName to group: $groupName"
            }
        } else {
            Write-Warning "User not found: $inputName"
        }
    } catch {
        Write-Error "Failed to process $inputName : $_"
    }
}

Write-Host "Processing complete. Check output for details."
