<#	
	.NOTES
	===========================================================================
	Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2019 v5.6.160
	Created on:   	08/10/2017
	Modified on:    03/16/2020 (Changed to Az)
	Created by:   	Gregg Britton (@ps_gregg)
	Filename:     	send-AzSQLDatabases.ps1
	===========================================================================
#>

Import-Module Az.Accounts
Import-Module Az.Sql
Import-Module EnhancedHTML2

# Location of CSS Stylesheet for the HTML
$stylesheet = '.\powershellstyle.css'

# Get the credentials and Login to Azure
$credential = [System.Management.Automation.PSCREDENTIAL]$fromVault
Connect-AzAccount -Tenant 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -SubscriptionId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' –Credential $credential

$output = @()
$subscriptions = Get-AzSubscription | Where-Object { $_.SubscriptionId -ne 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' } 
foreach ($subscription in $subscriptions) {
    Set-AzContext -subscription $subscription.SubscriptionId > $null
    
    $sqlservers = Get-AzSqlServer
    if ($null -ne $sqlservers) {
        foreach ($sqlserver in $sqlservers) {
            
            $databases = Get-AzSqlDatabase -ServerName $sqlserver.ServerName -ResourceGroupName $sqlserver.ResourceGroupName
            if ($null -ne $databases) {
                foreach ($database in $databases) {
                    
                    $props = @{
                        'SubscriptionName'  = $subscription.Name;
                        'ResourceGroupName' = $database.ResourceGroupName;
                        'ServerName'        = $database.ServerName;
                        'DatabaseName'      = $database.DatabaseName;
                    }
                    $output += New-Object -TypeName PSObject -Property $props
                }
            }
        }
    }
}

# Create HTML object of all Azure SQL Servers/Databases
$params = @{
    'As'              = 'Table';
    'PreContent'      = '';
    'EvenRowCssClass' = 'even';
    'OddRowCssClass'  = 'odd';
    'Properties'      = 'SubscriptionName', 'ResourceGroupName', 'ServerName', 'DatabaseName'
}
$output_html = $output | Sort-Object SubscriptionName, ServerName | ConvertTo-EnhancedHTMLFragment @params

# Create HTML report
$params = @{
    'CssStyleSheet' = (Get-Content $stylesheet);
    'Title'         = "Azure SQL Servers/Databases - $((Get-Date).ToShortDateString())";
    'PreContent'    = "<h1>Azure SQL Servers/Databases  - $((Get-Date).ToShortDateString())</h1>";
    'HTMLFragments' = @($output_html)
}
$body = ConvertTo-EnhancedHTML @params | Out-String

# Email the results
$emailcredential = [System.Management.Automation.PSCREDENTIAL]$fromVault
$messageParameters = @{
    Subject    = "Azure SQL Servers/Databases - $((Get-Date).ToShortDateString())"
    Body       = $body
    BodyAsHtml = $true
    From       = "<<sender>>"
    To         = ("<<recipients>>").split(',')
    SmtpServer = "<<smtpserver>>"
    Credential = $emailcredential
    UseSsl     = $true
    Port       = 587
}
Send-MailMessage @messageParameters
