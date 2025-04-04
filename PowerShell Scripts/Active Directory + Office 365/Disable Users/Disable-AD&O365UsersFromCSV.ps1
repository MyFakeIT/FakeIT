# Script: Disable-AD&O365UsersFromCSV.ps1
# Purpose: Disables AD and O365 accounts from a CSV, sets random passwords, configures password policies, and adds users to an on-premises AD group.
# Author: FakeIT (AI Assisted)
# Date: April 04, 2025
# Notes:
# - Requires Microsoft.Graph PowerShell module (Install-Module Microsoft.Graph) for O365 user management.
# - Requires ActiveDirectory module (via RSAT) for on-premises AD management.
# - CSV must have a 'Username' column; accepts SamAccountName (e.g., user1) or UserPrincipalName (e.g., user1@domain.com).
# - Default CSV path and file: C:\PS\AD&O365UsersToDisable.csv
# - Requires sufficient Microsoft Entra ID permissions (e.g., User Administrator) and AD permissions (e.g., Domain Admin).
# - Random passwords include letters, numbers, mixed case, and symbols (!@#$%^&*).
# - Notifies if an AD user isn’t found in O365 instead of erroring out.

# --- Check and Install ActiveDirectory Module ---
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Host "ActiveDirectory module not found. Attempting to install now..." -ForegroundColor Yellow
    try {
        Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -ErrorAction Stop
        Write-Host "ActiveDirectory module installed successfully via RSAT." -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to install ActiveDirectory module. Ensure RSAT is available or install manually." -ForegroundColor Red
        exit
    }
}

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "ActiveDirectory module loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to load ActiveDirectory module." -ForegroundColor Red
    exit
}

# --- Check and Install Microsoft Graph Module ---
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

# Define the CSV file path
$csvPath = "C:\PS\AD&O365UsersToDisable.csv"

# Define an on-premises AD group to add users to
$groupName = "PW-Cleanup-2025"  # On-premises AD group

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

# Connect to Microsoft Graph with broader scopes
Disconnect-MgGraph -ErrorAction SilentlyContinue
Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.AccessAsUser.All","Directory.ReadWrite.All" -ErrorAction Stop -NoWelcome
Write-Host "Connected to Microsoft Graph" -ForegroundColor Green

# Validate the on-premises AD group
$groupDN = $null
try {
    $group = Get-ADGroup -Identity $groupName -ErrorAction Stop
    $groupDN = $group.DistinguishedName
    Write-Host -NoNewline "On-premises AD group found: " -ForegroundColor White
    Write-Host "$groupDN" -ForegroundColor Yellow
} catch {
    Write-Error "On-premises AD group '$groupName' not found or inaccessible. Group addition will be skipped: $_"
    $groupDN = $null
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

        # Process AD user if found
        if ($adUser) {
            if ($adUser.UserPrincipalName) {
                $displayName = $adUser.UserPrincipalName
            } else {
                $displayName = $adUser.SamAccountName
            }

            # Generate a random password for AD
            $newPassword = New-RandomPassword
            $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force

            # Disable the AD account
            Disable-ADAccount -Identity $adUser -ErrorAction Stop
            Write-Host -NoNewline "$displayName" -ForegroundColor Green
            Write-Host -NoNewline ": Disabled on-premises AD account" -ForegroundColor White
            Write-Host

            # Set the new random password in AD with retry logic
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

            # Verify the AD password change immediately
            $updatedADUser = Get-ADUser -Identity $adUser -Properties pwdLastSet -ErrorAction Stop
            $pwdLastSetDate = [DateTime]::FromFileTime($updatedADUser.pwdLastSet)
            Write-Host -NoNewline "$displayName" -ForegroundColor Green
            Write-Host -NoNewline ": Last AD Password Change Date: " -ForegroundColor White
            Write-Host "$pwdLastSetDate" -ForegroundColor Yellow

            # Configure AD password policies (this sets pwdLastSet to 0)
            Set-ADUser -Identity $adUser -PasswordNeverExpires $false -ChangePasswordAtLogon $true -ErrorAction Stop
            $updatedUser = Get-ADUser -Identity $adUser -Properties pwdLastSet -ErrorAction Stop
            if ($updatedUser.pwdLastSet -eq 0) {
                Write-Host -NoNewline "$displayName" -ForegroundColor Green
                Write-Host -NoNewline ": Confirmed: 'User must change password at next logon' is set" -ForegroundColor White
                Write-Host
            } else {
                Write-Warning "'User must change password at next logon' NOT set for $displayName (pwdLastSet: $($updatedUser.pwdLastSet))"
            }
            Write-Host -NoNewline "$displayName" -ForegroundColor Green
            Write-Host -NoNewline ": Configured AD password policies (Password: " -ForegroundColor White
            Write-Host -NoNewline "$newPassword" -ForegroundColor Yellow
            Write-Host ")" -ForegroundColor White

            # Add to AD group if specified
            if ($groupDN) {
                Add-ADGroupMember -Identity $groupDN -Members $adUser -ErrorAction Stop
                Write-Host -NoNewline "$displayName" -ForegroundColor Green
                Write-Host -NoNewline ": Added to on-premises AD group: " -ForegroundColor White
                Write-Host "$groupName" -ForegroundColor Yellow
            }
        } else {
            Write-Warning "User not found in AD: $inputName"
        }

        # Process O365 user with notification instead of error if not found
        $o365User = Get-MgUser -UserId $upn -ErrorAction SilentlyContinue
        if ($o365User) {
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Attempting to disable O365 account" -ForegroundColor White
            Write-Host
            Update-MgUser -UserId $o365User.Id -AccountEnabled:$false -ErrorAction Stop
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Disabled O365 account" -ForegroundColor White
            Write-Host

            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Attempting to set O365 password" -ForegroundColor White
            Write-Host
            if ($adUser) {
                $o365Password = $newPassword
            } else {
                $o365Password = New-RandomPassword
            }
            $passwordProfile = @{
                "password" = $o365Password
                "forceChangePasswordNextSignIn" = $true
            }
            Update-MgUser -UserId $o365User.Id -PasswordProfile $passwordProfile -ErrorAction Stop
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Set random password for O365 account (Password: " -ForegroundColor White
            Write-Host -NoNewline "$o365Password" -ForegroundColor Yellow
            Write-Host ")" -ForegroundColor White

            # Verify the O365 password change immediately
            $updatedO365User = Get-MgUser -UserId $o365User.Id -Property LastPasswordChangeDateTime -ErrorAction Stop
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Last O365 Password Change Date: " -ForegroundColor White
            Write-Host "$($updatedO365User.LastPasswordChangeDateTime)" -ForegroundColor Yellow

            # Tenant default password policy will apply, followed by red line
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Tenant default password policy will apply" -ForegroundColor White
            Write-Host
            Write-Host "----------" -ForegroundColor Red
        } elseif ($adUser) {
            Write-Warning "User $upn found in AD but not in O365. O365 actions skipped."
        } else {
            Write-Warning "User not found in O365: $upn"
        }
    } catch {
        Write-Error "Failed to process $inputName : $_"
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Host "Processing complete. Check output for details." -ForegroundColor Green
