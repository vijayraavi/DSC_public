function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $RelationshipName,

        [parameter(Mandatory = $true)]
        [System.String]
        $ScopeName,

        [parameter(Mandatory = $true)]
        [System.String]
        $PartnerServer
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

$relationship = Get-DhcpServerv4Failover | Where-Object {$_.PartnerServer -match $PartnerServer}

if ($relationship) {
    $Ensure = 'Present'
    }
else {
    $Ensure = 'Absent'
    }
$ReturnValue = @{
     Ensure = $Ensure
     PartnerServer = $PartnerServer
     RelationshipName = $relationship.Name
     Mode = $relationship.Mode
     LBPercent = $relationship.LoadBalancePercent
     MCLT = $relationship.MaxClientLeadTime
     StateSwitchInterval = $relationship.StateSwitchInterval
     ScopeName = $relationship.ScopeId
     AutoStateTransition = $relationship.AutoStateTransition
     SharedSecret = $relationship.EnableAuth
     }
$ReturnValue

    <#
    $returnValue = @{
    Ensure = [System.String]
    RelationshipName = [System.String]
    ScopeName = [System.String]
    PartnerServer = [System.String]
    AutoStateTransition = [System.Boolean]
    SharedSecret = [System.String]
    MCLT = [System.String]
    LBPercentage = [System.UInt32]
    StateSwitchInterval = [System.String]
    }

    $returnValue
    #>
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $RelationshipName,

        [parameter(Mandatory = $true)]
        [System.String]
        $ScopeName,

        [parameter(Mandatory = $true)]
        [System.String]
        $PartnerServer,

        [System.Boolean]
        $AutoStateTransition,

        [System.String]
        $SharedSecret,

        [System.String]
        $MCLT,

        [System.UInt32]
        $LBPercentage,

        [System.String]
        $StateSwitchInterval
    )

    #########################################Fix input types

#shamelessly stolen from helper function, handle later :S

[System.TimeSpan]$timeSpan = New-TimeSpan
$result = [System.TimeSpan]::TryParse($MCLT, [ref]$timeSpan)

$MCLT=$timeSpan

[System.TimeSpan]$timeSpan = New-TimeSpan
$result = [System.TimeSpan]::TryParse($StateSwitchInterval, [ref]$timeSpan)

$StateSwitchInterval=$timeSpan

############################End fix input#############################################

If ($Ensure -match "Absent") {
    write-verbose "Removing DHCP failover relationship"
    Remove-DhcpServerv4Failover -Name $RelationshipName
    write-verbose "DHCP Failover relationship removed successfully"
    }
else {
    try {
        $null = Get-DhcpServerv4Failover -ScopeId $ScopeName -ErrorAction Stop
        write-verbose "Modifying DHCP failover relationship $($RelationshipName)"
        Set-DhcpServerv4Failover -Name $RelationshipName -SharedSecret $SharedSecret -AutoStateTransition $AutoStateTransition -MaxClientLeadTime $MCLT -StateSwitchInterval $StateSwitchInterval -LoadBalancePercent $LBPercentage
        Write-Verbose "DHCP failover relationship modified successfully"
        }
    catch {
        write-verbose "Adding DHCP failover relationship"
        Add-DhcpServerv4Failover -Name $RelationshipName -PartnerServer $PartnerServer -ScopeId $ScopeName -SharedSecret $SharedSecret -MaxClientLeadTime $MCLT -StateSwitchInterval $StateSwitchInterval
        write-verbose "DHCP failover relationship created"
        }
    }

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1


}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $RelationshipName,

        [parameter(Mandatory = $true)]
        [System.String]
        $ScopeName,

        [parameter(Mandatory = $true)]
        [System.String]
        $PartnerServer,

        [System.Boolean]
        $AutoStateTransition,

        [System.String]
        $SharedSecret,

        [System.String]
        $MCLT,

        [System.UInt32]
        $LBPercentage,

        [System.String]
        $StateSwitchInterval
    )

#########################################Fix input types

#shamelessly stolen from helper function, handle later :S

[System.TimeSpan]$timeSpan = New-TimeSpan
$result = [System.TimeSpan]::TryParse($MCLT, [ref]$timeSpan)

$MCLT=$timeSpan

[System.TimeSpan]$timeSpan = New-TimeSpan
$result = [System.TimeSpan]::TryParse($StateSwitchInterval, [ref]$timeSpan)

$StateSwitchInterval=$timeSpan

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

     try {
        $testFailover = Get-DhcpServerv4Failover -ScopeId $ScopeNameID -ErrorAction Stop
        }
    catch {  #If currently absent, will fall into catch
        if ($Ensure -match 'Present') {
            write-verbose "Failover relationship not present, configuration is needed."
            return $False
        }
        else {
            write-verbose "Failover relationship is not present, already in desired state."
            return $True
        }
    }
    #If currently present, check if absent is desired state
    if ($Ensure -match 'Absent') {
        write-verbose "Failover relationship is configured, desired state is unconfigured."
        return $False
        }
        
    #Otherwise failover is currently present and desired present, so check all settings.        
    elseif ($TestFailover.Name -notmatch $RelationshipName) {
        write-verbose "Failover Name does not match $($RelationshipName), configuration is needed."
        return $False
        }
    elseif ($TestFailover.PartnerServer -notmatch $PartnerServer) {
        write-verbose "Failover relationship with $($PartnerServer) is not found, configuration is needed."
        return $False
        }
    elseif ($TestFailover.AutoStateTransition -ne $AutoStateTransition) {
        Write-Verbose "Failover Auto State Transition does not match $($AutoStateTranstion), configuration is needed."
        return $False
        }
    
    #Cannot test SharedSecret - get-DHCPServerv4Failover does not return this value
    #More research is needed to see if it can be checked some other way
    #Skip checking for now
    <#
    elseif ($TestFailover.SharedSecret -notmatch $SharedSecret) {
        Write-Verbose "Shared Secret does not match desired shared secret, configuration is needed."
        return $False
        }  #>


     elseif (($MCLT -ne $Null) -and ($TestFailover.MaxClientLeadTime -ne $MCLT)) {  #Only check if a value is specified
        Write-Verbose "$($TestFailover.MaxClientLeadTime) does not match $($MCLT)."
        return $False
        }
    elseif (($LBPercentage -ne $Null) -and ($TestFailover.LoadBalancePercent -ne $LBPercentage)) { #Only check if a value is specified
            Write-Verbose "Load Balancing Percentage does not match $($LBPercentage) Percent."
            return $False
            }
    elseif (($StateSwitchInterval -ne $Null) -and ($TestFailover.StateSwitchInterval -notmatch $StateSwitchInterval)) { #Only check if a value is specified
            Write-Verbose "State Switch Interval does not match $($StateSwitchInterval)"
            return $False
            }
    else {
        Write-Verbose "All settings configured as requested."
        return $True
        }

    <#
    $result = [System.Boolean]
    
    $result
    #>
}


Export-ModuleMember -Function *-TargetResource

