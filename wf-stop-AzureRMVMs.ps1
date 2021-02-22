workflow wf-stop-AzureRMVMs {
    <#
        .SYNOPSIS
            This workflow will login to the AzureRM and suspend all virtual machines that are not in the whitelist database.
        
        .DESCRIPTION
            This workflow will login to the AzureRM and suspend all virtual machines that are not in the whitelist database.
        
        .PARAMETER  SubscriptionId
            The subscription ID the virtual machines are in.
    
        .PARAMETER  WhiteListServerName
            The server name running the WhiteList of the virtual machines not to suspend.
    
        .PARAMETER  WhiteListDatabaseName
            The database name running the WhiteList of the virtual machines not to suspend..
    
        .PARAMETER  WhiteListDatabaseCredential
            The credentials to use to access database running the WhiteList of the virtual machines not to suspend..
    
        .EXAMPLE
            Start-AzureRmAutomationRunbook -AutomationAccountName ContosoAA -Name wf-suspend-AzureDWs -WhiteListServerName ContosoServer -WhiteListDatabaseName ContosoWarehouse -SubscriptionId 0xxx000x-00x0-xx0x-000x-000xxx00xx00  -WhiteListDatabaseCredential $credential
    
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
    $myCredential = Get-AutomationPSCredential -Name $WhiteListDatabaseCredential
    Write-Output "[EXECUTE] - Get-AutomationPSCredential -Name $WhiteListDatabaseCredential" -Verbose
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
            
        $sqlqry = "SELECT ResourceName FROM dbo.AzureWhitelist WHERE ResourceType = 'VM' AND SubscriptionId = '" + $SubscriptionId + "';"
            
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
        
    Write-Verbose "Retrieving all AzureRM resource groups" -Verbose
    $ResourceGroups = Get-AzureRmResourceGroup
    Write-Output "[EXECUTE] - Get-AzureRmResourceGroup"
        
    #Get all resource groups in the subscription
    foreach ($ResourceGroup in $ResourceGroups) {
        Write-Verbose '' -Verbose
        Write-Verbose "Retrieving all VMs in resource group $($ResourceGroup.ResourceGroupName)" -Verbose
        $VMs = Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName)
        Write-Output "[EXECUTE] - Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName)"
            
        #Get all virtual machines in the resource group
        foreach -parallel ($vm in $VMs) {
            if ($whitelist.ResourceName -contains $VM.Name) {
                Write-Verbose "[PASS   ] - $($vm.Name) is in the whitelist." -Verbose
            } else {
                Write-Verbose "Retrieving status of VM  $($VM.Name)" -Verbose
                $VMstatus = (Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -name $($VM.Name) -status).statuses.code
                Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -name $($VM.Name) -status).statuses.code"
                    
                if ($VMstatus -contains "PowerState/deallocated") {
                    Write-Verbose "[PASS   ] - $($vm.Name) is stopped" -Verbose
                } else {
                    Write-Verbose "Attempting to stop VM  $($VM.Name)" -Verbose
                    $stopRtn = Stop-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -Name $($VM.Name) -force -ea SilentlyContinue
                    Write-Output "[EXECUTE] Stop-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -Name $($VM.Name) -force -ea SilentlyContinue"
                    $count = 1
                        
                    Write-Verbose "Retrieving status of VM  $($VM.Name)" -Verbose
                    $VMstatus = (Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -name $($VM.Name) -status).statuses.code
                    Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -name $($VM.Name) -status).statuses.code"
                        
                    if ($VMstatus -contains "PowerState/deallocated") {
                        Write-Verbose "[SUCCESS] - $($vm.Name) stopped on attempt number $count of 5" -Verbose
                    } else {
                        # Wait 90 seconds and try again - loop 5 times until it stops
                        do {
                            Write-Verbose "[PAUSE  ] - Failed to stop $($VM.Name). Retrying in 90 seconds..." -Verbose
                            Start-Sleep -Seconds 90
                                
                            Write-Verbose "Attempting to stop VM  $($VM.Name)" -Verbose
                            $stopRtn = Stop-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -Name $($VM.Name) -force -ea SilentlyContinue
                            Write-Output "[EXECUTE] Stop-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -Name $($VM.Name) -force -ea SilentlyContinue"
                            $count++
                                
                            Write-Verbose "Retrieving status of VM  $($VM.Name)" -Verbose
                            $VMstatus = (Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -name $($VM.Name) -status).statuses.code
                            Write-Output "[EXECUTE] - (Get-AzureRmVM -ResourceGroupName $($ResourceGroup.ResourceGroupName) -name $($VM.Name) -status).statuses.code"
                        } while ($VMstatus -notcontains "PowerState/deallocated" -and $count -lt 5)
                            
                        if ($VMstatus -contains "PowerState/deallocated") {
                            Write-Verbose "[SUCCESS] - $($vm.Name) is stopped on attempt number $count of 5" -Verbose
                        } else {
                            Write-Error "[FAILED ] - $($vm.Name) failed to stop after $count attempts" -Verbose
                        }
                    }
                }
            }
        }
    }
}
    
    
    