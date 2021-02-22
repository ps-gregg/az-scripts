workflow wf-suspend-AzureDWs {
    <#
        .SYNOPSIS
            This workflow will login to the AzureRM and suspend the specified SQL Data Warehouse.
        
        .DESCRIPTION
            This workflow will login to the AzureRM and suspend the specified SQL Data Warehouse.
        
        .PARAMETER  SubscriptionId
            The subscription ID the SQL Data Warehouses are in.
    
        .PARAMETER  WhiteListServerName
            The server name running the WhiteList of the SQL Data Warehouses not to suspend.
    
        .PARAMETER  WhiteListDatabaseName
            The database name running the WhiteList of the SQL Data Warehouses not to suspend..
    
        .PARAMETER  WhiteListDatabaseCredential
            The credentials to use to access database running the WhiteList of the SQL Data Warehouses not to suspend..
    
        .EXAMPLE
            Start-AzureRmAutomationRunbook -AutomationAccountName ContosoAA -Name wf-suspend-AzureDWs -WhiteListServerName ContosoServer -WhiteListDatabaseName ContosoWarehouse -SubscriptionId 0xxx000x-00x0-xx0x-000x-000xxx00xx00 -WhiteListDatabaseCredential $credential
    
        .NOTES
            Gregg Britton (@ps_gregg), Version 1.0.0  04/16/2017
    #>
    param (
        [Parameter(Mandatory = $false)]
        [String]$connectionName = 'AzureRunAsConnection',
        [Parameter(Mandatory = $true)]
        [String]$SubscriptionId = '',
        [Parameter(Mandatory = $true)]
        [String]$WhiteListServerName = '',
        [Parameter(Mandatory = $true)]
        [String]$WhiteListDatabaseName = '',
        [Parameter(Mandatory = $true)]
        [String]$WhiteListDatabaseCredential = ''
    )
        
    Write-Verbose "Authenticating to Azure with $connectionName." -Verbose
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
        
    Write-Verbose "Getting whitelist database credential" -Verbose
    Write-Output "[EXECUTE] - Get-AutomationPSCredential -Name $WhiteListDatabaseCredential" -Verbose
    $myCredential = Get-AutomationPSCredential -Name $WhiteListDatabaseCredential
    if ($myCredential -eq $null) {
        $ErrorMessage = "WhiteList database credentials $WhiteListDatabaseCredential not found."
        throw $ErrorMessage
    }
        
    Write-Verbose "Building whitelist database connection string" -Verbose
    $dbUser = $myCredential.UserName
    $securePassword = $myCredential.Password
    $dbPass = $myCredential.GetNetworkCredential().Password
    $connectionString = "Data Source=" + $WhiteListServerName + ",1433;Initial Catalog=" + $WhiteListDatabaseName + ";Integrated Security=False;User ID=" + $dbUser + ";Password=" + $dbPass + ";Connect Timeout=60;"
        
    Write-Verbose "Retrieving whitelist from database" -Verbose
    # Get contents of the whitelist
    if ($WhiteListServerName -ne $null) {
        $sqlqry = "SELECT ResourceName FROM dbo.AzureWhitelist WHERE ResourceType = 'DW' AND SubscriptionId = '" + $SubscriptionId + "';"
            
        $whitelist = InlineScript {
            Write-Output $connectionString
            Write-Output "[EXECUTE] - $Conn = New-Object System.Data.SqlClient.SqlConnection($Using:connectionString)"
            $Conn = New-Object System.Data.SqlClient.SqlConnection
            $Conn.ConnectionString = $Using:connectionString
                
            # Open the SQL connection 
            $Conn.Open()
                
            # Define the SQL command to run.
            $Cmd = new-object system.Data.SqlClient.SqlCommand
            $Cmd.Connection = $Conn
            $Cmd.CommandText = $Using:sqlqry
            $Cmd.CommandTimeout = 120
                
            # Fill the DataTable object with the query output
            $Reader = $Cmd.ExecuteReader()
            $DataTable = New-Object System.Data.DataTable
            $DataTable.Load($Reader)
                
            # Output the data
            $DataTable
                
            # Close the SQL connection 
            $Conn.Close()
        }
    } else {
        $whitelist = $null
    }
    Write-Verbose "Whitelist retrieved" -Verbose
        
    Write-Verbose "Displaying WhiteList" -Verbose
    Write-Output $whitelist.ResourceName
    Write-Verbose '' -Verbose
        
    #Get all SQL Datawarehouses in the subscription
    Write-Verbose "Get all SQL Datawarehouses in the subscription" -Verbose
    Write-Output "[EXECUTE] - Get-AzureRmResource | Where-Object ResourceType -EQ 'Microsoft.Sql/servers/databases' | Where-Object Kind -ILike '*datawarehouse*' " -Verbose
    $dws = Get-AzureRmResource | Where-Object ResourceType -EQ 'Microsoft.Sql/servers/databases' | Where-Object Kind -ILike '*datawarehouse*'
        
    #Loop through each SQLDW
    Write-Verbose '' -Verbose
    Write-Verbose "Looping through each Datawarehouse found" -Verbose
    foreach ($dw in $dws) {
        $resourcegroupname = $dw.ResourceGroupName
        $dwc = $dw.Name.split("/")
        $dw_servername = $dwc[0]
        $dw_databasename = $dwc[1]
        Write-Output " "
        Write-Output "[EXECUTE] - Get-AzureRmSqlDatabase -ResourceGroupName $resourcegroupname -ServerName $dw_servername -DatabaseName $dw_databasename "
        $status = Get-AzureRmSqlDatabase -ResourceGroupName $resourcegroupname -ServerName $dw_servername -DatabaseName $dw_databasename | Select Status
            
        #Check the status
        Write-Verbose "Checking status of $dw_servername \ $dw_databasename " -Verbose
        if ($status.Status -eq "Paused") {
            Write-Output "[PASS   ] - $dw_servername \ $dw_databasename is Paused"
        } else {
            if ($whitelist.ResourceName -contains $dw_databasename) {
                Write-Output "[PASS   ] - $dw_databasename is in the whitelist"
            } else {
                Write-Output "[EXECUTE] - Suspend-AzureRMSqlDatabase -ResourceGroupName $resourcegroupname -ServerName $dw_servername -DatabaseName $dw_databasename"
                Suspend-AzureRmSqlDatabase -ResourceGroupName "$resourcegroupname" -ServerName "$dw_servername" -DatabaseName "$dw_databasename"
            }
        }
    }
    Write-Verbose '' -Verbose
    Write-Verbose "-- Workflow complete --" -Verbose
}
    