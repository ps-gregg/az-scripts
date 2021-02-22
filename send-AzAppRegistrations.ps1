<#	
	.NOTES
	===========================================================================
	Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2020
	Created on:   	08/10/2017
	Modified on:    03/16/2020 (Changed to Az)
	Created by:   	Gregg Britton (@ps_gregg)
	Filename:     	send-AzureAppResgistrations.ps1
	===========================================================================
#>

Import-Module Az.Accounts
Import-Module Az.Resources
Import-Module EnhancedHTML2

# Location of CSS Stylesheet for the HTML
$stylesheet = '.\powershellstyle.css'

# Get the credentials and Login to Azure
$credential = [System.Management.Automation.PSCREDENTIAL]$fromVault
Connect-AzAccount -Tenant 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -SubscriptionId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' –Credential $credential

# Get automation certificates for each subscription
$appRegistrations = Get-AzADApplication
$appRegistrations_table = foreach ($registration in $appRegistrations) {
    $props = @{
        'DisplayName'   = $registration.DisplayName;
        'ApplicationId' = $registration.ApplicationId
    }
    New-Object -TypeName PSObject -Property $props
}

# Create HTML table of all application registrations
$params = @{
    'As'              = 'Table';
    'PreContent'      = '';
    'EvenRowCssClass' = 'even';
    'OddRowCssClass'  = 'odd';
    'Properties'      = 'DisplayName',
    'ApplicationId'
}
$appRegistrations_html = $appRegistrations_table | Sort-Object DisplayName | ConvertTo-EnhancedHTMLFragment @params

# Create HTML report
$params = @{
    'CssStyleSheet' = (Get-Content $stylesheet);
    'Title'         = "Azure App Registrations - $((Get-Date).ToShortDateString())";
    'PreContent'    = "<h1>Azure App Registrations - $((Get-Date).ToShortDateString())</h1>";
    'HTMLFragments' = @($appRegistrations_html)
}
$body = ConvertTo-EnhancedHTML @params | Out-String

# Email the results to the end-user
$emailcredential = [System.Management.Automation.PSCREDENTIAL]$fromVault
$messageParameters = @{
    Subject    = "Azure App Registrations - $((Get-Date).ToShortDateString())"
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
