
workflow Scale_Hyperscale_Database {
<#   
.SYNOPSIS   
    Add VCores (vertically scale) an Azure Hyperscale SQL Database    
   
.DESCRIPTION   
    This runbook enables you to vertically scale (up or down) an Azure Hyperscale SQL Database using Azure Automation.  
     
    There are many scenarios in which the performance needs of a database follow a known schedule. 
    Using the provided runbook, you can automatically schedule a database to a scale-up to 12 vCores  
    database during peak hours (e.g., 7am to 6pm) and then scale-down the database to 2 vCores during 
    non peak hours (e.g., 6pm-7am). 

.PARAMETER ResourceGroupName  
    Name of the Azure SQL Database server
       
.PARAMETER SqlServerName  
    Name of the Azure SQL Database server  
       
.PARAMETER DatabaseName   
    Name of the Azure SQL Database name 

.PARAMETER vCore   
    The vCore number for the Azure Sql database
  
.NOTES   
    Author: Gregg Britton   
    Last Updated: 11/11/2020      
    
#>    
    param
    (
        [Parameter(Mandatory = $false)]
        [String]$connectionName = 'AzureRunAsConnection',
        
        [parameter(Mandatory = $true)]
        [string]$ResourceGroupName = 'east-rg',
        
        [parameter(Mandatory = $true)]
        [string]$SqlServerName = 'east-sql',
        
        [parameter(Mandatory = $true)]
        [string]$DatabaseName = 'east-database',
        
        [parameter(Mandatory = $true)]
        [int32]$vCore = 2
    )
    
    Write-Output "Authenticating to Azure with $connectionName."
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
        
        Write-Output "Logging in to Azure..."
        $az_account = Connect-AzAccount `
                                        -ServicePrincipal `
                                        -SubscriptionId $servicePrincipalConnection.SubscriptionId `
                                        -TenantId $servicePrincipalConnection.TenantId `
                                        -ApplicationId $servicePrincipalConnection.ApplicationId `
                                        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
        Write-Output "Connected to Azure ..."
    } catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Azure connection $connectionName not found."
            throw $ErrorMessage
        } else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
    
    Write-Output ""
    Write-Output "Using Parameters ..."
    Write-Output "`$connectionName: $connectionName"
    Write-Output "`$ResourceGroupName: $ResourceGroupName"
    Write-Output "`$SqlServerName: $SqlServerName"
    Write-Output "`$DatabaseName: $DatabaseName"
    Write-Output "`$vCore: $vCore"
    
    try {
        Write-Output ""
        Write-Output "Getting database current settings ..."
        $Db = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $DatabaseName
        Write-Output "$DatabaseName is running Edition: $($Db.Edition)  Capacity:  $($Db.capacity) vCores"
    } catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    
    if ($vCore -ne $Db.capacity) {
        try {
            Write-Output ""
            Write-Output "Changing Database to Capacity:  $vCore"
            Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $DatabaseName -VCore $VCore
        } catch {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
        
        try {
            Write-Output ""
            Write-Output "Getting Database new settings ..."
            $Db = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $DatabaseName
            Write-Output "$DatabaseName is running Edition: $($Db.Edition)  Capacity:  $($Db.capacity) vCores"
        } catch {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
        
        # Output final status message 
        Write-Output ""
        Write-Output "Completed vertical scale"
    } else {
        Write-Output "Capacity is already set to:  $vCore"
    }
}

