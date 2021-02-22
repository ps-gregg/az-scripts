workflow wf-resume-AzureRmVM {
    <#
        .SYNOPSIS
            This workflow will login to the AzureRM and resume the specified Virtual Machine.
        
        .DESCRIPTION
            This workflow will login to the AzureRM and resume the specified Virtual Machine.
        
        .PARAMETER  SubscriptionId
            The subscription ID the Virtual Machine is in.
    
        .PARAMETER  ResourceGroupName
            The resource group the Virtual Machine is in.
    
        .PARAMETER  Name
            The server name running the Virtual Machine to resume.
    
        .EXAMPLE
            $params = @{
                'ResourceGroupName' = 'ContosoRG';
                'ServerName' = 'ContosoServer';
                'SubscriptionId' = '0xxx000x-00x0-xx0x-000x-000xxx00xx00';
            }
            Start-AzureRmAutomationRunbook -AutomationAccountName ContosoAutomation -Name wf-stop-AzureRMVM -ResourceGroupName ContosoResGroup –Parameters $params
    
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
        
    Write-Output "Parameters" -Verbose
    Write-Output "`$SubscriptionId    = $SubscriptionId" -Verbose
    Write-Output "`$ResourceGroupName = $ResourceGroupName" -Verbose
    Write-Output "`$ServerName        = $ServerName" -Verbose
    Write-Output " "
        
    # Try to connect to the AzureRmAccount
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
            
        Write-Output "Logging in to Azure..." -Verbose
        $az_account = Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
            -ErrorAction Stop
    } catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Connection $connectionName not found."
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
        
    # Try to resume the AzureRm Virtual Machine
    try {
        Write-Output "Retrieving status of VM  $ServerName" -Verbose
        Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code"
        $VMstatus = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code
            
        if ($VMstatus -contains "PowerState/running") {
            Write-Output "[PASS   ] - $ServerName is running" -Verbose
        } else {
            Write-Output "Attempting to start VM $ServerName" -Verbose
            Write-Output "[EXECUTE] Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -ea SilentlyContinue"
            $startRtn = Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -ea SilentlyContinue
            $count = 1
                
            Write-Output "Retrieving status of VM  $ServerName" -Verbose
            Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code"
            $VMstatus = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code
                
            if ($VMstatus -contains "PowerState/running") {
                Write-Output "[SUCCESS] - $ServerName started on attempt number $count of 5" -Verbose
            } else {
                # Wait 90 seconds and try again - loop 5 times until it stops
                do {
                    Write-Output "[PAUSE  ] - Failed to start $ServerName. Retrying in 90 seconds..." -Verbose
                    Start-Sleep -Seconds 90
                        
                    Write-Output "Attempting to start VM  $ServerName" -Verbose
                    Write-Output "[EXECUTE] Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -ea SilentlyContinue"
                    $startRtn = Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $ServerName -ea SilentlyContinue
                    $count++
                        
                    Write-Output "Retrieving status of VM  $ServerName" -Verbose
                    Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code"
                    $VMstatus = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -name $ServerName -status).statuses.code
                } while ($VMstatus -notcontains "PowerState/running" -and $count -lt 5)
                    
                if ($VMstatus -contains "PowerState/running") {
                    Write-Output "[SUCCESS] - $ServerName is running on attempt number $count of 5" -Verbose
                } else {
                    Write-Error "[FAILED ] - $ServerName failed to start after $count attempts" -Verbose
                }
            }
        }
    } catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    Write-Output "Workflow Complete" -Verbose
}
    