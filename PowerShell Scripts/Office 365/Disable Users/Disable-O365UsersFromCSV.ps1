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
    $length = Get-Random -Minimum $minLength -Maximum ($maxLength + 1)  # Maximum is exclusive
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    $password = -join ((0..($length - 1)) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Connect to Microsoft Graph (requires User.ReadWrite.All scope for user management)
Connect-MgGraph -Scopes "User.ReadWrite.All" -ErrorAction Stop
Write-Host "Connected to Microsoft Graph"

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
            Write-Host "Disabled O365 account: $upn"

            # Generate and set a random password
            $newPassword = New-RandomPassword
            $passwordProfile = @{
                "password" = $newPassword
                "forceChangePasswordNextSignIn" = $true  # Forces password change at next sign-in
            }
            Update-MgUser -UserId $o365User.Id -PasswordProfile $passwordProfile -ErrorAction Stop
            Write-Host "Set random password for: $upn (Password: $newPassword)"

            # Ensure cloud expiration policy by clearing PasswordPolicies
            Update-MgUser -UserId $o365User.Id -PasswordPolicies "" -ErrorAction Stop
            Write-Host "Ensured cloud expiration policy for: $upn"
        } else {
            Write-Warning "User not found in O365: $upn"
        }
    } catch {
        Write-Error "Failed to process $upn: $_"
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Host "Processing complete. Check output for details."
