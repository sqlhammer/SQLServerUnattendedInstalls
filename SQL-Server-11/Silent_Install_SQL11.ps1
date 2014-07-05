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
None.

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

################
###Functions####
################

#dialog builder
function CreateYesNoDialog([string]$caption, [string]$question, [string]$yesMsg, [string]$noMsg, [int]$default = 0)
{
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",$yesMsg
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No",$noMsg
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = $caption
	$message = $question
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,$default)

    switch ($choice)
    {
        0 { $output="YES" }
        1 { $output="NO" }
    }

    return $output;
}

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
function WriteNonConfigurableOptions()
{
    if (($InstallChoice -eq "STANDALONEINSTALL") -or ($InstallChoice -eq "INSTALLCLUSTER"))
    {
        #Default settings
		";File created by: $FileCreator" | Out-File $file 
		";File creation date: $CurrDate" | Out-File $file -Append
			
		";Script to install new SQL Server instance" | Out-file $file -Append
		";SQLSERVER2012 Configuration File" | Out-file $file -Append
		"" | Out-File $file -Append
		"[OPTIONS]" | Out-File $file -Append
		"" | Out-File $file -Append
			
		"IACCEPTSQLSERVERLICENSETERMS=`"TRUE`"" | Out-File $file -Append
			
		"HELP=`"False`"" |  Out-File $file -Append
		"INDICATEPROGRESS=`"True`"" |  Out-File $file -Append
		"QUIET=`"False`"" |  Out-File $file -Append
		"QUIETSIMPLE=`"True`"" |  Out-File $file -Append
		"X86=`"False`"" |  Out-File $file -Append
		"ENU=`"True`"" |  Out-File $file -Append
		"FTSVCACCOUNT=`"NT AUTHORITY\LOCAL SERVICE`"" |  Out-File $file -Append
        "ADDCURRENTUSERASSQLADMIN=`"False`"" |  Out-File $file -Append
		
		#SQL binaries location (in this case to C: I usually use D:)
		"INSTALLSHAREDDIR=`"C:\Program Files\Microsoft SQL Server`"" |  Out-File $file -Append
		"INSTALLSHAREDWOWDIR=`"C:\Program Files (x86)\Microsoft SQL Server`"" |  Out-File $file -Append
		"INSTANCEDIR=`"C:\Program Files\Microsoft SQL Server`"" |  Out-File $file -Append

        "ERRORREPORTING=`"False`"" |  Out-File $file -Append
		"SQMREPORTING=`"False`"" |  Out-File $file -Append
		"FILESTREAMLEVEL=`"0`"" |  Out-File $file -Append
		"ISSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
		"ISSVCACCOUNT=`"NT AUTHORITY\NetworkService`"" |  Out-File $file -Append
		"SQLCOLLATION=`"SQL_Latin1_General_CP1_CI_AS`"" |  Out-File $file -Append

        #Install specific settings
	    if ($InstallChoice -eq "STANDALONEINSTALL")
	    {
		    #Installing new server
		    "ACTION=`"Install`"" |  Out-File $file -Append

		    #Default settings
		    "AGTSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
		    "SQLSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
		    "BROWSERSVCSTARTUPTYPE=`"Automatic`"" |  Out-File $file -Append
		    "TCPENABLED=`"1`"" |  Out-File $file -Append
	    }
        elseif ($InstallChoice -eq "INSTALLCLUSTER")
        {
            #Installing new cluster
		    "ACTION=`"InstallFailoverCluster`"" |  Out-File $file -Append
        }
    }
    elseif ($InstallChoice -eq "ADDNODE")
    {
        #Default settings
		";File created by: $FileCreator" | Out-File $FileNameAddNode 
		";File creation date: $CurrDate" | Out-File $FileNameAddNode -Append
			
		";Script to install new SQL Server instance" | Out-file $FileNameAddNode -Append
		";SQLSERVER2012 Configuration File" | Out-file $FileNameAddNode -Append
		"" | Out-File $FileNameAddNode -Append
		"[OPTIONS]" | Out-File $FileNameAddNode -Append
		"" | Out-File $FileNameAddNode -Append
					
		"IACCEPTSQLSERVERLICENSETERMS=`"TRUE`"" | Out-File $FileNameAddNode -Append
			
		"HELP=`"False`"" |  Out-File $FileNameAddNode -Append
		"INDICATEPROGRESS=`"True`"" |  Out-File $FileNameAddNode -Append
		"QUIET=`"False`"" |  Out-File $FileNameAddNode -Append
		"QUIETSIMPLE=`"True`"" |  Out-File $FileNameAddNode -Append
		"X86=`"False`"" |  Out-File $FileNameAddNode -Append
		"ENU=`"True`"" |  Out-File $FileNameAddNode -Append
		"FTSVCACCOUNT=`"NT AUTHORITY\LOCAL SERVICE`"" |  Out-File $FileNameAddNode -Append
        "ADDCURRENTUSERASSQLADMIN=`"False`"" |  Out-File $FileNameAddNode -Append
		
		#Adding a new node
		"ACTION=`"AddNode`"" | Out-File $FileNameAddNode -Append
    }
}

#Set SQL virtual network name, Instance name, and IP
function ConfigureInstanceOptions()
{
    #SQL Instance Name or default
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","By selecting this option you will add updates to this set of installs."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","By selecting this option you will not append updates to this install set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to include updates in this install?"
	$IncludeUpdates = $Host.UI.PromptForChoice($caption,$message,$choices,0)

	switch ($IncludeUpdates)
	{
		0 {$Script:IncludeUpdates="YES"}
		1 {$Script:IncludeUpdates="NO"}
	}
			
	if ( $Script:IncludeUpdates -eq "YES" )
	{
        $UpdatePath = Read-Host "Where would you like your updates to come from? Input `"MU`" for Microsoft Updates or a directory path."

        "UpdateSource=`"$UpdatePath`"" |  Out-File $file -Append
        "UpdateEnabled=`"True`"" |  Out-File $file -Append
	}
	else
	{
		"UpdateEnabled=`"False`"" |  Out-File $file -Append
	}

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
			
			if ( $Script:IsDefaultInstance -eq "YES" )
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
            $ClusterNetworkName = Read-Host "Enter the Cluster Network Name (ie. Cluster Network 1)"
			$IPAddress = Read-Host "Enter the IP Address (IPv4 only)"
            $Subnet = Read-Host "Enter the subnet"
			"FAILOVERCLUSTERIPADDRESSES=`"IPv4;$IPAddress`;$ClusterNetworkName;$Subnet`""  |  Out-File $file -Append
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
    $Features = "FEATURES="
    $isFirstFeature = $true;

	##SQLENGINE
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install the SQL Engine as one of its features."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit the SQL Engine from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have SQL ENGINE installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
	
    $Script:IncludeSQL = $false;
	if ($FeatureChoice -eq 0)
	{
        $Script:IncludeSQL = $true;
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "SQLENGINE"
	}
	
	##REPLICATION
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install replication as one of its features. NOTE: If replication is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit replication from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have REPLICATION installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "REPLICATION"
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
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "FULLTEXT"
	}

    ##DQ
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install data quality server as one of its features. NOTE: If data quality server is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit data quality server from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have DATA QUALITY SERVER installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "DQ"
	}

    ##DQC
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install data quality client as one of its features. NOTE: If data quality client is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit data quality client from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have DATA QUALITY CLIENT installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "DQC"
	}

    ##MDS
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install master data services as one of its features. NOTE: If master data services is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit master data services from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have MASTER DATA SERVICES installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "MDS"
	}

    ##DREPLAY_CTLR
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install distributed replay client as one of its features. NOTE: If distributed replay client is already installed for this instance then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit distributed replay client from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have DISTRIBUTED REPLAY CLIENT installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
    $Script:IncludeDREPLAY_CTLR = $false;
	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "DREPLAY_CTLR"
        $Script:IncludeDREPLAY_CTLR = $true;
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
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "BIDS"
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
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "IS"
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
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "SSMS,ADV_SSMS"
	}
	
	##CONN,BC,SDK,BOL,SNAC_SDK
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install Client Connectivity Tools, Books Online, and SDKs as one of its features. NOTE: If these are already installed for this cluster then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit Client Connectivity Tools, Books Online, and SDKs from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have CLIENT CONNECTIVITY TOOLS, BOOKS ONLINE, AND SDKs installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "CONN,BC,SDK,BOL,SNAC_SDK,SDK"
	}

    ##LocalDB
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install LocalDB as one of its features. NOTE: If LocalDB is already installed for this cluster then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit LocalDB from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have LOCALDB installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "LocalDB"
	}

    #SSRS
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install SQL Server Reporting Services as one of its features. NOTE: If SSRS is already installed for this server then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit SQL Server Reporting Services from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have SQL SERVER REPORTING SERVICES installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    $Script:IncludeRS = $false;
	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "RS"
        $Script:IncludeRS = $true;
	}

    #SSAS
    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes you will command this installation to install SQL Server Analysis Services as one of its features. NOTE: If SSAS is already installed for this server then the installation will throw errors."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no you will command this installation to omit SQL Server Analysis Services from the feature set."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to have SQL SERVER ANALYSIS SERVICES installed?"
	$FeatureChoice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    $Script:IncludeAS = $false;
	if ($FeatureChoice -eq 0)
	{
        if ($isFirstFeature) { $isFirstFeature = $false; }
        else { $Features = $Features + ","; }
		$Features = $Features + "AS"
        $Script:IncludeAS = $true;
	}
	
	#WRITE FEATURES
	$Features |  Out-File $file -Append
}

function SetSysAdminAccounts()
{
    if($Script:IncludeSQL)
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
		
	    IF ($Script:SecChoice -eq "YES")
	    {
		    "SECURITYMODE=`"SQL`"" | Out-File $file -Append
	    }
    }

    if($Script:IncludeAS)
    {
        $AcctList = (read-host "Enter a comma delimited list of sysadmin accounts for the Analysis Services
	    eg DOMAIN\Database Administration, DOMAIN\Account2").split(",")

	    $AcctsComplete = [string]""
	    foreach ($Acct in $AcctList)
		    {
		    $Acct = $Acct.Trim()
			    $Acct = "`"$Acct`" "
			    $AcctsComplete += $Acct
	    }
		
	    "ASSYSADMINACCOUNTS=$AcctsComplete" |  Out-File $file -Append
    }
}

#Set service accounts
function SetServiceAccounts()
{
	#Choose service accounts
    if($Script:IncludeSQL)
    {
	    $Script:SQLServiceAccount = Read-Host "Enter the SQL Service account to be used"
	    "SQLSVCACCOUNT=`"$SQLServiceAccount`"" |  Out-File $file -Append
	    $Script:SQLAgentAccount = Read-Host "Enter the SQL Agent account to be used"
	    "AGTSVCACCOUNT=`"$SQLAgentAccount`"" |  Out-File $file -Append
    }

    if($Script:IncludeRS)
    {
        $Script:RSAccount = Read-Host "Enter the SQL Server Reporting Services account to be used"
	    "RSSVCACCOUNT=`"$Script:RSAccount`"" |  Out-File $file -Append
    }

    if($Script:IncludeAS)
    {
        $Script:IncludeAS = Read-Host "Enter the SQL Server Analysis Services account to be used"
	    "ASSVCACCOUNT=`"$Script:IncludeAS`"" |  Out-File $file -Append
    }
}

function SetFileDirectories()
{
    [string]$VersionString = ([string]$MajorSQLVersion).Replace(".", "_");

    if($Script:IncludeSQL)
    {
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

    if($Script:IncludeAS)
    {
	    #Config databases
	    $Configfolder = Read-Host "Select root folder for SSAS config files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer"
	    if ($ConfigDBfolder -ne $null) 
        {
	        $ConfigDir = $ConfigDBfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\OLAP_Config"
	        "ASCONFIGDIR=`"$ConfigDir`"" |  Out-File $file -Append
	    }

	    #Default DATA location
	    $DataFolder = Read-Host "Select root folder for SSAS DATA files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer"
	    if ($DataFolder -ne $null) 
        {
	        $DataDir = $DataFolder + "\MSSQL$VersionString." + $SQLInstanceName + "\OLAP_Data"
	        "ASDATADIR=`"$DataDir`"" |  Out-File $file -Append
	    }

	    #Default Log location
	    $Logfolder = Read-Host "Select root folder for SSAS LOG files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer"
	    if ($Logfolder -ne $null) 
        {
	        $LogDir = $Logfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\OLAP_Logs"
	        "ASLOGDIR=`"$LogDir`"" |  Out-File $file -Append
	    }
	
	    #Temp
	    $Tempfolder = Read-Host "Select root folder for SSAS Temp files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer"
	    if ($Tempfolder -ne $null) 
        {
	        $TempDir = $Tempfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\OLAP_Temp"
	        "ASTEMPDIR=`"$TempDir`"" |  Out-File $file -Append
	    }

	    #Default backup location
	    $Backupfolder = Read-Host "Select root folder for SSAS BACKUPS (Do not include the trailing '\')
	    eg. J: or J:\SQLServer"
	    if ($Backupfolder -ne $null) 
        {
	        $Backup = $Backupfolder + "\MSSQL$VersionString." + $SQLInstanceName + "\OLAP_Backup"
	        "ASBACKUPDIR=`"$Backup`"" |  Out-File $file -Append
	    }
    }
}

function SetDistributedReplayInformation()
{
    $Input = Read-Host "Enter the computer name that the client communicates with for the Distributed Replay Controller service.";
    "CLTCTLRNAME=`"$Input`"" | Out-File $file -Append;

    $InputList = (Read-Host "Enter the Windows account(s) used to grant permission to the Distributed Replay Controller service.
    eg DOMAIN\Database Administration, DOMAIN\Account2").split(",");

	$AcctsComplete = [string]""
	foreach ($Acct in $InputList)
		{
		$Acct = $Acct.Trim()
			$Acct = "`"$Acct`" "
			$AcctsComplete += $Acct
	}
		
    $Input = Read-Host "Enter the account used by the Distributed Replay Controller service.";
	"CTLRUSERS=$AcctsComplete" |  Out-File $file -Append;

    $Input = Read-Host "Enter the account used by the Distributed Replay Controller Service.
    eg NT Service\SQL Server Distributed Replay Controller";
    "CTLRSVCACCOUNT=`"$Input`"" | Out-File $file -Append;

    $Manual = New-Object System.Management.Automation.Host.ChoiceDescription "&Manual","Selecting manual will set the startup type to manual."
	$Automatic = New-Object System.Management.Automation.Host.ChoiceDescription "&Automatic","Selecting automatic will set the startup type to automatic."
    $Disabled = New-Object System.Management.Automation.Host.ChoiceDescription "&Disabled","Selecting disabled will set the startup type to disabled."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Manual,$Automatic,$Disabled)
	$caption = "Question!"
	$message = "What startup type would you like your Distributed Replay Controller Service set to?"
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    switch ($choice)
    {
        0 { $Input="Manual" }
        1 { $Input="Automatic" }
        2 { $Input="Disabled" }
    }
    "CTLRSTARTUPTYPE=`"$Input`"" | Out-File $file -Append;

    $Input = Read-Host "Enter the account used by the Distributed Replay Client Service.
    eg NT Service\SQL Server Distributed Replay Client";
    "CLTSVCACCOUNT=`"$Input`"" | Out-File $file -Append;

    $Manual = New-Object System.Management.Automation.Host.ChoiceDescription "&Manual","Selecting manual will set the startup type to manual."
	$Automatic = New-Object System.Management.Automation.Host.ChoiceDescription "&Automatic","Selecting automatic will set the startup type to automatic."
    $Disabled = New-Object System.Management.Automation.Host.ChoiceDescription "&Disabled","Selecting disabled will set the startup type to disabled."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Manual,$Automatic,$Disabled)
	$caption = "Question!"
	$message = "What startup type would you like your Distributed Replay Client Service set to?"
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    switch ($choice)
    {
        0 { $Input="Manual" }
        1 { $Input="Automatic" }
        2 { $Input="Disabled" }
    }
    "CLTSTARTUPTYPE=`"$Input`"" | Out-File $file -Append;

    $Input = Read-Host "Enter the result directory for the Distributed Replay Client service. (No trailing slash)";
    "CLTRESULTDIR=`"$Input`"" | Out-File $file -Append;

    $Input = Read-Host "Enter the working directory for the Distributed Replay Client service. (No trailing slash)";
    "CLTWORKINGDIR=`"$Input`"" | Out-File $file -Append;
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
function ExitMessage()
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
	";SQLSERVER2012 Configuration File" | Out-file $FileNameAddNode -Append
    "" | Out-file $FileNameAddNode -Append
	"[OPTIONS]" | Out-File $FileNameAddNode -Append
    "" | Out-file $FileNameAddNode -Append 
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

function PrintExecCMD()
{
	$ExecCmdPrintOut = "setup.exe /CONFIGURATIONFILE=`"$file`""
    
    IF($Script:IncludeSQL)
    {
        $ExecCmdPrintOut = $ExecCmdPrintOut + " /SQLSVCPASSWORD=`"<enter pwd>`" /AGTSVCPASSWORD=`"<enter pwd>`"";
    }
    IF ($Script:SecChoice -eq "YES")
	{
		$ExecCmdPrintOut = $ExecCmdPrintOut + " /SAPWD=`"<enter pwd>`"";
	}
    IF ($Script:IncludeRS)
	{
		$ExecCmdPrintOut = $ExecCmdPrintOut + " /RSSVCACCOUNT=`"<enter pwd>`"";
	}
    IF ($Script:IncludeAS)
	{
		$ExecCmdPrintOut = $ExecCmdPrintOut + " /ASSVCACCOUNT=`"<enter pwd>`"";
	}
    
    Write-Host ""
    Write-Host $ExecCmdPrintOut
    Write-Host ""
    Read-Host "Press ENTER to exit."
}

function SetReportingInformation ()
{
    $Manual = New-Object System.Management.Automation.Host.ChoiceDescription "&Manual","Selecting manual will set the startup type to manual."
	$Automatic = New-Object System.Management.Automation.Host.ChoiceDescription "&Automatic","Selecting automatic will set the startup type to automatic."
    $Disabled = New-Object System.Management.Automation.Host.ChoiceDescription "&Disabled","Selecting disabled will set the startup type to disabled."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Manual,$Automatic,$Disabled)
	$caption = "Question!"
	$message = "What startup type would you like your Reporting Service set to?"
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    switch ($choice)
    {
        0 { $Input="Manual" }
        1 { $Input="Automatic" }
        2 { $Input="Disabled" }
    }
    "RSSVCSTARTUPTYPE=`"$Input`"" | Out-File $file -Append;

    #Default to files only mode
    "RSINSTALLMODE=`"FilesOnlyMode`"" | Out-File $file -Append;
}

function SetAnalysisInformation ()
{
    $Input = Read-Host "Enter the account used by the Analysis Services (eg. SQL_Latin1_General_CP1_CI_AS):";
    "ASCOLLATION=`"$Input`"" | Out-File $file -Append;

    $Manual = New-Object System.Management.Automation.Host.ChoiceDescription "&Manual","Selecting manual will set the startup type to manual."
	$Automatic = New-Object System.Management.Automation.Host.ChoiceDescription "&Automatic","Selecting automatic will set the startup type to automatic."
    $Disabled = New-Object System.Management.Automation.Host.ChoiceDescription "&Disabled","Selecting disabled will set the startup type to disabled."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Manual,$Automatic,$Disabled)
	$caption = "Question!"
	$message = "What startup type would you like your Analysis Services set to?"
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    switch ($choice)
    {
        0 { $Input="Manual" }
        1 { $Input="Automatic" }
        2 { $Input="Disabled" }
    }
    "ASSVCSTARTUPTYPE=`"$Input`"" | Out-File $file -Append;

    $MULTIDIMENSIONAL = New-Object System.Management.Automation.Host.ChoiceDescription "&MULTIDIMENSIONAL","Selecting multideimensional will set the Analysis Server mode as such."
	$POWERPIVOT = New-Object System.Management.Automation.Host.ChoiceDescription "&POWERPIVOT","Selecting powerpivot will set the Analysis Server mode as such."
    $TABULAR = New-Object System.Management.Automation.Host.ChoiceDescription "&TABULAR","Selecting tabular will set the Analysis Server mode as such."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($MULTIDIMENSIONAL,$POWERPIVOT,$TABULAR)
	$caption = "Question!"
	$message = "What server mode would you like your Analysis Services set to?"
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    switch ($choice)
    {
        0 { $Input="MULTIDIMENSIONAL" }
        1 { $Input="POWERPIVOT" }
        2 { $Input="TABULAR" }
    }
    "ASSERVERMODE=`"$Input`"" | Out-File $file -Append;

    #Choose provider mode
	$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","By selecting yes you will enable the MSOLAP provider to run in-process."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","By selecting no you will disable the MSOLAP provider from running in-process."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to enable the MSOLAP provider to run in-process?"
	$MSOLAPprovider = $Host.UI.PromptForChoice($caption,$message,$choices,0)
		
	switch ($MSOLAPprovider)
	{
		0 { $Script:MSOLAPprovider="YES" }
		1 { $Script:MSOLAPprovider="NO" }
	}
		
	IF ($Script:MSOLAPprovider -eq "YES")
	{
		"ASPROVIDERMSOLAP=`"1`"" | Out-File $file -Append
	}
    else
    {
        "ASPROVIDERMSOLAP=`"0`"" | Out-File $file -Append
    }
}

function SetSQLEngineInformation ()
{
    $Input = Read-Host "Enter the collation that you would like to use for the SQL Engine (eg. SQL_Latin1_General_CP1_CI_AS):"
    "SQLCOLLATION=`"$Input`"" | Out-File $file -Append
}

################
###   Main  ####
################

WelcomeMessage

SetInstallationType

SetFilePath

WriteNonConfigurableOptions

ConfigureInstanceOptions

if($InstallChoice -ne "ADDNODE")
{
    SetFeatures

    if($Script:IncludeSQL) { SetSQLEngineInformation }

    if($Script:IncludeDREPLAY_CTLR) { SetDistributedReplayInformation }

    if($Script:IncludeRS) { SetReportingInformation }

    if($Script:IncludeAS) { SetAnalysisInformation }

    SetFileDirectories
			
    SetSysAdminAccounts 
}

SetServiceAccounts 

if($InstallChoice -eq "INSTALLCLUSTER")
{
    SetClusterDisks

    WriteAddNodeFile
}

ExitMessage
		
PrintExecCMD
