# Script: Disable-ADUsersFromCSV.ps1
# Purpose: Disables AD accounts from a CSV, sets random passwords, and configures password policies.
# Author: FakeIT (AI Assisted)
# Date: April 02, 2025
# Notes:
# - Requires ActiveDirectory module.
# - CSV must have a 'UserPrincipalName' column with valid UPNs (e.g., user@domain.com).
# - Must run with sufficient AD permissions (e.g., Domain Admin).
# - Random passwords include letters, numbers, mixed case, and symbols (!@#$%^&*).

# Import the ActiveDirectory module
Import-Module ActiveDirectory -ErrorAction Stop

# Define the CSV file path (modify as needed)
$csvPath = "C:\PS\UsersToDisable.csv"

# Function to generate a random 12-character password
function New-RandomPassword {
    $length = 12
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    $password = -join ((0..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Read the CSV and process each user
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {
    $upn = $user.UserPrincipalName
    
    try {
        # Get the AD user object
        $adUser = Get-ADUser -Filter "UserPrincipalName -eq '$upn'" -ErrorAction Stop
        
        if ($adUser) {
            # Generate a random 12-character password
            $newPassword = New-RandomPassword
            $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force
            
            # Disable the account
            Disable-ADAccount -Identity $adUser -ErrorAction Stop
            Write-Host "Disabled account: $upn"
            
            # Set the new random password
            Set-ADAccountPassword -Identity $adUser -NewPassword $securePassword -Reset -ErrorAction Stop
            Write-Host "Set random password for: $upn"
            
            # Uncheck "Password never expires" and check "User must change password at next logon"
            Set-ADUser -Identity $adUser `
                       -PasswordNeverExpires $false `
                       -ChangePasswordAtLogon $true `
                       -ErrorAction Stop
            Write-Host "Configured password policies for: $upn (Password: $newPassword)"
        } else {
            Write-Warning "User not found: $upn"
        }
    } catch {
        Write-Error "Failed to process $upn : $_"
    }
}

Write-Host "Processing complete. Check output for details."
