workflow wf-Restart-AzureRmVmss {
    <#
        .SYNOPSIS
            This workflow will login to the AzureRM and restart the specified VM ScaleSet.
        
        .DESCRIPTION
            This workflow will login to the AzureRM and restart the specified VM ScaleSet.
        
        .PARAMETER  SubscriptionId
            The subscription ID the VM ScaleSet is in.
    
        .PARAMETER  ResourceGroupName
            The resource group the VM ScaleSet is in.
    
        .PARAMETER  VMScaleSetName
            The name of the VM ScaleSet to suspend.
    
        .EXAMPLE
            Start-AzureRmAutomationRunbook -AutomationAccountName ContosoAA -Name wf-Restart-AzureRmVmss -ResourceGroupName ContosoRG -VMScaleSetName ContosoScaleSetWarehouse -SubscriptionId 0xxx000x-00x0-xx0x-000x-000xxx00xx00
    
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
        [String]$VMScaleSetName
    )
        
    # Try to connect to the AzureRmAccount
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
            
        Write-Verbose "Logging in to Azure..." -Verbose
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
        
    # Try to suspend the AzureRmSqlDatabase
    try {
        Write-Output "[EXECUTE] - Restart-AzureRmVmss -ResourceGroupName `"$ResourceGroupName`" -VMScaleSetName `"$VMScaleSetName`" -Verbose"
        Restart-AzureRmVmss -ResourceGroupName "$ResourceGroupName" -VMScaleSetName "$VMScaleSetName" -Verbose
    } catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
    