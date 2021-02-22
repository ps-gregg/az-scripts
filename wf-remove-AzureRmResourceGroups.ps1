workflow wf-remove-AzureRmResourceGroups {
    <#
        .SYNOPSIS
            This workflow will login to the AzureRM and remove all resource groups in the subscription.
        
        .DESCRIPTION
            This workflow will login to the AzureRM and remove all resource groups in the subscription.
        
        .PARAMETER  SubscriptionId
            The subscription ID the resource groups are in.
    
        .EXAMPLE
            $params = @{
                'ResourceGroupName' = 'ContosoRG';
                'SubscriptionId' = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
            }
            Start-AzureRmAutomationRunbook -AutomationAccountName ContosoAutomation -Name wf-remove-AzureRmResourceGroups -ResourceGroupName ContosoResGroup –Parameters $params
    
        .NOTES
            Gregg Britton (@ps_gregg), Version 1.0.0  07/19/2017
    #>
    param (
        [Parameter(Mandatory = $false)]
        [String]$connectionName = 'AzureRunAsConnection',
        [Parameter(Mandatory = $true)]
        [String]$SubscriptionId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    )      

    Write-Output "Parameters" -Verbose
    Write-Output "`$SubscriptionId    = $SubscriptionId" -Verbose
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
        
    # Try to remove the Resource Groups
    try {
        Write-Output "Retrieving resource groups in subscription  $SubscriptionId" -Verbose
        Write-Output "[EXECUTE] - Get-AzureRmResourceGroup "
        $AllResourceGroups = Get-AzureRmResourceGroup  
        $AllResourceGroups = $AllResourceGroups | Where-Object { $_.ResourceGroupName -ne 'BBI-Automation' }
        foreach -parallel ($ResourceGroup in $AllResourceGroups) {
            $ResourceGroupName = $ResourceGroup.ResourceGroupName
            Write-Output "[EXECUTE] - Remove-AzureRmResourceGroup -Name $ResourceGroupName -Verbose -Force "
            Remove-AzureRmResourceGroup -Name "$ResourceGroupName" -Verbose -Force
        }
    } catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    Write-Output "Workflow Complete" -Verbose
}
    