# Active Directory Password Audit Script

This repository contains a PowerShell script designed to audit password-related attributes for Active Directory users in an on-premises AD environment. The script exports detailed user account data to a CSV file, enabling security reviews and compliance checks.

## Scripts

### 1. Export-ADPasswordAudit.ps1
- **Purpose**: Exports a detailed password audit report for all Active Directory users to a CSV file for analysis.
- **Output**: Saves `ADPasswordAudit-YYYY-MM-DD.csv` to `C:\PS` (e.g., `C:\PS\ADPasswordAudit-2025-04-02.csv`).
- **Details**: 
  - Retrieves all users with `-Filter *` to ensure a comprehensive audit.
  - Exports fields like `Name`, `UserPrincipalName`, `PasswordLastSet`, `PasswordExpired`, `AccountEnabled`, and more for tracking password status, account activity, and security risks.
  - Uses a dynamic date in the filename for easy versioning.
- **Usage**: 
  ```powershell
  .\Export-ADPasswordAudit.ps1

  ## Prerequisites
- **PowerShell Module**: `ActiveDirectory`
  - **Install**: Available with Remote Server Administration Tools (RSAT) or AD PowerShell on domain-joined systems.
  - **Enable**: `Import-Module ActiveDirectory`
- **Permissions**: Sufficient AD permissions (e.g., Domain Admin or equivalent)
- **Execution**: Run in a PowerShell session with access to the AD environment

- ## Workflow
### Running the Audit
1. Run `Export-ADPasswordAudit.ps1` to generate the CSV file.
2. Review the output in `C:\PS\ADPasswordAudit-YYYY-MM-DD.csv` using Excel, PowerShell, or another tool.
3. Analyze fields like `PasswordExpired`, `PasswordNeverExpires`, and `LastLogonDate` to identify security risks or policy violations.

## Notes
- **Output Directory**: The script creates `C:\PS` if it doesn’t exist. Modify `$outputDir` in the script if a different path is preferred.
- **Scope**: Queries all users by default. Add `-SearchBase "OU=YourOU,DC=domain,DC=com"` to limit to a specific OU.
- **Verification**: After running, check the CSV for completeness or use:
  ```powershell
  Import-Csv "C:\PS\ADPasswordAudit-2025-04-02.csv" | Where-Object { $_.PasswordExpired -eq "True" }
  to find expired passwords.
Customization: Edit the Select-Object properties in the script to include additional AD fields as needed.

## Author
- FakeIT (AI assisted)
- **Date**: April 02, 2025

