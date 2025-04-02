# Active Directory Password Audit Script

This repository contains a PowerShell script designed to audit password-related attributes for Active Directory users in an on-premises AD environment. The script exports detailed user account data to a CSV file, enabling security reviews and compliance checks.


## Scripts

### 1. Export-ADPasswordAudit.ps1

- **Purpose**: Exports a detailed password audit report for all Active Directory users to a CSV file for analysis.
- **Output**: Saves `ADPasswordAudit-YYYY-MM-DD.csv` to `C:\PS` (e.g., `C:\PS\ADPasswordAudit-2025-04-02.csv`).
- **Details**:
  - Retrieves all users using `-Filter *` for a comprehensive audit.
  - Includes fields like `Name`, `UserPrincipalName`, `PasswordLastSet`, `PasswordExpired`, `PasswordAgeDays`, `AccountEnabled`, and more to track password status, account activity, and potential security risks.
  - Uses a dynamic date in the filename for easy versioning and historical tracking.
- **Usage**:
  ```powershell
  .\Export-ADPasswordAudit.ps1

---



## Prerequisites

- **PowerShell Module**: `ActiveDirectory`
  - **Install**: Included with RSAT or available on domain-joined systems.
  - **Enable**:
    ```powershell
    Import-Module ActiveDirectory
    ```

- **Permissions**: Run with sufficient privileges (e.g., Domain Admin or delegated rights).

- **Execution**: Must be run in a PowerShell session with connectivity to the Active Directory environment.


## Workflow

### Running the Audit

1. Run `Export-ADPasswordAudit.ps1` to generate the CSV file.
2. Locate and open the output file at `C:\PS\ADPasswordAudit-YYYY-MM-DD.csv` using Excel, PowerShell, or any CSV-compatible tool.
3. Analyze key fields like:
   - `PasswordExpired`
   - `PasswordNeverExpires`
   - `PasswordAgeDays`
   - `LastLogonDate`
   - `AccountEnabled`
   - `AccountLockedOut`

   These fields help identify expired passwords, stale accounts, and users exempt from expiration policies.


## Notes

- **Output Directory**: The script automatically creates `C:\PS` if it doesn’t exist. You can change this by modifying the `$outputDir` variable in the script.

- **Scope**: By default, the script queries all users in the domain. To limit it to a specific OU, modify the `Get-ADUser` command with a `-SearchBase` parameter, for example:
  ```powershell
  Get-ADUser -Filter * -SearchBase "OU=YourOU,DC=domain,DC=com"
  ```
Verification Example: After running the script, you can quickly find users with expired passwords:

```powershell
Import-Csv "C:\PS\ADPasswordAudit-2025-04-02.csv" | Where-Object { $_.PasswordExpired -eq "True" }
```
Customization: You can edit the Select-Object block in the script to include additional AD fields such as Title, Department, or custom attributes.


---


## Author

- **FakeIT** (AI Assisted)
- **Date**: April 02, 2025
