###################################################################################
### SCRIPT GENERATES INI FILES WHICH CAN BE USED TO PERFORM UNATTENDED INSTALLS ###
### OF SQL SERVER. NOTE: This script assumes that the product key is packaged   ###
### with the installation media.                                                ###
###################################################################################

###################################################################################
###								Help Context									###
###################################################################################

<#
.SYNOPSIS
This script will create the configuration.ini file(s) necessary for an unattended or silent
installation of MS SQL Server 2008 / 2008 R2 as a Stand-A-Lone Instance or a Windows Fail-Over Cluster.

.DESCRIPTION
This script is designed to be a start to finish solution for unattended or silent installations
of MS SQL Server 2008 / 2008 R2 at Liberty Tax Service. The script has certain Liberty defaults
registered within it that you can optionally select for expediancy in entering the necessary information.
It will then walk you through a number of questions specific to the cluster that you are installing
this instance on and then create the necessary configuration.ini files. At the end you will be able
to command PowerShell to execute the installation right then or you can request that the execution
command be printed and copied to your clipboard for future use.

.EXAMPLE
.\InstallSQL_Silent.ps1

.NOTES
At this time SSRS and SSAS features are not supported and this script has only been tested on MS SQL
Server 2008 and 2008 R2 instances.

.INPUTS
None.

.OUTPUTS
None.
#>

################
####Includes####
################

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

#See if the user wants to use Liberty standard responses for some options
function UseLibertyDefaults()
{
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","By selecting yes you will be allowing this script to skip certain questions where there are registered Liberty defaults and skip all informational messages. For example, regarding services accounts you will be asked what environment this install is for but not the service accounts. Those will be populated automatically."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","By selecting no you will be given the full opportunity to select every configuration and set variables manually."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to use Liberty minimal install with default options for choices where applicable?"
	$LibertyDefaultChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

	switch ($LibertyDefaultChoice)
	{
		0 {$Script:LibertyDefaultChoice = "YES"}
		1 {$Script:LibertyDefaultChoice = "NO"}
	}
}

#welcome message
function WelcomeMessage([string]$SkipMessage)
{
	if ($Script:SkipMessage -eq "NO")
	{
		#Let the user know what this script does
		[system.Windows.Forms.MessageBox]::show("You are about to create ini files that can be used to automate installation of SQL instances into a cluster and then (optionally) initiate the setup sequence.
				
When choosing to create the ini for a new clustered instance it will also create the ini file used to add nodes to that cluster.

The ini files can be renamed when they are completed.
		")
	}
}

#identify which environment to set service accounts
function SelectEnvironment([string]$UseDefaults)
{
	if ($UseDefaults -eq "YES")
	{
		$Dev = New-Object System.Management.Automation.Host.ChoiceDescription "&Dev","Select Dev if this configuration is for a development instance."
		$SIT = New-Object System.Management.Automation.Host.ChoiceDescription "&SIT","Select SIT if this configuration is for a SIT instance."
		$QA = New-Object System.Management.Automation.Host.ChoiceDescription "&QA","Select QA if this configuration is for a QA instance."
		$Production = New-Object System.Management.Automation.Host.ChoiceDescription "&Prod","Select Prod if this configuration is for a production instance."
		$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Dev,$SIT,$QA,$Production)
		$caption = "Question!"
		$message = "Which environment is this configuration for?"
		$EnvironmentSelection = $Host.UI.PromptForChoice($caption,$message,$choices,3)
		
		switch ($EnvironmentSelection) 
		{ 
			0 {$Script:EnvironmentSelection="DEV"} 
			1 {$Script:EnvironmentSelection="SIT"} 
			2 {$Script:EnvironmentSelection="QA"} 
			3 {$Script:EnvironmentSelection="PRODUCTION"} 
		}
	}
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

#Create choices for whether we want to install a new clustered instance or add a node
function SetInstallationType()
{
	$InstallCluster = New-Object System.Management.Automation.Host.ChoiceDescription "&New Clustered Instance","By selecting this option you will generate two ini files. One for the new instance installation and one to add a node."
	$AddNode = New-Object System.Management.Automation.Host.ChoiceDescription "&Add Node To Cluster","By selecting this option you will skip several irrelevant questions and only generate one ini file designed for adding a node to an existing instance."
	$StandAlone = New-Object System.Management.Automation.Host.ChoiceDescription "New &Stand Alone Instance","By selecting this option you will generate one ini file necessary to install your instance."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($InstallCluster,$AddNode,$StandAlone)
	$caption = "Question!"
	$message = "Install stand-alone instance, clustered instance or add node to existing cluster?"
	$InstallChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

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

			#IPAddress (running IPV4 only and will use default 255.255.0.0 subnet)
			$IPAddress = Read-Host "Enter the IP Address (IPv4 only)"
			"FAILOVERCLUSTERIPADDRESSES=`"IPv4;$IPAddress`;Cluster Network 1;255.255.0.0`""  |  Out-File $file -Append
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

function SetFeatures([string]$UseDefaults)
{
	#The SQLENGINE is always installed for this script.
	$Features = "FEATURES=SQLENGINE"
	
	IF ($UseDefaults -eq "NO")
	{
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
	}
	ELSE
	{
		$Features = $Features + ",REPLICATION"
	}
	IF ($UseDefaults -eq "NO")
	{
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
	}
	ELSE
	{
		$Features = $Features + ",FULLTEXT"
	}
	IF ($UseDefaults -eq "NO")
	{
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
	}
	else
	{
		if (($EnvironmentSelection -eq "DEV") -OR ($EnvironmentSelection -eq "SIT"))
		{
			$Features = $Features + ",BIDS"
		}
	}
	IF ($UseDefaults -eq "NO")
	{
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
	}
	else
	{
		if (($EnvironmentSelection -eq "DEV") -OR ($EnvironmentSelection -eq "SIT"))
		{
			$Features = $Features + ",IS"
		}
	}
	IF ($UseDefaults -eq "NO")
	{
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
	}
	else
	{
		if (($EnvironmentSelection -eq "DEV") -OR ($EnvironmentSelection -eq "SIT"))
		{
			$Features = $Features + ",SSMS,ADV_SSMS"
		}
	}
	IF ($UseDefaults -eq "NO")
	{
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
	}
	else
	{
		if (($EnvironmentSelection -eq "DEV") -OR ($EnvironmentSelection -eq "SIT"))
		{
			$Features = $Features + ",CONN,BC,SDK,BOL,SNAC_SDK,OCS"
		}
	}

	#WRITE FEATURES
	$Features |  Out-File $file -Append
}

function SetSysAdminAccounts([string]$UseDefaults, $InstallType)
{
	IF ($UseDefaults -eq "NO")
	{
		#SET SYSADMIN ACCOUNT HERE
		$AcctList = (read-host "Enter a comma delimited list of sysadmin accounts for this instance
		eg LIBERTY\Database Administration, LIBERTY\SCMAdmin").split(",")

		$AcctsComplete = [string]""
		foreach ($Acct in $AcctList)
			{
			$Acct = $Acct.Trim()
			 $Acct = "`"$Acct`" "
			 $AcctsComplete += $Acct
		}
		
		"SQLSYSADMINACCOUNTS=$AcctsComplete" |  Out-File $file -Append
		
		#Choose Security Mode
		$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will enable mixed mode authentication which allows for Windows or SQL Authentication. NOTE: This is not a best practice and violates Liberty's development standards."
		$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will restrict your installation to Windows Authentication. NOTE: This option is best practice and a Liberty development standard."
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
	}
	ELSE
	{
		#SET SYSADMIN ACCOUNT HERE
		$AcctList = "LIBERTY\Database Administration, LIBERTY\SCMAdmin".split(",")

		$AcctsComplete = [string]""
		foreach ($Acct in $AcctList)
			{
			$Acct = $Acct.Trim()
			 $Acct = "`"$Acct`" "
			 $AcctsComplete += $Acct
		}
		
		"SQLSYSADMINACCOUNTS=$AcctsComplete" |  Out-File $file -Append
	}
	
	if ($InstallType -eq "STANDALONEINSTALL" )
	{
		#don't add the current user as a sysadmin to the instance
		"ADDCURRENTUSERASSQLADMIN=`"False`"" |  Out-File $file -Append
	}
}

#Set service accounts
function SetServiceAccounts([string]$UseDefaults,[string]$Env,[string]$InstallType)
{
	$Script:Env1 = $Env
	$Script:Install1 = $InstallType
	$Script:Default1 = $UseDefaults

	IF ($UseDefaults -eq "NO")
	{
		#Choose service accounts
		$Script:SQLServiceAccount = Read-Host "Enter the SQL Service account to be used"
		"SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $file -Append
		$Script:SQLAgentAccount = Read-Host "Enter the SQL Agent account to be used"
		"AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $file -Append
	}
	ELSE
	{
		switch ($Env)
		{
			"DEV" 
			{
				$Script:SQLServiceAccount = 'LIBERTY\DevMSSQLService'
				"SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $file -Append
				$Script:SQLAgentAccount = 'LIBERTY\DevAgentService'
				"AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $file -Append
			}
			"SIT" 
			{
				$Script:SQLServiceAccount = 'LIBERTY\SITMSSQLService'
				"SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $file -Append
				$Script:SQLAgentAccount = 'LIBERTY\SITAgentService'
				"AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $file -Append
			}
			"QA" 
			{
				$Script:SQLServiceAccount = 'LIBERTY\QAMSSQLService'
				"SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $file -Append
				$Script:SQLAgentAccount = 'LIBERTY\QAAgentService'
				"AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $file -Append
			}
			"PRODUCTION" 
			{
				$Script:SQLServiceAccount = 'LIBERTY\MSSQLService'
				"SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $file -Append
				$Script:SQLAgentAccount = 'LIBERTY\AgentService'
				"AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $file -Append
			}
		}
	}
}

function SetFileDirectories()
{
	#System databases
	$SysDBfolder = Read-Host "Select root folder for SQL SYSTEM databases (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$SysDBfolder = $object.BrowseForFolder(0, "Select root folder for SQL SYSTEM databases.", 0)
	if ($SysDBfolder -ne $null) {
	#$SysDB = $SysDBfolder.self.Path + "\SQLSystem"
	$SysDB = $SysDBfolder + "\MSSQL10_50." + $SQLInstanceName + "\SQLSystem"
	"INSTALLSQLDATADIR=`"$SysDB`"" |  Out-File $file -Append
	}

	#Default User DB location
	$UserDBfolder = Read-Host "Select root folder for USER DATABASE DATA files (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$UserDBfolder = $object.BrowseForFolder(0, "Select root folder for USER DATABASE DATA files.", 0)
	if ($UserDBfolder -ne $null) {
	#$UserDB = $UserDBfolder.self.Path + "\MSSQL\Data"
	$UserDB = $UserDBfolder + "\MSSQL10_50." + $SQLInstanceName + "\MSSQL\Data"
	"SQLUSERDBDIR=`"$UserDB`"" |  Out-File $file -Append
	}

	#Default User Log location
	$UserLogfolder = Read-Host "Select root folder for USER DATABASE LOG files (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$UserLogfolder = $object.BrowseForFolder(0, "Select root folder for USER DATABASE LOG files", 0)
	if ($UserLogfolder -ne $null) {
	#$UserLog = $UserLogfolder.self.Path + "\MSSQL\Logs"
	$UserLog = $UserLogfolder + "\MSSQL10_50." + $SQLInstanceName + "\MSSQL\Logs"
	"SQLUSERDBLOGDIR=`"$UserLog`"" |  Out-File $file -Append
	}
	
	#TempDB
	$TempDBfolder = Read-Host "Select root folder for SQL TempDB (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$TempDBfolder = $object.BrowseForFolder(0, "Select root folder for SQL TempDB.", 0)
	if ($TempDBfolder -ne $null) {
	#$TempDB = $TempDBfolder.self.Path + "\MSSQL\Data"
	$TempDB = $TempDBfolder + "\MSSQL10_50." + $SQLInstanceName + "\MSSQL\Data"
	"SQLTEMPDBDIR=`"$TempDB`"" |  Out-File $file -Append
	}

	#Default backup location
	$Backupfolder = Read-Host "Select ROOT folder for DATABASE BACKUPS (Do not include the trailing '\')
	eg. J: or J:\SQLServer"
	#$Backupfolder = $object.BrowseForFolder(0, "Select root folder for DATABASE BACKUPS", 0)
	if ($Backupfolder -ne $null) {
	#$Backup = $Backupfolder.self.Path + "\MSSQL\Backup"
	$Backup = $Backupfolder + "\MSSQL10_50." + $SQLInstanceName + "\MSSQL\Backup"
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

#Let the use know the script is complete and where the files reside		
function ExitMessage([string]$SkipMessage,[string]$InstallType)
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

function ExecuteInstall([string]$SQLAuthMode)
{
	IF ($SQLAuthMode -eq "NO")
	{
		$SQLSVCPASSWORD = read-host "/SQLSVCPASSWORD"
		$AGTSVCPASSWORD = read-host "/AGTSVCPASSWORD"
		
		$SetupFilePath = read-host "setup.exe fully qualified file path (ie. D:\)"
		$ExecCmd = $SetupFilePath + 'setup.exe'
		$ExecCmd = $ExecCmd + " /CONFIGURATIONFILE=`"$file`" /SQLSVCPASSWORD=`"$SQLSVCPASSWORD`" /AGTSVCPASSWORD=`"$AGTSVCPASSWORD`""
		
		Invoke-Item $ExecCmd
	}
	ELSE
	{
		$SAPWD = read-host "/SAPWD"
		$SQLSVCPASSWORD = read-host "/SQLSVCPASSWORD"
		$AGTSVCPASSWORD = read-host "/AGTSVCPASSWORD"
		
		$SetupFilePath = read-host "setup.exe fully qualified file path (ie. D:\)"
		$ExecCmd = $SetupFilePath + 'setup.exe'
		$ExecCmd = $ExecCmd + "/CONFIGURATIONFILE=`"$file`" /SQLSVCPASSWORD=`"$SQLSVCPASSWORD`" /AGTSVCPASSWORD=`"$AGTSVCPASSWORD`" /SAPWD=`"$SAPWD`""
		
		Invoke-Item $ExecCmd
	}
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

UseLibertyDefaults
	
WelcomeMessage $LibertyDefaultChoice
	
SelectEnvironment $LibertyDefaultChoice

SetInstallationType

SetFilePath

switch ( $InstallChoice )
{
	"STANDALONEINSTALL"
	{
		WriteNonConfigurableOptions $InstallChoice
		
		ConfigureInstanceOptions $InstallChoice
		
		SetFeatures $LibertyDefaultChoice
		
		SetSysAdminAccounts $LibertyDefaultChoice $InstallChoice
		
		SetServiceAccounts $LibertyDefaultChoice $EnvironmentSelection $InstallChoice
		
		SetFileDirectories
		
		ExitMessage $LibertyDefaultChoice, $InstallChoice
		
		#Offer an execution right now
		$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","By selecting yes this script will compile an executable command and begin the installation immediately."
		$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","By selecting no this script will compile and display a rough executable command for you along with copying the command to your clipboard for manual execution."
		$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
		$caption = "Question!"
		$message = "Would you like to enter passwords and run this installation now?"
		$ExecuteChoice = $Host.UI.PromptForChoice($caption,$message,$choices,1)
			
		switch ($ExecuteChoice)
		{
			0 {$ExecuteChoice = "YES"}
			1 {$ExecuteChoice = "NO"}
		}
		
		if ($ExecuteChoice -eq "YES")
		{
			#ExecuteInstall $SecChoice
			
			"There is currently a bug preventing execution so I'm forcing you to print not execute."
			PrintExecCMD $SecChoice
		}
		ELSE
		{
			PrintExecCMD $SecChoice
		}
	}
	"INSTALLCLUSTER"
	{
		Try
		{
			WriteNonConfigurableOptions $InstallChoice
			
			ConfigureInstanceOptions $InstallChoice
			
			SetFeatures $LibertyDefaultChoice
			
			SetSysAdminAccounts $LibertyDefaultChoice $InstallChoice
			
			SetServiceAccounts $LibertyDefaultChoice $EnvironmentSelection $InstallChoice

			SetFileDirectories

			SetClusterDisks

			WriteAddNodeFile

			ExitMessage $LibertyDefaultChoice, $InstallChoice
			
			#Offer an execution right now
			$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","By selecting yes this script will compile an executable command and begin the installation immediately."
			$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","By selecting no this script will compile and display a rough executable command for you along with copying the command to your clipboard for manual execution."
			$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
			$caption = "Question!"
			$message = "Would you like to enter passwords and run this installation now?"
			$ExecuteChoice = $Host.UI.PromptForChoice($caption,$message,$choices,1)
				
			switch ($ExecuteChoice)
			{
				0 {$ExecuteChoice = "YES"}
				1 {$ExecuteChoice = "NO"}
			}
				
			if ($ExecuteChoice -eq "YES")
			{
				ExecuteInstall $SecChoice
			}
			ELSE
			{
				PrintExecCMD $SecChoice
			}
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
			
			SetServiceAccounts $LibertyDefaultChoice $EnvironmentSelection $InstallChoice

			ExitMessage $LibertyDefaultChoice $InstallChoice
		}
		Catch
		{ 
			Write-Error "Errors occured during the INI creation. Inspect your INI file before attempting to use it."
		}	
	}
	default
	{
		Write-Error "Installation choice not recognized."
	}
}
