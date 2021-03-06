﻿<#
    DESCRIPTION: 
        Checks that all DNS servers are configured, and if required, in the right order.

    REQUIRED-INPUTS:
        DNSServers    - List of DNS IP addresses that you want to check|IPv4
        OrderSpecific - "True|False" - Should the DNS order match exactly for a Pass.?  If the number of entries does not match the input list, this is set to "FALSE"
        AllMustExist  - "True|False" - Should all DNS entries exist for a Pass.?

    DEFAULT-VALUES:
        DNSServers    = ('')
        OrderSpecific = 'True'
        AllMustExist  = 'True'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All DNS servers configured (and in the right order)
        WARNING: 
        FAIL:
            DNS Server count mismatch
            Mismatched DNS servers
            DNS Server list is not in the required order
            No DNS servers are configured
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-11-dns-settings
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-11-dns-settings'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DNSServerSearchOrder FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled="TRUE"'
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty DNSServerSearchOrder
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check.Count -gt 0)
    {
        If (($check.Count) -ne ($script:appSettings['DNSServers'].Count))
        {
            If ($script:appSettings['AllMustExist'] -eq 'TRUE')
            {
                $result.result  = $script:lang['Fail']
                $result.message = 'DNS Server count mismatch'
                $result.data    = "Configured: $($check -join ', '),#Looking For: $($script:appSettings['DNSServers'] -join ', ')"
            }
            Else
            {
                $script:appSettings['OrderSpecific'] = 'FALSE'
            }
        }

        # Set OrderSpecific to FALSE if required
        If (($script:appSettings['OrderSpecific']) -eq 'TRUE')
        {
            # Check OrderSpecific list
            For ($i=0; $i -le ($check.Count); $i++)
            {
                If ($check[$i] -ne $script:appSettings['DNSServers'][$i]) { $result.message = 'DNS Server list is not in the required order'; Break }
            }
            If (($result.message) -ne '')
            {
                $result.result = $script:lang['Fail']
                $result.data   = "Configured: $($check -join ', '),#Looking For: $($script:appSettings['DNSServers'] -join ', ')"
            }
            Else
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'All DNS servers configured and in the right order'
                $result.data    = ($check -join ', ')
            }
        }
        Else
        {
            # Check any ordered list
            ForEach ($itemC In $check)
            {
                [boolean]$Found = $false
                ForEach ($itemS In $script:appSettings['DNSServers']) { If ($itemC -eq $itemS) { $Found = $true; Break } }
                If ($Found -eq $false)
                {
                    $result.result  = $script:lang['Fail']
                    $result.message = 'Mismatched DNS servers'
                    $result.data    = "Configured: $($check -join ', '),#Looking For: $($script:appSettings['DNSServers'] -join ', ')"
                }
            }

            If (($result.message) -eq '')
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'All DNS servers configured'
                $result.data    = ($check -join ', ')
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'No DNS servers are configured'
        $result.data    = ''
    }

    Return $result
}