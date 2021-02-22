workflow wf-stop-AzureRMVM {
    <#
        .SYNOPSIS
            This workflow will login to the AzureRM and stop the specified Virtual Machine.
        
        .DESCRIPTION
            This workflow will login to the AzureRM and stop the specified Virtual Machine.
        
        .PARAMETER  SubscriptionId
            The subscription ID the Virtual Machine is in.
    
        .PARAMETER  ResourceGroupName
            The resource group the Virtual Machine is in.
    
        .PARAMETER  ServerName
            The server name running the Virtual Machine to stop.
    
        .EXAMPLE
            Start-AzureRmAutomationRunbook -AutomationAccountName ContosoAA -Name wf-stop-AzureRMVM -ResourceGroupName ContosoRG -ServerName ContosoServer -SubscriptionId 0xxx000x-00x0-xx0x-000x-000xxx00xx00
    
        .NOTES
            Gregg Britton (@ps_gregg), Version 1.0.0  04/16/2017
    #>
    param (
        [Parameter(Mandatory = $false)]
        [String]$connectionName = 'AzureRunAsConnection',
        [Parameter(Mandatory = $true)]
        [String]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [String]$ServerName
    )
        
    Write-Verbose "Parameters" -Verbose
    Write-Verbose "`$SubscriptionId    = $SubscriptionId" -Verbose
    Write-Verbose "`$ResourceGroupName = $ResourceGroupName" -Verbose
    Write-Verbose "`$ServerName        = $ServerName" -Verbose
        
    # Try to connect to the AzureRmAccount
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
            
        Write-Verbose "Logging in to Azure..." -Verbose
        $az_account = Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    } catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Azure connection $connectionName not found."
            throw $ErrorMessage
        } else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
        
    # Try to connect to Azure SubscriptionId
    try {
        Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
    } catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
        
    # Try to stop the AzureRm Virtual Machine
    try {
        Write-Output "Retrieving status of VM  $ServerName" -Verbose
        Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code"
        $VMstatus = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code
            
        if ($VMstatus -contains "PowerState/deallocated") {
            Write-Verbose "[PASS   ] - $ServerName is stopped" -Verbose
        } else {
            Write-Verbose "Attempting to stop VM  $ServerName" -Verbose
            Write-Output "[EXECUTE] Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -force -ea SilentlyContinue"
            $stopRtn = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -force -ea SilentlyContinue
            $count = 1
                
            Write-Verbose "Retrieving status of VM  $ServerName" -Verbose
            Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code"
            $VMstatus = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code
                
            if ($VMstatus -contains "PowerState/deallocated") {
                Write-Verbose "[SUCCESS] - $ServerName stopped on attempt number $count of 5" -Verbose
            } else {
                # Wait 90 seconds and try again - loop 5 times until it stops
                do {
                    Write-Verbose "[PAUSE  ] - Failed to stop $ServerName. Retrying in 90 seconds..." -Verbose
                    Start-Sleep -Seconds 90
                        
                    Write-Verbose "Attempting to stop VM $ServerName" -Verbose
                    Write-Output "[EXECUTE] Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -force -ea SilentlyContinue"
                    $stopRtn = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -force -ea SilentlyContinue
                    $count++
                        
                    Write-Verbose "Retrieving status of VM $ServerName" -Verbose
                    Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code"
                    $VMstatus = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code
                } while ($VMstatus -notcontains "PowerState/deallocated" -and $count -lt 5)
                    
                if ($VMstatus -contains "PowerState/deallocated") {
                    Write-Verbose "[SUCCESS] - $ServerName is stopped on attempt number $count of 5" -Verbose
                } else {
                    Write-Error "[FAILED ] - $ServerName failed to stop after $count attempts" -Verbose
                }
            }
        }
    } catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    Write-Verbose "Workflow Complete" -Verbose
}
    