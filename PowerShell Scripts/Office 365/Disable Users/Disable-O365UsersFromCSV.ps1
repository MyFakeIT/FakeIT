# Script: Disable-O365UsersFromCSV.ps1
# Purpose: Disables O365 accounts from a CSV, sets random passwords, and configures password policies in Microsoft Entra ID.
# Author: FakeIT (AI Assisted)
# Date: April 04, 2025
# Notes:
# - Requires Microsoft.Graph PowerShell module (Install-Module Microsoft.Graph) for O365 user management.
# - CSV must have a 'UserPrincipalName' column (e.g., user1@domain.com).
# - Default CSV path and file: C:\PS\O365UsersToDisable.csv
# - Requires sufficient Microsoft Entra ID permissions (e.g., User Administrator or Global Administrator).
# - Random passwords include letters, numbers, mixed case, and symbols (!@#$%^&*).
# - Automatically installs Microsoft.Graph module if missing.

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
$csvPath = "C:\PS\O365UsersToDisable.csv"

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

# Connect to Microsoft Graph (requires User.ReadWrite.All scope for user management)
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All" -ErrorAction Stop -NoWelcome
    Write-Host "Connected to Microsoft Graph" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit
}

# Read the CSV and process each user
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    # Ensure the CSV has a valid UserPrincipalName column
    if (-not $user.UserPrincipalName) {
        Write-Warning "Missing 'UserPrincipalName' in one of the CSV rows. Skipping..."
        continue
    }

    $upn = $user.UserPrincipalName

    try {
        # Get the user by UserPrincipalName in O365
        $o365User = Get-MgUser -UserId $upn -ErrorAction Stop

        if ($o365User) {
            # Disable the account in O365
            Update-MgUser -UserId $o365User.Id -AccountEnabled $false -ErrorAction Stop
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Disabled O365 account" -ForegroundColor White
            Write-Host

            # Generate and set a random password with retry logic
            $newPassword = New-RandomPassword
            $passwordProfile = @{
                "password" = $newPassword
                "forceChangePasswordNextSignIn" = $true  # Forces password change at next sign-in
            }
            $maxRetries = 3
            $retryCount = 0
            $passwordSet = $false
            do {
                try {
                    Update-MgUser -UserId $o365User.Id -PasswordProfile $passwordProfile -ErrorAction Stop
                    $passwordSet = $true
                } catch {
                    $retryCount++
                    if ($retryCount -ge $maxRetries) {
                        throw $_  # Re-throw the error after max retries
                    }
                    Write-Warning ("Password attempt {0} failed for {1}: {2}. Retrying..." -f $retryCount, $upn, $_.Exception.Message)
                    $newPassword = New-RandomPassword
                    $passwordProfile["password"] = $newPassword
                }
            } until ($passwordSet -or $retryCount -ge $maxRetries)
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Set random password for O365 account (Password: " -ForegroundColor White
            Write-Host -NoNewline "$newPassword" -ForegroundColor Yellow
            Write-Host ")" -ForegroundColor White

            # Verify the password change
            $updatedO365User = Get-MgUser -UserId $o365User.Id -Property LastPasswordChangeDateTime -ErrorAction Stop
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Last O365 Password Change Date: " -ForegroundColor White
            Write-Host "$($updatedO365User.LastPasswordChangeDateTime)" -ForegroundColor Yellow

            # Ensure cloud expiration policy by clearing PasswordPolicies
            Update-MgUser -UserId $o365User.Id -PasswordPolicies "" -ErrorAction Stop
            Write-Host -NoNewline "$upn" -ForegroundColor Green
            Write-Host -NoNewline ": Ensured cloud expiration policy" -ForegroundColor White
            Write-Host

            # Add red horizontal line after user processing
            Write-Host "----------" -ForegroundColor Red
        } else {
            Write-Warning "User not found in O365: $upn"
        }
    } catch {
        Write-Error "Failed to process $upn: $_"
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Host "Processing complete. Check output for details." -ForegroundColor Green
