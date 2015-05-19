

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
installation of MS SQL Server 2014 as a Stand-A-Lone Instance or a Windows Fail-Over Cluster.

.DESCRIPTION
This script is designed to be a start to finish solution for unattended or silent installations
of MS SQL Server 2014. It will walk you through a number of questions specific to the server or cluster 
that you are installing this instance on and then create the necessary configuration.ini files. 
Your template file will be saved to a location of your choice.

.EXAMPLE
.\Silent_Install_SQL12.ps1

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

#load windows form assembly
[reflection.assembly]::loadwithpartialname('system.windows.forms') | Out-Null; 

#Instantiates a new com object we'll use for choosing folders
$object = New-Object -comObject Shell.Application

#Instantiates a new QSConfig.SQLInstallConfiguration object
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. $scriptDir\QSConfig.SQLInstallConfiguration.class.ps1; 
$Script:config = Get-SQLInstallConfiguration;

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
	$Version10 = New-Object System.Management.Automation.Host.ChoiceDescription "1&0 (2008/2008 R2)","By selecting this option you will use configurations for SQL Server 2008/2008 R2."
	$Version11 = New-Object System.Management.Automation.Host.ChoiceDescription "1&1 (2012)","By selecting this option you will use configurations for SQL Server 2012."
    $Version12 = New-Object System.Management.Automation.Host.ChoiceDescription "1&2 (2014)","By selecting this option you will use configurations for SQL Server 2014."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Version10,$Version11,$Version12)
	$caption = "Question!"
	$message = "What version of SQL Server are you looking to install?"
	$VersionChoice = $Host.UI.PromptForChoice($caption,$message,$choices,2)

	switch ($VersionChoice)
	{
		0 {$config.MajorSQLVersion = 10}
		1 {$config.MajorSQLVersion = 11}
		2 {$config.MajorSQLVersion = 12}
        default { $Script:MajorSQLVersion = 0 }
	}

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
    #Common default settings
    $config.Creator = $FileCreator;
    $config.X86 = $false;
    $config.AddCurrentUserAsSQLAdmin = $false;	

    if (($InstallChoice -eq "STANDALONEINSTALL") -or ($InstallChoice -eq "INSTALLCLUSTER"))
    {
        #Install specific settings
	    if ($InstallChoice -eq "STANDALONEINSTALL")
	    {
		    #Installing new server
            $config.Action = 'Install';
		    
		    #Default settings
            $config.AgtSvcStartupType = 'Automatic';
            $config.SQLSvcStartupType = 'Automatic';
		    $config.BrowserSvcStartupType = 'Automatic';
		    $config.TCPEnabled = 1;
	    }
        elseif ($InstallChoice -eq "INSTALLCLUSTER")
        {
            #Installing new cluster
            $config.Action = 'InstallFailoverCluster';
        }
    }
    elseif ($InstallChoice -eq "ADDNODE")
    {
        #Adding a new node
        $config.Action = 'AddNode';
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
        $UpdatePath = Read-Host "Where would you like your updates to come from? Input `"MU`" for Microsoft Updates or a directory path"

        $config.UpdateSource = $UpdatePath;
        $config.UpdateEnabled = $true;
	}
	else
	{
		$config.UpdateEnabled = $false;
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
                $config.InstanceName = $SQLInstanceName;
				$config.InstanceId = $SQLInstanceName;
			}
			else
			{
				$SQLInstanceName = Read-Host "Enter the SQL instance name
	ie: CLDB001A"
				$Script:SQLInstanceName = $SQLInstanceName.ToUpper()
                $config.InstanceName = $SQLInstanceName;
				$config.InstanceId = $SQLInstanceName;
			}
		}
		"INSTALLCLUSTER"
		{
			#SQL Virtual Name
			$SQLVirtualName = read-host "Enter the SQL virtual network name
	ie: CL-DB-001-A"
			$Script:SQLVirtualName = $SQLVirtualName.ToUpper()
            $config.FailoverClusterNetworkName = $SQLVirtualName;
				
			#SQL Instance Name (will also use for Instance ID and failover cluster group)
			$SQLInstanceName = Read-Host "Enter the SQL instance name
	ie: CLDB001A"
			$Script:SQLInstanceName = $SQLInstanceName.ToUpper()
            $config.InstanceName = $SQLInstanceName;
			$config.InstanceId = $SQLInstanceName;
            $config.FailoverClusterGroup = $SQLVirtualName;

			#IPAddress (running IPV4 only)
            $ClusterNetworkName = Read-Host "Enter the Cluster Network Name (ie. Cluster Network 1)"
			$IPAddress = Read-Host "Enter the IP Address (IPv4 only)"
            $Subnet = Read-Host "Enter the subnet"
            $config.FailoverClusterIpAddressList += "IPv4;$IPAddress;$ClusterNetworkName;$Subnet";
		}
		"ADDNODE"
		{
			#SQL Virtual Name
			$SQLVirtualName = read-host "Enter the SQL virtual network name
			ie: CL-DB-001-A"
			$Script:SQLVirtualName = $SQLVirtualName.ToUpper()
            $config.FailoverClusterNetworkName = $SQLVirtualName;

			#SQL Instance Name (will also use for Instance ID and failover cluster group)
			$SQLInstanceName = Read-Host "Enter the SQL instance name
			ie: CLDB001A"
			$Script:SQLInstanceName = $SQLInstanceName.ToUpper()
            $config.InstanceName = $SQLInstanceName;
            $config.FailoverClusterGroup = $SQLVirtualName;
		}
		default
		{
			Write-Error "Installation choice not recognized."
		}
	}
}

function AcceptFeatures($CheckedListBox)
{
    #validate entry
    if(($CheckedListBox -eq $null) -or ($CheckedListBox.CheckedItems.Count -eq 0))
    {
        [Windows.Forms.MessageBox]::Show("You must select at least one feature.", "No feature selected", [Windows.Forms.MessageBoxButtons]::OK)
    }
    else
    {
        foreach ($item in $CheckedListBox.CheckedItems)
        {
            $Script:FeatureHash.Set_Item($item.ToString(), $true);

            switch ($item.ToString())
            {
                "Database engine" {$config.FeatureList += "SQLENGINE"}
                "Replication" {$config.FeatureList += "REPLICATION"}
                "Full-text and semantic extractions for search" {$config.FeatureList += "FULLTEXT"}
                "Data quality services" {$config.FeatureList += "DQ"}
                "Analysis services" {$config.FeatureList += "AS"}
                "Reporting services - native" {$config.FeatureList += "RS"}
                "Reporting services - sharepoint" {$config.FeatureList += "RS_SHP"}
                "Reporting services add-in for sharepoint products" {$config.FeatureList += "RS_SHPWFE"}
                "Data quality client" {$config.FeatureList += "DQC"}
                "All Tools" {$config.FeatureList += "TOOLS"}
                "Business Intelligence Development Studio" {$config.FeatureList += "BIDS"}
                "Client tools connectivity" {$config.FeatureList += "CONN"}
                "Integration services" {$config.FeatureList += "IS"}
                "Client tools backwards compatibility" {$config.FeatureList += "BC"}
                "Client tools SDK" {$config.FeatureList += "SDK"}
                "Documentation components" {$config.FeatureList += "BOL"}
                "Management tools - basic" {$config.FeatureList += "SSMS"}
                "Management tools - advanced" {$config.FeatureList += "ADV_SSMS"}
                "Distributed replay controller" {$config.FeatureList += "DREPLAY_CTLR"}
                "Distributed replay client" {$config.FeatureList += "DREPLAY_CLT"}
                "SQL client connectivity SDK" {$config.FeatureList += "SNAC_SDK"}
                "Master data services" {$config.FeatureList += "MDS"}
                "LocalDb" {$config.FeatureList += "LocalDb"}
                default {Write-Host "Selected feature (" + $item.ToString() + ") not recognized. Debug script."}
            }
        }

        $FeatureForm.Close() | Out-Null;
    }
}

function InitializeFeatureList([REF]$CheckedListBox)
{
    [hashtable]$Script:FeatureHash = @{};
    $Script:FeatureHash.Add("Database engine", $false);    
    $Script:FeatureHash.Add("Replication", $false);
    $Script:FeatureHash.Add("Full-text and semantic extractions for search", $false);
    $Script:FeatureHash.Add("Data quality services", $false);
    $Script:FeatureHash.Add("Analysis services", $false);
    $Script:FeatureHash.Add("Reporting services - native", $false);
    $Script:FeatureHash.Add("Reporting services - sharepoint", $false);
    $Script:FeatureHash.Add("Reporting services add-in for sharepoint products", $false);
    $Script:FeatureHash.Add("Data quality client", $false);
    $Script:FeatureHash.Add("All Tools", $false);
    $Script:FeatureHash.Add("Business Intelligence Development Studio", $false);
    $Script:FeatureHash.Add("Client tools connectivity", $false);
    $Script:FeatureHash.Add("Integration services", $false);
    $Script:FeatureHash.Add("Client tools backwards compatibility", $false);
    $Script:FeatureHash.Add("Client tools SDK", $false);
    $Script:FeatureHash.Add("Documentation components", $false);
    $Script:FeatureHash.Add("Management tools - basic", $false);
    $Script:FeatureHash.Add("Management tools - advanced", $false);
    $Script:FeatureHash.Add("Distributed replay controller", $false);
    $Script:FeatureHash.Add("Distributed replay client", $false);
    $Script:FeatureHash.Add("SQL client connectivity SDK", $false);
    $Script:FeatureHash.Add("Master data services", $false);
    $Script:FeatureHash.Add("LocalDb", $false);

    # Set the list items here to centralize a location for changing the feature list
    if ($CheckedListBox -ne $null)
    {
        $a = $config.ValidateFeatureList("SQLENGINE").isValid

        if($config.ValidateFeatureList("SQLENGINE").isValid) { $CheckedListBox.Value.Items.Add("Database engine") | Out-Null; }
        if($config.ValidateFeatureList("REPLICATION").isValid) { $CheckedListBox.Value.Items.Add("Replication") | Out-Null; }
        if($config.ValidateFeatureList("FULLTEXT").isValid) { $CheckedListBox.Value.Items.Add("Full-text and semantic extractions for search") | Out-Null; }
        if($config.ValidateFeatureList("DQ").isValid) { $CheckedListBox.Value.Items.Add("Data quality services") | Out-Null; }
        if($config.ValidateFeatureList("AS").isValid) { $CheckedListBox.Value.Items.Add("Analysis services") | Out-Null; }
        if($config.ValidateFeatureList("RS").isValid) { $CheckedListBox.Value.Items.Add("Reporting services - native") | Out-Null; }
        if($config.ValidateFeatureList("RS_SHP").isValid) { $CheckedListBox.Value.Items.Add("Reporting services - sharepoint") | Out-Null; }
        if($config.ValidateFeatureList("RS_SHPWFE").isValid) { $CheckedListBox.Value.Items.Add("Reporting services add-in for sharepoint products") | Out-Null; }
        if($config.ValidateFeatureList("DQC").isValid) { $CheckedListBox.Value.Items.Add("Data quality client") | Out-Null; }
        if($config.ValidateFeatureList("TOOLS").isValid) { $CheckedListBox.Value.Items.Add("All Tools") | Out-Null; }
        if($config.ValidateFeatureList("CONN").isValid) { $CheckedListBox.Value.Items.Add("Client tools connectivity") | Out-Null; }
        if($config.ValidateFeatureList("IS").isValid) { $CheckedListBox.Value.Items.Add("Integration services") | Out-Null; }
        if($config.ValidateFeatureList("BC").isValid) { $CheckedListBox.Value.Items.Add("Client tools backwards compatibility") | Out-Null; }
        if($config.ValidateFeatureList("SDK").isValid) { $CheckedListBox.Value.Items.Add("Client tools SDK") | Out-Null; }
        if($config.ValidateFeatureList("BOL").isValid) { $CheckedListBox.Value.Items.Add("Documentation components") | Out-Null; }
        if($config.ValidateFeatureList("SSMS").isValid) { $CheckedListBox.Value.Items.Add("Management tools - basic") | Out-Null; }
        if($config.ValidateFeatureList("ADV_SSMS").isValid) { $CheckedListBox.Value.Items.Add("Management tools - advanced") | Out-Null; }
        if($config.ValidateFeatureList("DREPLAY_CTLR").isValid) { $CheckedListBox.Value.Items.Add("Distributed replay controller") | Out-Null; }
        if($config.ValidateFeatureList("DREPLAY_CLT").isValid) { $CheckedListBox.Value.Items.Add("Distributed replay client") | Out-Null; }
        if($config.ValidateFeatureList("SNAC_SDK").isValid) { $CheckedListBox.Value.Items.Add("SQL client connectivity SDK") | Out-Null; }
        if($config.ValidateFeatureList("LocalDB").isValid) { $CheckedListBox.Value.Items.Add("LocalDb") | Out-Null; }
        if($config.ValidateFeatureList("MDS").isValid) { $CheckedListBox.Value.Items.Add("Master data services") | Out-Null; }
        if($config.ValidateFeatureList("BIDS").isValid) { $CheckedListBox.Value.Items.Add("Business Intelligence Development Studio") | Out-Null; }
    }
}

function SetFeatures()
{
    # Create a Form
    $FeatureForm = New-Object -TypeName System.Windows.Forms.Form;
    $FeatureForm.Width = 345;
    $FeatureForm.Height = 404;
    $FeatureForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog;
    $FeatureForm.StartPosition = "CenterScreen";
    $FeatureForm.MaximizeBox = $false;
    $FeatureForm.Text = "Feature selection";
    # Create a CheckedListBox
    $CheckedListBox = New-Object -TypeName System.Windows.Forms.CheckedListBox;
    # Add the CheckedListBox to the Form
    $FeatureForm.Controls.Add($CheckedListBox);
    # Widen the CheckedListBox
    $CheckedListBox.Width = 325;
    $CheckedListBox.Height = 340;
    $CheckedListBox.Left = 5;
    $CheckedListBox.Top = 5;
    $CheckedListBox.CheckOnClick = $true
    #Create button
    $OKButton = New-Object -TypeName System.Windows.Forms.Button;
    $OKButton.Text = "Accept";
    $OKButton.Top = $CheckedListBox.Top + $CheckedListBox.Height + 2;
    $OKButton.Left = ($FeatureForm.Width / 2) - ($OKButton.Width / 2);
    $OKButton.add_Click({AcceptFeatures $CheckedListBox});
    #Add button
    $FeatureForm.Controls.Add($OKButton);

    # Add the CheckedListBox to the Form
    InitializeFeatureList ([REF]$CheckedListBox)
    $FeatureForm.Controls.Add($CheckedListBox);

    # Clear all existing selections
    $CheckedListBox.ClearSelected();

    # Show the form
    $FeatureForm.ShowDialog();
}

function SetSysAdminAccounts()
{
    if($config.FeatureList -contains "SQLENGINE")
    {
	    #SET SYSADMIN ACCOUNT HERE
	    $AcctList = (read-host "Enter a comma delimited list of sysadmin accounts for this instance
	    eg DOMAIN\Database Administration, DOMAIN\Account2").split(",")

	    foreach ($Acct in $AcctList)
		{
		    $config.SQLSysAdminAccountList += $Acct.Trim()
	    }

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
            $config.SecurityMode = 'SQL';
	    }
    }

    if($config.FeatureList -contains "AS")
    {
        $AcctList = (read-host "Enter a comma delimited list of sysadmin accounts for the Analysis Services
	    eg DOMAIN\Database Administration, DOMAIN\Account2").split(",")

	    foreach ($Acct in $AcctList)
		{
		    $config.ASSysAdminAccountList += $Acct.Trim()
	    }
    }
}

#Set service accounts
function SetServiceAccounts()
{
	#Choose service accounts
    if($config.FeatureList -icontains "SQLENGINE")
    {
	    $Script:SQLServiceAccount = Read-Host "Enter the SQL Service account to be used"
        $config.SQLSvcAccount = $SQLServiceAccount;
	    $Script:SQLAgentAccount = Read-Host "Enter the SQL Agent account to be used"
        $config.AgtSvcAccount = $SQLAgentAccount;
    }

    if($config.FeatureList -icontains "RS")
    {
        $Script:RSAccount = Read-Host "Enter the SQL Server Reporting Services account to be used"
        $config.RSSvcAccount = $Script:RSAccount;
    }

    if($config.FeatureList -icontains "AS")
    {
        $Script:ASAccount = Read-Host "Enter the SQL Server Analysis Services account to be used"
        $config.ASSvcAccount = $Script:ASAccount;
    }

    if($config.FeatureList -icontains "IS")
    {
        $Script:ISAccount = Read-Host "Enter the SQL Server Integration services account to be used"
        $config.ISSvcAccount = $Script:ISAccount;
    }

    if($config.FeatureList -icontains "FullText")
    {
        $Script:FTAccount = Read-Host "Enter the SQL Server Full-text service account to be used"
        $config.FTSvcAccount = $Script:FTAccount;
    }
}

function SetFileDirectories()
{
    [string]$VersionString = ([string]$MajorSQLVersion).Replace(".", "_");

    #SQL binaries location (in this case to C: I usually use D:)
	$config.InstallSharedDir = 'C:\Program Files\Microsoft SQL Server'
    $config.InstallSharedWOWDir = 'C:\Program Files (x86)\Microsoft SQL Server'
	$config.InstanceDir = 'C:\Program Files\Microsoft SQL Server'

    $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Selecting yes will use default installation directories."
	$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Selecting no will spawn additional prompts for custom install directories."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Yes,$No)
	$caption = "Question!"
	$message = "Would you like to use the default installation directories for the SQL Server binaries?"
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    if($choice -eq 1)
    {
        $config.InstallSQLDataDir = Read-Host "Select directory for the SQL Server binaries (Do not include the trailing '\')
	    eg. J: or C:\Program Files\Microsoft SQL Server"
	    
	    $config.InstallSharedWOWDir = Read-Host "Select directory for the SQL Server 32-bit binaries (Do not include the trailing '\')
	    eg. J: or C:\Program Files (x86)\Microsoft SQL Server"

	    $config.InstanceDir = Read-Host "Select directory for SQL Server instance files (Do not include the trailing '\')
	    eg. J: or C:\Program Files\Microsoft SQL Server"
    }
    
    if($config.FeatureList -contains "SQLENGINE")
    {
	    #System databases
	    $SysDBfolder = Read-Host "Select directory for SQL SYSTEM databases (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\SystemDBs"
	    $config.InstallSQLDataDir = $SysDBfolder;

	    #Default User DB location
	    $UserDBfolder = Read-Host "Select directory for USER DATABASE DATA files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\UserData"
	    $config.SQLUserDbDir = $UserDBfolder;

	    #Default User Log location
	    $UserLogfolder = Read-Host "Select directory for USER DATABASE LOG files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\UserLogs"
	    $config.SQLUserDbLogDir = $UserLogfolder;
	
	    #TempDB
	    $TempDBfolder = Read-Host "Select directory for SQL TempDB (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\tempdbData"
	    $config.SQLtempdbDir = $TempDBfolder;

	    #Default backup location
	    $Backupfolder = Read-Host "Select directory for DATABASE BACKUPS (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\Backup"
	    $config.SQLBackupDir = $Backupfolder;
    }

    if($config.FeatureList -contains "AS")
    {
	    #Config databases
	    $Configfolder = Read-Host "Select directory for SSAS config files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\AnalysisServicesConfig"
	    $config.ASConfigDir = $ConfigDir;

	    #Default DATA location
	    $DataFolder = Read-Host "Select directory for SSAS DATA files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\AnalysisServicesData"
	    $config.ASDataDir = $DataDir;

	    #Default Log location
	    $Logfolder = Read-Host "Select directory for SSAS LOG files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\AnalysisServicesLogs"
	    $config.ASLogDir = $LogDir;
	
	    #Temp
	    $Tempfolder = Read-Host "Select directory for SSAS Temp files (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\AnalysisServicesTemp"
	    $config.ASTempDir = $TempDir;

	    #Default backup location
	    $Backupfolder = Read-Host "Select directory for SSAS BACKUPS (Do not include the trailing '\')
	    eg. J: or J:\SQLServer\AnalysisServicesBackup"
	    $config.ASBackupDir = $Backup;
    }
}

function SetDistributedReplayInformation()
{
    $Input = Read-Host "Enter the computer name that the client communicates with for the Distributed Replay Controller service.";
    $config.CltCtlrName = $Input;

    $InputList = (Read-Host "Enter the Windows account(s) used to grant permission to the Distributed Replay Controller service.
    eg DOMAIN\Database Administration, DOMAIN\Account2").split(",");

	foreach ($Acct in $InputList)
	{
		$config.CtlrUserList += $Acct.Trim();
	}

    $Input = Read-Host "Enter the account used by the Distributed Replay Controller Service.
    eg NT Service\SQL Server Distributed Replay Controller";
    $config.CtlrSvcAccount = $Input;

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
    $config.CtlrStartupType = $Input;

    $Input = Read-Host "Enter the account used by the Distributed Replay Client Service.
    eg NT Service\SQL Server Distributed Replay Client";
    $config.CltSvcAccount = $Input;

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
    $config.CltStartupType = $Input;

    $Input = Read-Host "Enter the result directory for the Distributed Replay Client service. (No trailing slash)";
    $config.CltResultDir = $Input;

    $Input = Read-Host "Enter the working directory for the Distributed Replay Client service. (No trailing slash)";
    $config.CltWorkingDir = $Input;
}

function SetClusterDisks()
{
	$DiskList = (read-host "Enter a comma delimited list of failover cluster disks for use in this cluster
	eg SQL Data, SQL Log, SQL Backup").split(",")

	foreach ($Disk in $DiskList)
	{
		$config.FailoverClusterDisks += $Disk.Trim();
	}
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
    $addNodeConfig = Get-SQLInstallConfiguration;

    $addNodeConfig.Creator = $config.Creator;
    $addNodeConfig.MajorSQLVersion = $config.MajorSQLVersion;

	$addNodeConfig.Action = 'AddNode';
    $addNodeConfig.X86 = $config.X86;	
	$addNodeConfig.FTSvcAccount = $FTAccount;
	$addNodeConfig.SQLSvcAccount = $SQLServiceAccount;
    $addNodeConfig.AgtSvcAccount = $SQLAgentAccount;
	$addNodeConfig.FailoverClusterNetworkName = $SQLVirtualName;
    $addNodeConfig.InstanceName = $SQLInstanceName;
    $addNodeConfig.FailoverClusterGroup = $SQLVirtualName;

    $addNodeConfig.Prepare([ref]$addNodeConfig);
    $addNodeConfig.SaveToFile($FileNameAddNode, [ref]$addNodeConfig);
}

function PrintExecCMD()
{
	$ExecCmdPrintOut = "setup.exe /CONFIGURATIONFILE=`"$file`""
    
    if($config.FeatureList -contains "SQLENGINE")
    {
        $ExecCmdPrintOut = $ExecCmdPrintOut + " /SQLSVCPASSWORD=`"<enter pwd>`" /AGTSVCPASSWORD=`"<enter pwd>`"";
    }
    if ($Script:SecChoice -eq "YES")
	{
		$ExecCmdPrintOut = $ExecCmdPrintOut + " /SAPWD=`"<enter pwd>`"";
	}
    if (($config.FeatureList -contains "RS") -or ($config.FeatureList -contains "RS_SHP"))
	{
		$ExecCmdPrintOut = $ExecCmdPrintOut + " /RSSVCACCOUNT=`"<enter pwd>`"";
	}
    if ($config.FeatureList -contains "AS")
	{
		$ExecCmdPrintOut = $ExecCmdPrintOut + " /ASSVCACCOUNT=`"<enter pwd>`"";
	}
    if ($config.FeatureList -contains "IS")
	{
		$ExecCmdPrintOut = $ExecCmdPrintOut + " /ISSVCACCOUNT=`"<enter pwd>`"";
	}
    
    Write-Host ""
    Write-Host $ExecCmdPrintOut
    Write-Host ""
    Read-Host "Press ENTER to exit"
}

function SetReportingInformation ()
{
    if($config.FeatureList -contains "RS")
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
        $config.RsSvcStartupType = $Input;

        #Default to files only mode
        $config.RSInstallMode = 'FilesOnlyMode';
    }

    if($config.FeatureList -contains "RS_SHP")
    {
        #Default to files only mode
        $config.RSInstallMode = 'SharePointFilesOnlyMode';
    }
}

function SetIntegrationInformation ()
{
    $Manual = New-Object System.Management.Automation.Host.ChoiceDescription "&Manual","Selecting manual will set the startup type to manual."
	$Automatic = New-Object System.Management.Automation.Host.ChoiceDescription "&Automatic","Selecting automatic will set the startup type to automatic."
    $Disabled = New-Object System.Management.Automation.Host.ChoiceDescription "&Disabled","Selecting disabled will set the startup type to disabled."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($Manual,$Automatic,$Disabled)
	$caption = "Question!"
	$message = "What startup type would you like your Integration Services set to?"
	$choice = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    switch ($choice)
    {
        0 { $Input="Manual" }
        1 { $Input="Automatic" }
        2 { $Input="Disabled" }
    }
    $config.ISSvcStartupType = $Input;
}

function SetAnalysisInformation ()
{
    $Input = Read-Host "Enter the account used by the Analysis Services (eg. SQL_Latin1_General_CP1_CI_AS)";
    $config.ASCollation = $Input;

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
    $config.ASSvcStartupType = $Input;

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
    $config.ASServerMode = $Input;

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
        $config.ASProviderMSOLAP = 1;
	}
    else
    {
        $config.ASProviderMSOLAP = 0;
    }
}

function SetSQLEngineInformation ()
{
    $Input = Read-Host "Enter the collation that you would like to use for the SQL Engine (eg. SQL_Latin1_General_CP1_CI_AS)"
    $config.SQLCollation = $Input;

    #Choose filestream mode
	$zero = New-Object System.Management.Automation.Host.ChoiceDescription "&0","Disable FILESTREAM support for this instance."
	$one = New-Object System.Management.Automation.Host.ChoiceDescription "&1","Enable FILESTREAM for Transact-SQL access."
    $two = New-Object System.Management.Automation.Host.ChoiceDescription "&2","Enable FILESTREAM for Transact-SQL and file I/O streaming access. (Not valid for cluster scenarios)"
    $three = New-Object System.Management.Automation.Host.ChoiceDescription "&3","Allow remote clients to have streaming access to FILESTREAM data."
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($zero,$one,$two,$three);
	$caption = "Question!"
	$message = "Specify the access level for the FILESTREAM feature."
	$FileStreamAccessLevel = $Host.UI.PromptForChoice($caption,$message,$choices,0)

    switch ($FileStreamAccessLevel)
	{
		0 { $config.FileStreamLevel = 0; }
		1 { $config.FileStreamLevel = 1; }
        2 { $config.FileStreamLevel = 2; }
        3 { $config.FileStreamLevel = 3; }
	}

    if (($config.FileStreamLevel -eq 2) -or ($config.FileStreamLevel -eq 3))
    {
        $Input = Read-Host "Enter the filestream share that you would like to use:"
        $config.FileStreamShareName = $Input;
    }
}

function WriteConfigFile ()
{
    $config.Prepare([ref]$config);
    $config.SaveToFile($file, [ref]$config);
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

    if($config.FeatureList -contains "SQLENGINE") { SetSQLEngineInformation }

    if($config.FeatureList -contains "DREPLAY_CTLR") { SetDistributedReplayInformation }

    if (($config.FeatureList -contains "RS") -or ($config.FeatureList -contains "RS_SHP"))
        { SetReportingInformation }

    if($config.FeatureList -contains "AS") { SetAnalysisInformation }

    if($config.FeatureList -contains "IS") { SetIntegrationInformation }

    SetFileDirectories
			
    SetSysAdminAccounts 
}

SetServiceAccounts 

if($InstallChoice -eq "INSTALLCLUSTER")
{
    SetClusterDisks

    WriteAddNodeFile
}

WriteConfigFile

ExitMessage
		
PrintExecCMD

