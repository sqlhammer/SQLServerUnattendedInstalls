# Known Issues #

- This version is in open beta testing. I look forward to your feedback (derik@sqlhammer.com).
- UPDATEENABLED and UPDATESOURCE should not be possible when installing a 2008 / 2008 R2 instance.

----------
TODO: Consider how default values affect the add node config when serializing all non-null attributes.

----------
# Bug Fixes / Release History #

- Refactored with new customer QSConfig.SQLInstallConfiguration class structure.
- Now supports setting the FILESTREAM access level.
- Granted more explicit control over folder directories.
- All supported SQL Server versions are now available in one script.
- Added prompt for ISSvcAccount.
- Added prompt for FileStreamShareName if FileStreamLevel is set to 2 or 3.
- Corrected various typos. 
- Corrected syntax compatibility issues with PowerShell v2.0.
