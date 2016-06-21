﻿$ConfigData = @{
                AllNodes = @(
                @{
                    NodeName = "*"
                    Domain = "blah.com"
                    DCDatabasePath = "C:\NTDS"
                    DCLogPath = "C:\NTDS"
                    SysvolPath = "C:\Sysvol" 
                },
                @{
                    NodeName = "DC1"
                    Role = "AD_ADCS"
                    PSDSCAllowPlainTextPassword = $True
                    PSDSCAllowDomainUser = $True
                    DomainDN = "dc=blah,dc=com"
                },
                @{
                    NodeName = "Pull"
                    Role = "PullServer"
                }
            )
        }

Configuration LabInfraBuild {

param (
    [parameter(Mandatory=$True)]
    [pscredential]$EACredential,

    [parameter(Mandatory=$True)]
    [pscredential]$SafeModeAdminPW
    )

    import-DSCresource -ModuleName PSDesiredStateConfiguration,@{ModuleName="xActiveDirectory";ModuleVersion="2.11.0.0"},@{ModuleName="XADCSDeployment";ModuleVersion="1.0.0.1"}

    node $AllNodes.NodeName
    {
       
        WindowsFeature ServerCore
        {
            Ensure = "Absent"
            Name = "User-Interfaces-Infra"
            IncludeAllSubFeature = $false
        } 

#region - firewall rules

        script vmpingFWRule 
        {
            TestScript = {
                            $FW = Get-NetFirewallRule | Where-Object {$_.Name -match "vm-monitoring-icmpv4"} 
                            if ($FW.Enabled -eq $False) {return $False} else {return $True}
                         }
            SetScript = 
                         { 
                            Get-NetFirewallRule | Where-Object {$_.Name -match "vm-monitoring-icmpv4"} | Enable-NetFirewallRule
                         }
            GetScript =  {
                            $result = (Get-NetFirewallRule | Where-Object {$_.Name -match "vm-monitoring-icmpv4"})
                            return @{Result = $result}
                         }
        }
        
        script SMBFWRule 
        {
            TestScript = {
                            $FW = Get-NetFirewallRule | Where-Object {$_.Name -match "FPS-SMB-In-TCP"} 
                            if ($FW.Enabled -eq $False) {return $False} else {return $True}
                         }
            SetScript = 
                         { 
                            Get-NetFirewallRule | Where-Object {$_.Name -match "FPS-SMB-In-TCP"} | Enable-NetFirewallRule
                         }
            GetScript =  {
                            $result = (Get-NetFirewallRule | Where-Object {$_.Name -match "FPS-SMB-In-TCP"})
                            return @{Result = $result}
                         }
        }       
        
        script RemoteEvtLogFWRule1 
        {
            TestScript = {
                            $FW = Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-In-TCP"} 
                            if ($FW.Enabled -eq $False) {return $False} else {return $True}
                         }
            SetScript = 
                         { 
                            Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-In-TCP"} | Enable-NetFirewallRule
                         }
            GetScript =  {
                            $result = (Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-In-TCP"})
                            return @{Result = $result}
                         }
        }   
        
        script RemoteEvtLogFWRule2 
        {
            TestScript = {
                            $FW = Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-NP-In-TCP"} 
                            if ($FW.Enabled -eq $False) {return $False} else {return $True}
                         }
            SetScript = 
                         { 
                            Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-NP-In-TCP"} | Enable-NetFirewallRule
                         }
            GetScript =  {
                            $result = (Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-NP-In-TCP"})
                            return @{Result = $result}
                         }
        }          
        
        script RemoteEvtLogFWRule3 
        {
            TestScript = {
                            $FW = Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-RPCSS-In-TCP"} 
                            if ($FW.Enabled -eq $False) {return $False} else {return $True}
                         }
            SetScript = 
                         { 
                            Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-RPCSS-In-TCP"} | Enable-NetFirewallRule
                         }
            GetScript =  {
                            $result = (Get-NetFirewallRule | Where-Object {$_.Name -match "RemoteEventLogSvc-RPCSS-In-TCP"})
                            return @{Result = $result}
                         }
        }   

 #end region - firewall rules                                                                     

    }
    
    node $AllNodes.Where{$_.Role -eq "AD_ADCS"}.NodeName {
        
        WindowsFeature ADDS
        {
           Ensure = "Present"
           Name   = "AD-Domain-Services"
        }

        WindowsFeature GPMC
        {
            Ensure = 'Present'
            Name = 'GPMC'
        }
 
 #DCPromo
        
        xADDomain FirstDC
        {
            DomainName = $Node.Domain
            DomainAdministratorCredential = $EACredential
            SafemodeAdministratorPassword = $SafeModeAdminPW
            DatabasePath = $Node.DCDatabasePath
            LogPath = $Node.DCLogPath
            SysvolPath = $Node.SysvolPath 
            DependsOn = '[WindowsFeature]ADDS'
        }      

# Add OU for groups

         xADOrganizationalUnit GroupsOU
        {
            Name = 'Groups'
            Path = 'DC=blah,DC=com'
            DependsOn = '[xADDomain]FirstDC'
            Ensure = 'Present'
            ProtectedFromAccidentalDeletion = $True
            Credential = $EaCredential
        }

#Add Web Servers group - add pull server as member later

         xADGroup WebServerGroup
        {
            GroupName = 'Web Servers'
            GroupScope = 'Global'
            DependsOn = '[xADOrganizationalUnit]GroupsOU'
            #Members = $AllNodes.Where{$_.Role -eq "PullServer"}.NodeName
            Credential = $EACredential
            Category = 'Security'
            Path = "OU=Groups,DC=blah,DC=com"
            Ensure = 'Present'
        }

#region - Add GPO for PKI AutoEnroll
        script CreatePKIAEGpo
        {
            Credential = $EACredential
            TestScript = {
                            if ((get-gpo -name "PKI AutoEnroll" -ErrorAction SilentlyContinue) -eq $Null) {
                                return $False
                            } 
                            else {
                                return $True}
                        }
            SetScript = {
                            new-gpo -name "PKI AutoEnroll"
                        }
            GetScript = {
                            $GPO= (get-gpo -name "PKI AutoEnroll")
                            return @{Result = $GPO}
                        }
            DependsOn = '[xADDomain]FirstDC'
        }
        
        script setAEGPRegSetting1
        {
            Credential = $EACredential
            TestScript = {
                            if ((Get-GPRegistryValue -name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "AEPolicy" -ErrorAction SilentlyContinue).Value -eq 7) {
                                return $True
                            }
                            else {
                                return $False
                            }
                        }
            SetScript = {
                            Set-GPRegistryValue -name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "AEPolicy" -Value 7 -Type DWord
                        }
            GetScript = {
                            $RegVal1 = (Get-GPRegistryValue -name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "AEPolicy")
                            return @{Result = $RegVal1}
                        }
            DependsOn = '[Script]CreatePKIAEGpo'
        }

        script setAEGPRegSetting2 
        {
            Credential = $EACredential
            TestScript = {
                            if ((Get-GPRegistryValue -name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "OfflineExpirationPercent" -ErrorAction SilentlyContinue).Value -eq 10) {
                                return $True
                                }
                            else {
                                return $False
                                 }
                         }
            SetScript = {
                            Set-GPRegistryValue -Name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "OfflineExpirationPercent" -value 10 -Type DWord
                        }
            GetScript = {
                            $Regval2 = (Get-GPRegistryValue -name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "OfflineExpirationPercent")
                            return @{Result = $RegVal2}
                        }
            DependsOn = '[Script]setAEGPRegSetting1'

        }
                                  
        script setAEGPRegSetting3
        {
            Credential = $EACredential
            TestScript = {
                            if ((Get-GPRegistryValue -Name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "OfflineExpirationStoreNames" -ErrorAction SilentlyContinue).value -match "MY") {
                                return $True
                                }
                            else {
                                return $False
                                }
                        }
            SetScript = {
                            Set-GPRegistryValue -Name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "OfflineExpirationStoreNames" -value "MY" -Type String
                        }
            GetScript = {
                            $RegVal3 = (Get-GPRegistryValue -Name "PKI AutoEnroll" -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" -ValueName "OfflineExpirationStoreNames")
                            return @{Result = $RegVal3}
                        }
            DependsOn = '[Script]setAEGPRegSetting2'
        }
      
        Script SetAEGPLink
        {
            Credential = $EACredential
            TestScript = {
                            try {
                                    set-GPLink -name "PKI AutoEnroll" -target $Using:Node.DomainDN -LinkEnabled Yes -ErrorAction silentlyContinue
                                    return $True
                                }
                            catch
                                {
                                    return $False
                                }
                         }
            SetScript = {
                            New-GPLink -name "PKI AutoEnroll" -Target $Using:Node.DomainDN -LinkEnabled Yes 
                        }
            GetScript = {
                            $GPLink = set-GPLink -name "PKI AutoEnroll" -target $Using:Node.DomainDN
                            return @{Result = $GPLink}
                        }
            DependsOn = '[Script]setAEGPRegSetting3'
        }                           

#end region - Add GPO for PKI AutoEnroll
 
#region - ADCS
                            
        WindowsFeature ADCS
        {
            Ensure = "Present"
            Name = "ADCS-Cert-Authority"
            DependsOn = '[xADDomain]FirstDC'
        }

        xAdcsCertificationAuthority ADCSConfig
        {
            CAType = 'EnterpriseRootCA'
            Credential = $EACredential
            CryptoProviderName = 'RSA#Microsoft Software Key Storage Provider'
            HashAlgorithmName = 'SHA256'
            KeyLength = 2048
            CACommonName = "blahblahblah root"
            CADistinguishedNameSuffix = "C=US,L=Somecity,S=Pennsylvania,O=Test Corp"
            DatabaseDirectory = 'C:\windows\system32\CertLog'
            LogDirectory = 'C:\CA_Logs'
            ValidityPeriod = 'Years'
            ValidityPeriodUnits = 2
            DependsOn = '[WindowsFeature]ADCS','[xADDomain]FirstDC'    
        }

#end region - ADCS

    }
}

LabInfraBuild -configurationData $ConfigData -outputpath "C:\DSC\Config" -EACredential (get-credential -username "blah.com\administrator" -Message "EA for ADCS/checking domain presence") -SafeModeAdminPW (get-credential -Username 'Password Only' -Message "Safe Mode Admin PW")
