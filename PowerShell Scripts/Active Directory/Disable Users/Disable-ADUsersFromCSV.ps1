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
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "ActiveDirectory module loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to load ActiveDirectory module." -ForegroundColor Red
    exit
}

# Define the CSV file path
$csvPath = "C:\PS\ADUsersToDisable.csv"

# Optional: Define an AD group to add users to (uncomment to use)
$groupName = "PW-Cleanup-2025"  # Group to add users to

# Get the current domain name for UPN construction
$domain = (Get-ADDomain).DNSRoot  # e.g., "example.com"

# Function to generate a random password with a length between 12 and 15 characters
function New-RandomPassword {
    $minLength = 12
    $maxLength = 15
    $length = Get-Random -Minimum $minLength -Maximum ($maxLength + 1)

    # Define character sets
    $upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lower = "abcdefghijklmnopqrstuvwxyz"
    $numbers = "0123456789"
    $special = "!@#$%^&*"

    # Ensure at least one of each category
    $password = @(
        $upper[(Get-Random -Maximum $upper.Length)]
        $lower[(Get-Random -Maximum $lower.Length)]
        $numbers[(Get-Random -Maximum $numbers.Length)]
        $special[(Get-Random -Maximum $special.Length)]
    )

    # Fill the remaining length with random characters
    $allChars = $upper + $lower + $numbers + $special
    $remainingLength = $length - 4
    if ($remainingLength -gt 0) {
        $password += 0..($remainingLength - 1) | ForEach-Object { $allChars[(Get-Random -Maximum $allChars.Length)] }
    }

    # Shuffle the password to avoid predictable patterns
    $password = $password | Get-Random -Count $password.Length
    return -join $password
}

# Validate the group if specified
$groupDN = $null
if ($groupName) {
    try {
        $group = Get-ADGroup -Identity $groupName -ErrorAction Stop
        $groupDN = $group.DistinguishedName
        Write-Host -NoNewline "On-premises AD group found: " -ForegroundColor White
        Write-Host "$groupDN" -ForegroundColor Yellow
    } catch {
        Write-Error "Group '$groupName' not found or inaccessible. Aborting group addition: $_"
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

            # Disable the account
            Disable-ADAccount -Identity $adUser -ErrorAction Stop
            Write-Host -NoNewline "$displayName" -ForegroundColor Green
            Write-Host -NoNewline ": Disabled on-premises AD account" -ForegroundColor White
            Write-Host
            
            # Generate a random password and set it with retry logic
            $newPassword = New-RandomPassword
            $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force
            $maxRetries = 3
            $retryCount = 0
            $passwordSet = $false
            do {
                try {
                    Set-ADAccountPassword -Identity $adUser -NewPassword $securePassword -Reset -ErrorAction Stop
                    $passwordSet = $true
                } catch {
                    $retryCount++
                    if ($retryCount -ge $maxRetries) {
                        throw $_  # Re-throw the error after max retries
                    }
                    Write-Warning ("Password attempt {0} failed for {1}: {2}. Retrying..." -f $retryCount, $displayName, $_.Exception.Message)
                    $newPassword = New-RandomPassword
                    $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force
                }
            } until ($passwordSet -or $retryCount -ge $maxRetries)
            Write-Host -NoNewline "$displayName" -ForegroundColor Green
            Write-Host -NoNewline ": Set random password for AD account" -ForegroundColor White
            Write-Host
            
            # Verify the password change
            $updatedADUser = Get-ADUser -Identity $adUser -Properties pwdLastSet -ErrorAction Stop
            $pwdLastSetDate = [DateTime]::FromFileTime($updatedADUser.pwdLastSet)
            Write-Host -NoNewline "$displayName" -ForegroundColor Green
            Write-Host -NoNewline ": Last AD Password Change Date: " -ForegroundColor White
            Write-Host "$pwdLastSetDate" -ForegroundColor Yellow
            
            # Uncheck "Password never expires" and enforce "User must change password at next logon"
            try {
                Set-ADUser -Identity $adUser `
                           -PasswordNeverExpires $false `
                           -ChangePasswordAtLogon $true `
                           -ErrorAction Stop
                
                # Verify the "User must change password at next logon" setting
                $updatedUser = Get-ADUser -Identity $adUser -Properties pwdLastSet -ErrorAction Stop
                if ($updatedUser.pwdLastSet -eq 0) {
                    Write-Host -NoNewline "$displayName" -ForegroundColor Green
                    Write-Host -NoNewline ": Confirmed: 'User must change password at next logon' is set" -ForegroundColor White
                    Write-Host
                } else {
                    Write-Warning "'User must change password at next logon' NOT set for $displayName (pwdLastSet: $($updatedUser.pwdLastSet))"
                }
            } catch {
                Write-Error "Failed to set password policies for $displayName : $_"
                continue
            }
            
            Write-Host -NoNewline "$displayName" -ForegroundColor Green
            Write-Host -NoNewline ": Configured AD password policies (Password: " -ForegroundColor White
            Write-Host -NoNewline "$newPassword" -ForegroundColor Yellow
            Write-Host ")" -ForegroundColor White
            
            # Optional: Force password to expire immediately (uncomment to enable)
            # Set-ADUser -Identity $adUser -Replace @{pwdLastSet = 0} -ErrorAction Stop
            # Write-Host -NoNewline "$displayName" -ForegroundColor Green
            # Write-Host -NoNewline ": Forced password expiration" -ForegroundColor White
            # Write-Host
            
            # Optional: Add user to a specified group (uncomment to enable)
            if ($groupDN) {
                Add-ADGroupMember -Identity $groupDN -Members $adUser -ErrorAction Stop
                Write-Host -NoNewline "$displayName" -ForegroundColor Green
                Write-Host -NoNewline ": Added to on-premises AD group: " -ForegroundColor White
                Write-Host "$groupName" -ForegroundColor Yellow
            }

            # Add red horizontal line after user processing
            Write-Host "----------" -ForegroundColor Red
        } else {
            Write-Warning "User not found: $inputName"
        }
    } catch {
        Write-Error "Failed to process $inputName : $_"
    }
}

Write-Host "Processing complete. Check output for details." -ForegroundColor Green
