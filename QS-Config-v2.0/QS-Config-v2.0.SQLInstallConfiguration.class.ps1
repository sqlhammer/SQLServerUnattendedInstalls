###################################################################################
###								Help Context									###
###################################################################################

<#
.SYNOPSIS
This script is intended for use within the QS-COnfig-v2.0.ps1 script only. It defines a 
object, QSConfig.SQLInstallConfiguration, which is used for storing and serializing
all of the necessary configurations for a given SQL Server installation.

.DESCRIPTION
This script is intended for use within the QS-COnfig-v2.0.ps1 script only. It defines a 
object, QSConfig.SQLInstallConfiguration, which is used for storing and serializing
all of the necessary configurations for a given SQL Server installation.

.EXAMPLE
. $scriptDir\QS-Config-v2.0.SQLInstallConfiguration.class.ps1; 
$config = Get-SQLInstallConfiguration;

.NOTES
Author: Derik Hammer
Twitter: @SQLHammer
URL: http://www.sqlhammer.com/blog/qs-config/

.INPUTS
None.

.OUTPUTS
None.
#>

function Get-SQLInstallConfiguration ([int]$MajorVersion)
{
    $configurationParameters = New-Module -AsCustomObject `
        -ScriptBlock {
            function SetHeader ([ref]$obj)
            {
                $obj.Value.Header = @();
                $obj.Value.Header += ";File created by: $Creator";
                $obj.Value.Header += ";File creation date: $(Get-Date -UFormat "%Y-%m-%d %H:%M")";
                $obj.Value.Header += '';
                $obj.Value.Header += ";Script to install new SQL Server instance"
                $obj.Value.Header += ";SQL Server $(GetMajorVersionYear) Configuration File"
                $obj.Value.Header += '';
                $obj.Value.Header += "[OPTIONS]"
                $obj.Value.Header += '';
            }

            function FeatureRule-ReportingServices([string[]]$inputFeatures)
            {
                $output = New-OutputObject;

                if ($inputFeatures -contains "RS" -and $inputFeatures -contains "RS_SHP")
                {
                    $output.isValid = $false
                    $output.messages += "Reporting Services Native and SharePoint mode cannot both be included in the same installation."
                }
                
                return $output;
            }

            function FeatureRule-VersionCompatibility([string[]]$inputFeatures)
            {
                $output = New-OutputObject;

                [string[]]$ValidFeatures = @();
                $ValidFeatures += 'SQLENGINE';
                $ValidFeatures += 'REPLICATION';
                $ValidFeatures += 'FULLTEXT';
                $ValidFeatures += 'DQ';
                $ValidFeatures += 'AS';
                $ValidFeatures += 'RS';
                $ValidFeatures += 'RS_SHP';
                $ValidFeatures += 'RS_SHPWFE';
                $ValidFeatures += 'DQC';
                $ValidFeatures += 'CONN';
                $ValidFeatures += 'IS';
                $ValidFeatures += 'BC';
                $ValidFeatures += 'SDK';
                $ValidFeatures += 'BOL';
                $ValidFeatures += 'SSMS';
                $ValidFeatures += 'ADV_SSMS';
                $ValidFeatures += 'DREPLAY_CTLR';
                $ValidFeatures += 'DREPLAY_CLT';
                $ValidFeatures += 'SNAC_SDK';
                $ValidFeatures += 'MDS';
                $ValidFeatures += 'LocalDB';
                $ValidFeatures += 'TOOLS';

                if($MajorSQLVersion -le 11) { $ValidFeatures += 'BIDS'; }

                for($i=0;$i -le $inputFeatures.Length-1;$i++)
                {
                    if([array]::indexof($ValidFeatures,($inputFeatures[$i])) -eq -1)
                    {
                        $output.isValid = $false
                        $output.messages += "$($inputFeatures[$i]) is not a valid feature. Verify compatibility with SQL Server version $MajorSQLVersion"
                    }
                }

                return $output;
            }

            function New-OutputObject ()
            {
                $output = New-Object psobject;
                $output | Add-Member -MemberType NoteProperty -Name isValid -Value $true
                $output | Add-Member -MemberType NoteProperty -Name messages -Value @()

                return $output;
            }

            function IsValidSafeToggle ([bool]$current, [bool]$new)
            {
                #This will flip to $false only. $false cannot be converted to $true.
                if($current) { return $new; }

                return $current;
            }

            function UpdateOutputObject ([psobject]$InputObject, [psobject]$mergeObj)
            {                
                $mergeObj.isValid = IsValidSafeToggle $InputObject.isValid $mergeObj.isValid;
                $mergeObj.messages += $input.messages

                return $mergeObj;
            }

            function ValidateFeatureList ([string[]]$inputFeatures = @())
            {
                $output = New-OutputObject;

                if($inputFeatures.Count -gt 0) { $testFeatureList = $inputFeatures; }
                else { $testFeatureList = $FeatureList; }
                
                $output = UpdateOutputObject $output (FeatureRule-VersionCompatibility $testFeatureList)
                $output = UpdateOutputObject $output (FeatureRule-ReportingServices $testFeatureList)

                return $output;
            }
            
            function GetDelimitedString([string[]]$list, [char]$delimiter = ' ', [string]$wrapper = '"')
            {
                if($list.Length -eq 0) { return $null; }

                [string]$str = '';
                
                for($i=0;$i -lt $list.Length;$i++)
                {
                    $str += "$wrapper$($list[$i])$wrapper";
                    $str += $delimiter;
                }
                
                return $str.Substring(0,$str.Length-1);
            }

            function SetFeatures ([ref]$obj)
            {
                $obj.Value.Features = ($obj.Value.GetDelimitedString($FeatureList, ',', $null));
            }

            function SetFailoverClusterIpAddresses ([ref]$obj)
            {
                $obj.Value.FailoverClusterIpAddresses = ($obj.Value.GetDelimitedString($FailoverClusterIpAddressList));
            }

            function SetSQLSysAdminAccounts ([ref]$obj)
            {
                $obj.Value.SQLSysAdminAccounts = ($obj.Value.GetDelimitedString($SQLSysAdminAccountList));
            }

            function SetASSysAdminAccounts ([ref]$obj)
            {
                $obj.Value.ASSysAdminAccounts = ($obj.Value.GetDelimitedString($ASSysAdminAccountList));
            }

            function GetMajorVersionYear ()
            {
                return (GetSupportedVersions).Get_Item($MajorSQLVersion.ToString());
            }

            function GetSupportedVersions()
            {
                return @{
                            "10" = "2008"; 
                            "11" = "2012"; 
                            "12" = "2014"
                        }
            }

            function Prepare([ref]$obj)
            {
                if(-not (GetSupportedVersions).ContainsKey($MajorSQLVersion.ToString()))
                {
                    throw "QSConfig.SQLInstallConfiguration.MajorSQLVersion is not set to a supported value. Current value: $MajorSQLVersion";
                }
                
                $obj.Value.SetHeader($obj);

                $validateFeatureResult = $obj.Value.ValidateFeatureList()
                if(-not $validateFeatureResult.isValid)
                {
                    #$validateFeatureResult.messages | foreach { Write-Error "VALIDATION ERROR: $_" };
                    throw $validateFeatureResult.messages;
                }

                $obj.Value.SetFeatures($obj);
                $obj.Value.SetFailoverClusterIpAddresses($obj);
                $obj.Value.SetSQLSysAdminAccounts($obj);
                $obj.Value.SetASSysAdminAccounts($obj);
            }

            function GetSerializationExclusions ()
            {
                [string[]]$SerialExclusions = @();
                $SerialExclusions += 'MajorSQLVersion';
                $SerialExclusions += 'Header';
                $SerialExclusions += 'Creator';
                $SerialExclusions += 'FailoverClusterIpAddressList';
                $SerialExclusions += 'FeatureList';
                $SerialExclusions += 'CtlrUserList';
                $SerialExclusions += 'SQLSysAdminAccountList';
                $SerialExclusions += 'ASSysAdminAccountList';
                $SerialExclusions += 'FailoverClusterDisks'; 

                return $SerialExclusions;
            }

            function GetSerializableList ([ref]$obj)
            {
                $SerializableList = $obj.Value | Get-Member | Where-Object { $_.MemberType -eq 'NoteProperty' } `
                                                    | Where-Object { [array]::indexof((GetSerializationExclusions),($_.Name)) -eq -1 } `
                                                    | Sort-Object Name;

                return $SerializableList;
            }
            
            function Serialize ([ref]$obj)
            {
                [string[]]$output = $Header;
                
                $obj.Value.GetSerializableList($obj) | foreach {
                    #write-host $property                    
                    $scriptblock = [scriptblock]::Create("`$obj.Value.$($_.Name)");
                    [string]$value = (& $scriptblock).ToString().ToUpper().Trim();
                    #write-host $value
                    if($value)
                    {
                        $output += "$($($_.Name).ToUpper()) = `"$value`"";
                    }
                }

                return $output;
            }

            function SaveToFile([string]$path, [ref]$obj)
            {
                $dir = (Split-Path $path -Parent);
                if(-not (Test-Path $dir))
                {
                    throw "Invalid directory ($dir). Save was not complete.";
                    return;
                }

                if(Test-Path $path)
                {
                    throw "File already exists ($path). Save was not complete.";
                    return;
                }

                $obj.Value.Serialize($obj) | Out-File $path
            }

            [string]$Creator = '???';
            [int]$MajorSQLVersion = 12;

            [string[]]$Header = @();
            [bool]$IAcceptSQLServerLicenseTerms = $true;
            [bool]$Help = $false;
            [bool]$IndicateProgress = $true;
            [bool]$Quiet = $false;
            [bool]$QuietSimple = $true;
            [bool]$X86 = $false;
            [bool]$ENU = $true;
            [string]$FTSvcAccount = $null;
            [bool]$AddCurrentUserAsSQLAdmin = $true;
            [string]$InstallSharedDir = $null;
            [string]$InstallSharedWOWDir = $null;
            [string]$InstanceDir = $null;
            [bool]$ErrorReporting = $false;
            [bool]$SQMReporting = $false;
            [int]$FileStreamLevel = 0;
            [string]$FileStreamShareName = $null;
            [string]$ISSvcStartupType = $null;
            [string]$ISSvcAccount = $null;
            [string]$SQLCollation = $null;
            [string]$Action = $null;
            [string]$AgtSvcStartupType = $null;
            [string]$SQLSvcStartupType = $null;
            [string]$BrowserSvcStartupType = $null;
            [int]$TCPEnabled = 1;

            [string]$UpdateSource = $null;
            [bool]$UpdateEnabled = $false;
            [string]$InstanceName = $null;
            [string]$InstanceId = $null;
            [string]$FailoverClusterNetworkName = $null;
            [string]$FailoverClusterGroup = $null;
            [string[]]$FailoverClusterIpAddressList = @();
            [string]$FailoverClusterIpAddresses = $null;

            [string[]]$FeatureList = @();
            [string]$Features = $null;
            
            [string[]]$SQLSysAdminAccountList = @();
            [string]$SQLSysAdminAccounts = $null;
            [string]$SecurityMode = $null;
            [string[]]$ASSysAdminAccountList = @();
            [string]$ASSysAdminAccounts = $null;
            [string]$SQLSvcAccount = $null;
            [string]$AgtSvcAccount = $null;
            [string]$RSSvcAccount = $null;
            [string]$ASSvcAccount = $null;

            [string]$InstallSQLDataDir = $null;
            [string]$SQLUserDbDir = $null;
            [string]$SQLUserDbLogDir = $null;
            [string]$SQLtempdbDir = $null;
            [string]$SQLBackupDir = $null;
            [string]$ASConfigDir = $null;
            [string]$ASDataDir = $null;
            [string]$ASLogDir = $null;
            [string]$ASTempDir = $null;
            [string]$ASBackupDir = $null;

            [string]$CltCtlrName = $null;
            [string[]]$CtlrUserList = @();
            [string]$CtlrUsers = $null;
            [string]$CtlrSvcAccount = $null;
            [string]$CtlrStartupType = $null;
            [string]$CltSvcAccount = $null;
            [string]$CltStartupType = $null;
            [string]$CltResultDir = $null;
            [string]$CltWorkingDir = $null;

            [string[]]$FailoverClusterDisks = @();

            [string]$RsSvcStartupType = $null;
            [string]$RSInstallMode = $null;

            [string]$ASCollation = $null;
            [string]$ASSvcStartupType = $null;
            [string]$ASServerMode = $null;
            [int]$ASProviderMSOLAP = 1;

            [string]$SQLCollation = $null;

            Export-ModuleMember -Variable * -Function *;
        }

    $configurationParameters.MajorSQLVersion = $MajorVersion;
    $configurationParameters.PSTypeNames.Insert(0,'QSConfig.SQLInstallConfiguration');

    return $configurationParameters;
}


<#Debugging
function test-qsconfig
{
cls
. .\QSConfig.SQLInstallConfiguration.class.ps1
$a = Get-SQLInstallConfiguration(12)
$a.creator = 'derik'
$a.FeatureList += 'TOOLS'
$a.FeatureList += 'SQLENGINE'
$a.FeatureList += 'AS'
#$a.ValidateFeatureList();
$a.Prepare([ref]$a);
$a.Features
$a.MajorSQLVersion;
#$a.GetSerailizableList([ref]$a)
$a.Serialize([ref]$a);
#$a.SaveToFile("C:\Users\Derik\Documents\GitHub\SQLServerUnattendedInstalls\SQL-Server-12\test_$(Get-Date -UFormat "%Y%m%d_%H%M").txt", [ref]$a);
#$a.Header
#$a.featurestring
}

#>


