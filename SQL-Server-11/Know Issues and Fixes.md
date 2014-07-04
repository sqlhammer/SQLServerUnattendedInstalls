# Known Issues #
- SSAS needs further testing.
- SSRS needs further testing.
- Data quality server, master data services, and distributed replay services need further testing.
- Elements to add: RSINSTALLMODE, RSSHPINSTALLMODE,  RSSVCSTARTUPTYPE, ASSVCSTARTUPTYPE, ASCOLLATION, SQLCOLLATION, ASDATADIR, ASLOGDIR, ASBACKUPDIR, ASTEMPDIR, ASCONFIGDIR, ASPROVIDERMSOLAP, ASSYSADMINACCOUNTS, ASSERVERMODE

----------
# Bug Fixes / Release History #

- 7/4/2014 5:17:06 PM - Bug fix - AddCurrentUserAsSQLAdmin defaulted to FALSE because it is only applicable when using ROLEs or with SQL Express.
- 7/4/2014 5:16:14 PM - Bug fix - Distributed Replay Controller security attributes.
- 6/29/2014 9:33:12 PM - Initial publish.