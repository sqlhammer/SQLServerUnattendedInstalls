###################################################################################
### SCRIPT GENERATES INI FILES WHICH CAN BE USED TO PERFORM UNATTENDED INSTALLS ###
### OF SQL SERVER.                                                              ###
###################################################################################

###################################################################################
###								Help Context									###
###################################################################################

<#
.SYNOPSIS
This script will create the configuration.ini file(s) necessary for an unattended or silent
installation of MS SQL Server 2012 as a Stand-A-Lone Instance or a Windows Fail-Over Cluster.

.DESCRIPTION
This script is designed to be a start to finish solution for unattended or silent installations
of MS SQL Server 2012. It will walk you through a number of questions specific to the server or cluster 
that you are installing this instance on and then create the necessary configuration.ini files. 
Your template file will be saved to a location of your choice.

.EXAMPLE
.\Silent_Install_SQL11.ps1

.NOTES
At this time SSRS and SSAS features are not supported and this script is intended for MS SQL
Server 2012 instances only.

.INPUTS
None.

.OUTPUTS
None.
#>

#############################
####Includes and Declares####
#############################

#SQL Version
$Script:MajorSQLVersion = 11;

#load windows form assembly
[reflection.assembly]::loadwithpartialname('system.windows.forms') | Out-Null; 

#Instantiates a new com object we'll use for choosing folders
$object = New-Object -comObject Shell.Application

#setup clipboard alias
IF ((get-alias | where-object {$_.name -eq "out-clipboard"} | select name) -NotLike "*out-clipboard*")
{
	new-alias  Out-Clipboard $env:SystemRoot\system32\clip.exe
}

################
###Functions####
################

#welcome message
function WelcomeMessage()
{
	#Let the user know what this script does
	[system.Windows.Forms.MessageBox]::show("You are about to create ini files that can be used to automate installation of SQL instances into a stand-alone server or cluster.
				
When choosing to create the ini for a new clustered instance it will also create the ini file used to add nodes to that cluster.

The ini files can be renamed when they are completed.
	")
}

#Set variables for file naming
function SetFilePath()
{
	#Grab the current user and current time, we'll use these to create the file
	$CurrUser = [Security.Principal.WindowsIdentity]::GetCurrent() | select Name
	$Script:FileCreator = $CurrUser.Name
	$Script:CurrDate = (Get-Date -UFormat "%Y-%m-%d %H:%M") 
	$CurrDateSanitized = $CurrDate -replace ":",""

	#Strip out the domain from the user account
	if ($FileCreator -ilike "*\*") 
	{
		$string = $FileCreator.Split("\")
		$FilePart1 = ($string[1]) -replace "\.", " "
		$FilePart1 = (Get-Culture).TextInfo.ToTitleCase($FilePart1)
	}
	else
	{
		$FilePart1 = (Get-Culture).TextInfo.ToTitleCase($FileCreator)
	}

	#Current user + date time = filename	
	$Script:FileName = $FilePart1+" "+$CurrDateSanitized+" New Instance.ini"
	$Script:FileNameAddNode = $FilePart1+" "+$CurrDateSanitized+" Add Node.ini"
		
	#Ask the user for the path where they want to put the ini file	
	$inifolder = $object.BrowseForFolder(0, "Please choose the folder where you wish to put the INI file", 0)
	if ($inifolder -ne $null) 
	{
		$ini = $inifolder.self.Path 
		#if we use a root drive we need to remove the \
		$iniRoot =$inifolder.Self.Type
		if ($iniRoot -eq "Local Disk") 
		{ 
			$ini = $ini -replace "\\","" 
		}
		$Script:file = $ini +"\"+ $fileName
		$Script:FileNameAddNode = $ini +"\"+ $FileNameAddNode
	}
}

#Create choices for whether we want to install a new clustered instance, add a node, or perform a stand-alone install
function SetInstallationType()
{
	$InstallCluster = New-Object System.Management.Automation.Host.ChoiceDescription "&New Clustered Instance","By selecting this option you will generate two ini files. One for the new instance installation and one to add a node."
	$AddNode = New-Object System.Management.Automation.Host.ChoiceDescription "&Add Node To Cluster","By selecting this option you will skip several irrelevant questions and only generate one ini file designed for adding a node to an existing instance."
	$StandAlone = New-Object System.Management.Automation.Host.ChoiceDescription "New &Stand Alone Instance","By selecting this option you will generate one ini file necessary to install your instance."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($InstallCluster,$AddNode,$StandAlone)
	$caption = "Question!"
	$message = "Install stand-alone instance, clustered instance or add node to existing cluster?"
	$InstallChoice = $Host.UI.PromptForChoice($caption,$message,$choices,2)

	switch ($InstallChoice)
	{
		0 {$Script:InstallChoice="INSTALLCLUSTER"}
		1 {$Script:InstallChoice="ADDNODE"}
		2 {$Script:InstallChoice="STANDALONEINSTALL"}
	}
}

#Set non-configurable options
function WriteNonConfigurableOptions([string]$InstallType)
{
	#Install specific settings
	switch ( $InstallChoice )
	{
		"STANDALONEINSTALL"
		{
			#Default settings
			";File created by: $FileCreator" | Out-File $file 
			";File creation date: $CurrDate" | Out-File $file -Append
			
			";Script to install new SQL clustered instance" | Out-file $file -Append
			";SQLSERVER2008 Configuration File" | Out-file $file -Append
			"" | Out-File $file -Append
			"[SQLSERVER2008]" | Out-File $file -Append
			"" | Out-File $file -Append
			
			"IACCEPTSQLSERVERLICENSETERMS=`"TRUE`"" | Out-File $file -Append
			
			"HELP=`"False`"" |  Out-File $file -Append
			"INDICATEPROGRESS=`"True`"" |  Out-File $file -Append
			"QUIET=`"False`"" |  Out-File $file -Append
			"QUIETSIMPLE=`"True`"" |  Out-File $file -Append
			"X86=`"False`"" |  Out-File $file -Append
			"ENU=`"True`"" |  Out-File $file -Append
			"FTSVCACCOUNT=`"NT AUTHORITY\LOCAL SERVICE`"" |  Out-File $file -Append
		
			#SQL binaries location (in this case to C: I usually use D:)
			"INSTALLSHAREDDIR=`"C:\Program Files\Microsoft SQL Server`"" |  Out-File $file -Append
			"INSTALLSHAREDWOWDIR=`"C:\Program Files (x86)\Microsoft SQL Server`"" |  Out-File $file -Append
			"INSTANCEDIR=`"C:\Program Files\Microsoft SQL Server`"" |  Out-File $file -Append
			
			#Installing new cluster
			"ACTION=`"Install`"" |  Out-File $file -Append

			#Default settings
			"ERRORREPORTING=`"False`"" |  Out-File $file -Append
			"SQMREPORTING=`"False`"" |  Out-File $file -Append
			"FILESTREAMLEVEL=`"0`"" |  Out-File $file -Append
			"ISSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
			"ISSVCACCOUNT=`"NT AUTHORITY\NetworkService`"" |  Out-File $file -Append
			"SQLCOLLATION=`"SQL_Latin1_General_CP1_CI_AS`"" |  Out-File $file -Append
			"AGTSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
			"SQLSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
			"BROWSERSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
			"TCPENABLED=`"1`"" |  Out-File $file -Append
		}
		"INSTALLCLUSTER"
		{
			#Default settings
			";File created by: $FileCreator" | Out-File $file 
			";File creation date: $CurrDate" | Out-File $file -Append
			
			";Script to install new SQL clustered instance" | Out-file $file -Append
			";SQLSERVER2008 Configuration File" | Out-file $file -Append
			"" | Out-File $file -Append
			"[SQLSERVER2008]" | Out-File $file -Append
			"" | Out-File $file -Append
			
			"IACCEPTSQLSERVERLICENSETERMS=`"TRUE`"" | Out-File $file -Append
			
			"HELP=`"False`"" |  Out-File $file -Append
			"INDICATEPROGRESS=`"True`"" |  Out-File $file -Append
			"QUIET=`"False`"" |  Out-File $file -Append
			"QUIETSIMPLE=`"True`"" |  Out-File $file -Append
			"X86=`"False`"" |  Out-File $file -Append
			"ENU=`"True`"" |  Out-File $file -Append
			"FTSVCACCOUNT=`"NT AUTHORITY\LOCAL SERVICE`"" |  Out-File $file -Append
		
			#SQL binaries location (in this case to C: I usually use D:)
			"INSTALLSHAREDDIR=`"C:\Program Files\Microsoft SQL Server`"" |  Out-File $file -Append
			"INSTALLSHAREDWOWDIR=`"C:\Program Files (x86)\Microsoft SQL Server`"" |  Out-File $file -Append
			"INSTANCEDIR=`"C:\Program Files\Microsoft SQL Server`"" |  Out-File $file -Append
			
			#Installing new cluster
			"ACTION=`"InstallFailoverCluster`"" |  Out-File $file -Append

			#Default settings
			"ERRORREPORTING=`"False`"" |  Out-File $file -Append
			"SQMREPORTING=`"False`"" |  Out-File $file -Append
			"FILESTREAMLEVEL=`"0`"" |  Out-File $file -Append
			"ISSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
			"ISSVCACCOUNT=`"NT AUTHORITY\NetworkService`"" |  Out-File $file -Append
			"SQLCOLLATION=`"SQL_Latin1_General_CP1_CI_AS`"" |  Out-File $file -Append
		}
		"ADDNODE"
		{
			#Default settings
			";File created by: $FileCreator" | Out-File $FileNameAddNode 
			";File creation date: $CurrDate" | Out-File $FileNameAddNode -Append
			
			";Script to install new SQL clustered instance" | Out-file $FileNameAddNode -Append
			";SQLSERVER2008 Configuration File" | Out-file $FileNameAddNode -Append
			"" | Out-File $FileNameAddNode -Append
			"[SQLSERVER2008]" | Out-File $FileNameAddNode -Append
			"" | Out-File $FileNameAddNode -Append
					
			"IACCEPTSQLSERVERLICENSETERMS=`"TRUE`"" | Out-File $FileNameAddNode -Append
			
			"HELP=`"False`"" |  Out-File $FileNameAddNode -Append
			"INDICATEPROGRESS=`"True`"" |  Out-File $FileNameAddNode -Append
			"QUIET=`"False`"" |  Out-File $FileNameAddNode -Append
			"QUIETSIMPLE=`"True`"" |  Out-File $FileNameAddNode -Append
			"X86=`"False`"" |  Out-File $FileNameAddNode -Append
			"ENU=`"True`"" |  Out-File $FileNameAddNode -Append
			"FTSVCACCOUNT=`"NT AUTHORITY\LOCAL SERVICE`"" |  Out-File $FileNameAddNode -Append
		
			#Adding a new node
			"ACTION=`"AddNode`"" | Out-File $FileNameAddNode -Append
		}
		default
		{
			Write-Error "Installation choice not recognized."
		}
	}
}

#Set SQL virtual network name, Instance name, and IP
function ConfigureInstanceOptions([string]$InstallType)
{
	switch ( $InstallChoice )
	{
		"STANDALONEINSTALL"
		{
			#SQL Instance Name or default
			$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","By selecting this option you will install a default instance by the name of `"MSSQLServer`"."
			$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","By selecting this option you will install an instance with a name that you choose."
			$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
			$caption = "Question!"
			$message = "Is this going to be a default instance?"
			$IsDefaultInstance = $Host.UI.PromptForChoice($caption,$message,$choices,1)

			switch ($IsDefaultInstance)
			{
				0 {$Script:IsDefaultInstance="YES"}
				1 {$Script:IsDefaultInstance="NO"}
			}
			
			if ( $IsDefaultInstance -eq "YES" )
			{
				$Script:SQLInstanceName = "MSSQLSERVER"
				"INSTANCENAME=`"$SQLInstanceName`"" |  Out-File $file -Append
				"INSTANCEID=`"$SQLInstanceName`"" |  Out-File $file -Append
			}
			else
			{
				$SQLInstanceName = Read-Host "Enter the SQL instance name
	ie: CLDB001A"
				$Script:SQLInstanceName = $SQLInstanceName.ToUpper()
				"INSTANCENAME=`"$SQLInstanceName`"" |  Out-File $file -Append
				"INSTANCEID=`"$SQLInstanceName`"" |  Out-File $file -Append
			}
		}
		"INSTALLCLUSTER"
		{
			#SQL Virtual Name
			$SQLVirtualName = read-host "Enter the SQL virtual network name
	ie: CL-DB-001-A"
			$Script:SQLVirtualName = $SQLVirtualName.ToUpper()
			"FAILOVERCLUSTERNETWORKNAME=`"$SQLVirtualName`"" | Out-File $file -Append
				
			#SQL Instance Name (will also use for Instance ID and failover cluster group)
			$SQLInstanceName = Read-Host "Enter the SQL instance name
	ie: CLDB001A"
			$Script:SQLInstanceName = $SQLInstanceName.ToUpper()
			"INSTANCENAME=`"$SQLInstanceName`"" |  Out-File $file -Append
			"INSTANCEID=`"$SQLInstanceName`"" |  Out-File $file -Append
			"FAILOVERCLUSTERGROUP=`"$SQLVirtualName`"" |  Out-File $file -Append

			#IPAddress (running IPV4 only)
			$IPAddress = Read-Host "Enter the IP Address (IPv4 only)"
            $Subnet = Read-Host "Enter the subnet"
			"FAILOVERCLUSTERIPADDRESSES=`"IPv4;$IPAddress`;Cluster Network 1;$Subnet`""  |  Out-File $file -Append
		}
		"ADDNODE"
		{
			#SQL Virtual Name
			$SQLVirtualName = read-host "Enter the SQL virtual network name
			ie: CL-DB-001-A"
			$Script:SQLVirtualName = $SQLVirtualName.ToUpper()
			"FAILOVERCLUSTERNETWORKNAME=`"$SQLVirtualName`"" | Out-File $FileNameAddNode -Append

			#SQL Instance Name (will also use for Instance ID and failover cluster group)
			$SQLInstanceName = Read-Host "Enter the SQL instance name
			ie: CLDB001A"
			$Script:SQLInstanceName = $SQLInstanceName.ToUpper()
			"INSTANCENAME=`"$SQLInstanceName`"" |  Out-File $FileNameAddNode -Append
			"FAILOVERCLUSTERGROUP=`"$SQLVirtualName`"" |  Out-File $FileNameAddNode -Append
		}
		default
		{
			Write-Error "Installation choice not recognized."
		}
	}
}

function SetFeatures() #TODO: Consider making this a list of check boxes
{
	#The SQLENGINE is always installed for this script.
	$Features = "FEATURES=SQLENGINE"
	
	##REPLICATION
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install replication as one of its features. NOTE: If replication is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit replication from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have REPLICATION installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	if ($FeatureChoice -eq 0)
	{
		$Features = $Features + ",REPLICATION"
	}

	##FULLTEXT
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install full-text search as one of its features. NOTE: If full-text search is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit full-text search from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have FULLTEXT installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	if ($FeatureChoice -eq 0)
	{
		$Features = $Features + ",FULLTEXT"
	}

	##BIDS
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install Business Intelligence Developer Studio as one of its features. NOTE: If BIDS is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit Business Intelligence Developer Studio from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have BUSINESS INTELLIGENCE DEVELOPMENT STUDIO installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	if ($FeatureChoice -eq 0)
	{
		$Features = $Features + ",BIDS"
	}

	##IS
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install integration services as one of its features. NOTE: If integration services is already installed for this cluster then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit integration services from the feature set. Integration services is only necessary for remote management of stored SSIS packages and is not necessary for execution."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have INTEGRATED SERVICES installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

	if ($FeatureChoice -eq 0)
	{
		$Features = $Features + ",IS"
	}

	##SSMS,ADV_SSMS
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install SQL Server Management Studio basic and advanced as one of its features. NOTE: If SSMS is already installed for this cluster then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit SQL Server Management Studio from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have SQL SERVER MANAGEMENT STUDIO installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

	if ($FeatureChoice -eq 0)
	{
		$Features = $Features + ",SSMS,ADV_SSMS"
	}
	
	##CONN,BC,SDK,BOL,SNAC_SDK,OCS
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install Client Connectivity Tools, Books Online, and SDKs as one of its features. NOTE: If these are already installed for this cluster then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit SQL Server Management Studio from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have CLIENT CONNECTIVITY TOOLS, BOOKS ONLINE, AND SDKs installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

	if ($FeatureChoice -eq 0)
	{
		$Features = $Features + ",CONN,BC,SDK,BOL,SNAC_SDK,OCS"
	}
	
	#WRITE FEATURES
	$Features |  Out-File $file -Append
}

function SetSysAdminAccounts([string]$UseDefaults, $InstallType)
{
	#SET SYSADMIN ACCOUNT HERE
	$AcctList = (read-host "Enter a comma delimited list of sysadmin accounts for this instance
	eg DOMAIN\Database Administration, DOMAIN\Account2").split(",")

	$AcctsComplete = [string]""
	foreach ($Acct in $AcctList)
		{
		$Acct = $Acct.Trim()
			$Acct = "`"$Acct`" "
			$AcctsComplete += $Acct
	}
		
	"SQLSYSADMINACCOUNTS=$AcctsComplete" |  Out-File $file -Append
		
	#Choose Security Mode
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will enable mixed mode authentication which allows for Windows or SQL Authentication."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will restrict your installation to Windows Authentication."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to use Mixed Mode Authentication (not recommended)?"
	$SecChoice = $Host.UI.PromptForChoice($caption,$message,$choices,1)
		
	switch ($SecChoice)
	{
		0 { $Script:SecChoice="YES" }
		1 { $Script:SecChoice="NO" }
	}
		
	IF ($SecChoice -eq "YES")
	{
		"SECURITYMODE=`"SQL`"" | Out-File $file -Append
	}
		
    #Choose Security Mode
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes will add the current user to the list of sysadmins to the server."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will only have the explicit list of sysadmins defined."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to add the current user as a sysadmin to this instance?"
	$CurrentUserSysadmin = $Host.UI.PromptForChoice($caption,$message,$choices,1)

    switch ($CurrentUserSysadmin)
    {
        0 { $Script:CurrentUserSysadmin="YES" }
        1 { $Script:CurrentUserSysadmin="NO" }
    }

	if ($CurrentUserSysadmin -eq "YES" )
	{
		"ADDCURRENTUSERASSQLADMIN=`"True`"" |  Out-File $file -Append
	}
    else
    {
        "ADDCURRENTUSERASSQLADMIN=`"False`"" |  Out-File $file -Append
    }
}

#Set service accounts
function SetServiceAccounts()
{
	#Choose service accounts
	$Script:SQLServiceAccount = Read-Host "Enter the SQL Service account to be used"
	"SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $file -Append
	$Script:SQLAgentAccount = Read-Host "Enter the SQL Agent account to be used"
	"AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $file -Append
}

function SetFileDirectories()
{
    [string]$VersionString = ([string]$MajorSQLVersion).Replace(".", "_");

	#System databases
	$SysDBfolder = Read-Host "Select root folder for SQL SYSTEM databases (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$SysDBfolder = $object.BrowseForFolder(0, "Select root folder for SQL SYSTEM databases.", 0)
	if ($SysDBfolder -ne $null) 
    {
	    #$SysDB = $SysDBfolder.self.Path + "\SQLSystem"
	    $SysDB = $SysDBfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\SQLSystem"
	    "INSTALLSQLDATADIR=`"$SysDB`"" |  Out-File $file -Append
	}

	#Default User DB location
	$UserDBfolder = Read-Host "Select root folder for USER DATABASE DATA files (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$UserDBfolder = $object.BrowseForFolder(0, "Select root folder for USER DATABASE DATA files.", 0)
	if ($UserDBfolder -ne $null) 
    {
	    #$UserDB = $UserDBfolder.self.Path + "\MSSQL\Data"
	    $UserDB = $UserDBfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\MSSQL\Data"
	    "SQLUSERDBDIR=`"$UserDB`"" |  Out-File $file -Append
	}

	#Default User Log location
	$UserLogfolder = Read-Host "Select root folder for USER DATABASE LOG files (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$UserLogfolder = $object.BrowseForFolder(0, "Select root folder for USER DATABASE LOG files", 0)
	if ($UserLogfolder -ne $null) 
    {
	    #$UserLog = $UserLogfolder.self.Path + "\MSSQL\Logs"
	    $UserLog = $UserLogfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\MSSQL\Logs"
	    "SQLUSERDBLOGDIR=`"$UserLog`"" |  Out-File $file -Append
	}
	
	#TempDB
	$TempDBfolder = Read-Host "Select root folder for SQL TempDB (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$TempDBfolder = $object.BrowseForFolder(0, "Select root folder for SQL TempDB.", 0)
	if ($TempDBfolder -ne $null) 
    {
	    #$TempDB = $TempDBfolder.self.Path + "\MSSQL\Data"
	    $TempDB = $TempDBfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\MSSQL\Data"
	    "SQLTEMPDBDIR=`"$TempDB`"" |  Out-File $file -Append
	}

	#Default backup location
	$Backupfolder = Read-Host "Select ROOT folder for DATABASE BACKUPS (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$Backupfolder = $object.BrowseForFolder(0, "Select root folder for DATABASE BACKUPS", 0)
	if ($Backupfolder -ne $null) 
    {
	    #$Backup = $Backupfolder.self.Path + "\MSSQL\Backup"
	    $Backup = $Backupfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\MSSQL\Backup"
	    "SQLBACKUPDIR=`"$Backup`"" |  Out-File $file -Append
	}
}

function SetClusterDisks()
{
	$DiskList = (read-host "Enter a comma delimited list of failover cluster disks for use in this cluster
	eg SQL Data, SQL Log, SQL Backup").split(",")

	$DiskComplete = [string]""
	foreach ($Disk in $DiskList)
		{
		$Disk = $Disk.Trim()
		 $Disk = "`"$Disk`" "
		 $DiskComplete += $Disk
	}

	"FAILOVERCLUSTERDISKS=$DiskComplete" |  Out-File $file -Append
}

#Let the user know the script is complete and where the files reside		
function ExitMessage([string]$InstallType)
{
	if($SkipMessage -eq "NO")
	{
		switch ( $InstallChoice )
		{
			"STANDALONEINSTALL"
			{
				[system.Windows.Forms.MessageBox]::show
				(
					"SQL ini file created!
						Be sure to check your ini config before using.
							
					To create a new SQL instance use:
						`"$file`" 
						
					Example: 
						setup.exe /CONFIGURATIONFILE=`"<Filename.ini>`" 
						/SQLSVCPASSWORD=`"<SQL service account pwd>`" 
						/AGTSVCPASSWORD=`"<Agent service account pwd>`"
						
					Setup command written to PowerShell output window.    
				")
			}
			"INSTALLCLUSTER"
			{
				[system.Windows.Forms.MessageBox]::show
				(
					"SQL ini files created!
						Be sure to check your ini config before using.
							
					To create a new clustered SQL instance use:
						`"$file`" 
						
					To add a node to an existing cluster use:	
						`"$FileNameAddNode`"
							
					Example: 
						setup.exe /CONFIGURATIONFILE=`"<Filename.ini>`" 
						/SQLSVCPASSWORD=`"<SQL service account pwd>`" 
						/AGTSVCPASSWORD=`"<Agent service account pwd>`"
						
					Setup command written to PowerShell output window.    
				")
			}
			"ADDNODE"
			{
				[system.Windows.Forms.MessageBox]::show
				(
					"SQL ini files created!
						Be sure to check your ini config before using.
						
					To add a node to an existing cluster use:	
						`"$FileNameAddNode`"
							
					Example: 
						setup.exe /CONFIGURATIONFILE=`"<Filename.ini>`" 
						/SQLSVCPASSWORD=`"<SQL service account pwd>`" 
						/AGTSVCPASSWORD=`"<Agent service account pwd>`"
						
					Setup command written to PowerShell output window.    
				")
			}
			default
			{
				Write-Error "Installation choice not recognized."
			}
		}
	}
}

#Write everything to the AddNode ini file
function WriteAddNodeFile()
{
	";File created by: $FileCreator" | Out-File $FileNameAddNode 
	";File creation date: $CurrDate" | Out-File $FileNameAddNode -Append

	";Script to add node to existing SQL cluster" | Out-file $FileNameAddNode -Append
	";SQLSERVER2008 Configuration File" | Out-file $FileNameAddNode -Append
	"[SQLSERVER2008]" | Out-File $FileNameAddNode -Append
 
	"IACCEPTSQLSERVERLICENSETERMS=`"TRUE`"" | Out-File $FileNameAddNode -Append

	"ACTION=`"AddNode`"" | Out-File $FileNameAddNode -Append
	"HELP=`"False`"" | Out-File $FileNameAddNode -Append
	"INDICATEPROGRESS=`"True`"" | Out-File $FileNameAddNode -Append
	"QUIET=`"True`"" | Out-File $FileNameAddNode -Append
	"X86=`"False`"" | Out-File $FileNameAddNode -Append
	"ENU=`"True`""  | Out-File $FileNameAddNode -Append
	
	"FTSVCACCOUNT=`"NT AUTHORITY\LOCALSERVICE`"" | Out-File $FileNameAddNode -Append
	
	"SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $FileNameAddNode -Append

	"AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $FileNameAddNode -Append	
	
	"FAILOVERCLUSTERNETWORKNAME=`"$SQLVirtualName`"" | Out-File $FileNameAddNode -Append

	"INSTANCENAME=`"$SQLInstanceName`"" |  Out-File $FileNameAddNode -Append
	"FAILOVERCLUSTERGROUP=`"$SQLVirtualName`"" |  Out-File $FileNameAddNode -Append
}

function PrintExecCMD([string]$SQLAuthMode)
{
	IF ($SQLAuthMode -eq "NO")
	{
		$ExecCmdPrintOut = "setup.exe /CONFIGURATIONFILE=`"$file`" /SQLSVCPASSWORD=`"<enter pwd>`" /AGTSVCPASSWORD=`"<enter pwd>`""
		
		#export to clipboard
		$ExecCmdPrintOut | Out-Clipboard
		
		Write-Host ""
		Write-Host $ExecCmdPrintOut
		Write-Host ""
		Write-Host "The above command has been outputed to your clipboard."
	}
	ELSE
	{
		$ExecCmdPrintOut = "setup.exe /CONFIGURATIONFILE=`"$file`" /SQLSVCPASSWORD=`"<enter pwd>`" /AGTSVCPASSWORD=`"<enter pwd>`" /SAPWD=`"<enter pwd>`""
		
		#export to clipboard
		$ExecCmdPrintOut | Out-Clipboard
		
		Write-Host ""
		Write-Host $ExecCmdPrintOut
		Write-Host ""
		Write-Host "The above command has been outputed to your clipboard."
	}
}

################
###   Main  ####
################

WelcomeMessage

SetInstallationType

SetFilePath

switch ( $InstallChoice )
{
	"STANDALONEINSTALL"
	{

		WriteNonConfigurableOptions $InstallChoice
		
		ConfigureInstanceOptions $InstallChoice
		
		SetFeatures
		
		SetSysAdminAccounts $InstallChoice
		
		SetServiceAccounts
		
		SetFileDirectories
		
		ExitMessage $InstallChoice
		
		PrintExecCMD $SecChoice
	}
	"INSTALLCLUSTER"
	{
		Try
		{
			WriteNonConfigurableOptions $InstallChoice
			
			ConfigureInstanceOptions $InstallChoice
			
			SetFeatures
			
			SetSysAdminAccounts $InstallChoice
			
			SetServiceAccounts $InstallChoice

			SetFileDirectories

			SetClusterDisks

			WriteAddNodeFile

			ExitMessage $InstallChoice
		
		    PrintExecCMD $SecChoice
		}
		Catch
		{ 
			Write-Error "Errors occured during the INI creation. Inspect your INI file before attempting to use it." 
		}
	}
	"ADDNODE"
	{
		Try
		{		
			WriteNonConfigurableOptions $InstallChoice
			
			ConfigureInstanceOptions $InstallChoice
			
			SetServiceAccounts $InstallChoice

			ExitMessage $InstallChoice
		}
		Catch
		{ 
			Write-Error "Errors occurred during the INI creation. Inspect your INI file before attempting to use it."
		}	
	}
	default
	{
		Write-Error "Installation choice not recognized."
	}
}
