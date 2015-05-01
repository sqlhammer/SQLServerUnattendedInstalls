#TODO: Consider how default values affect the add node config when serializing all non-null attributes.

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

            function ValidateFeatureList ([string[]]$inputFeatures = @())
            {
                [bool]$isValid = $true;

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

                [string[]]$testFeatureList = @();
                if($inputFeatures.Count -gt 0)
                {
                    $testFeatureList = $inputFeatures;
                }
                else
                {
                    $testFeatureList = $FeatureList;
                }
                
                for($i=0;$i -le $testFeatureList.Length-1;$i++)
                {
                    if([array]::indexof($ValidFeatures,($testFeatureList[$i])) -eq -1)
                    {
                        $isValid = $false;
                    }
                }

                return $isValid;
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

                if(-not $obj.Value.ValidateFeatureList())
                {
                    throw 'Feature validation failed!';
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

            function GetSerailizableList ([ref]$obj)
            {
                [string[]]$SerializableList = ($obj.Value | Get-Member | Where-Object { $_.MemberType -eq 'NoteProperty' } `
                                                    | Where-Object { [array]::indexof((GetSerializationExclusions),($_.Name)) -eq -1 } `
                                                    | Sort-Object Name).Name;

                return $SerializableList;
            }

            function Serialize ([ref]$obj)
            {
                [string[]]$output = $Header;
                foreach($property in $obj.Value.GetSerailizableList($obj))
                {
                    #write-host $property                    
                    $scriptblock = [scriptblock]::Create("`$obj.Value.$property");
                    [string]$value = (& $scriptblock).ToString().ToUpper().Trim();
                    #write-host $value
                    if($value)
                    {
                        $output += "$($property.ToUpper()) = `"$value`"";
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
cls
$a = Get-SQLInstallConfiguration(12)
$a.creator = 'derik'
#$a.Features += 'derik'
$a.FeatureList += 'SQLENGINE'
$a.FeatureList += 'DQ'
$a.FeatureList += 'TOOLS'
#$a.ValidateFeatureList();
$a.ASSysAdminAccountList += "DOMAIN\FakeFoo"
$a.ASSysAdminAccountList += "DOMAIN\FakeFoo2"
$a.Prepare([ref]$a);
$a.MajorSQLVersion;
#$a.GetSerailizableList([ref]$a)
$a.Serialize([ref]$a);
#$a.SaveToFile("C:\Users\Derik\Documents\GitHub\SQLServerUnattendedInstalls\SQL-Server-12\test_$(Get-Date -UFormat "%Y%m%d_%H%M").txt", [ref]$a);
#$a.Header
#$a.featurestring
#>

