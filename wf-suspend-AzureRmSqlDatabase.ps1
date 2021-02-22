workflow wf-suspend-AzureRmSqlDatabase {
    <#
        .SYNOPSIS
            This workflow will login to the AzureRM and suspend the specified SQL Data Warehouse.
        
        .DESCRIPTION
            This workflow will login to the AzureRM and suspend the specified SQL Data Warehouse.
        
        .PARAMETER  SubscriptionId
            The subscription ID the SQL Data Warehouse is in.
    
        .PARAMETER  ResourceGroupName
            The resource group the SQL Data Warehouse is in.
    
        .PARAMETER  ServerName
            The server name running the SQL Data Warehouse to resume.
    
        .PARAMETER  DatabaseName
            The name of the SQL Data Warehouse to suspend.
    
        .EXAMPLE
            Start-AzureRmAutomationRunbook -AutomationAccountName ContosoAA -Name wf-suspend-AzureRmSqlDatabase -ResourceGroupName ContosoRG -ServerName ContosoServer -DatabaseName ContosoWarehouse -SubscriptionId 0xxx000x-00x0-xx0x-000x-000xxx00xx00
    
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
        [String]$ServerName,
        [Parameter(Mandatory = $true)]
        [String]$DatabaseName
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
        # Suspend-AzureRmSqlDatabase -ResourceGroupName "$ResourceGroupName" -ServerName "$ServerName" -DatabaseName "$DatabaseName" -ErrorAction Stop
        # Write-Output "[EXECUTE] - Suspend-AzureRmSqlDatabase -ResourceGroupName `"$ResourceGroupName`" -ServerName `"$ServerName`" -DatabaseName `"$DatabaseName`" "
    } catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
    