<#	
	.NOTES
	===========================================================================
	Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2020
	Created on:   	08/10/2017
	Modified on:    03/16/2020 (Changed to Az)
	Created by:   	Gregg Britton
    Filename:     	send-AzAutomationCertificates.ps1
	===========================================================================
#>

# Location of CSS Stylesheet for the HTML
$stylesheet = '.\powershellstyle.css'

# Get the credentials and Login to Azure
$credential = [System.Management.Automation.PSCREDENTIAL]$fromVault
Connect-AzAccount -Tenant 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -SubscriptionId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' –Credential $credential

# Get automation certificates for each subscription
$subscriptions = Get-AzSubscription | ? { $_.subscriptionid -ne 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' }
$certificates_table = foreach ($subscription in $subscriptions) {
    Set-AzContext -subscription $subscription.SubscriptionId > $null
    
    $certificates = Get-AzAutomationAccount | Get-AzAutomationCertificate
    foreach ($certificate in $certificates) {
        $props = @{
            'AutomationAccountName' = $certificate.AutomationAccountName;
            'Name'                  = $certificate.Name;
            'ExpiryTime'            = $certificate.ExpiryTime;
            'ResourceGroupName'     = $certificate.ResourceGroupName
        }
        New-Object -TypeName PSObject -Property $props
    }
}

# Create HTML table of all certificates
$params = @{
    'As'              = 'Table';
    'PreContent'      = '';
    'EvenRowCssClass' = 'even';
    'OddRowCssClass'  = 'odd';
    'Properties'      = 'AutomationAccountName',
    'Name',
    @{ n = 'ExpiryTime'; e = { $_.ExpiryTime }; css = { if ($_.ExpiryTime -lt $(get-date).adddays(30)) { 'red' } } },
    'ResourceGroupName'
}
$certificates_html = $certificates_table | Sort-Object ExpiryTime, AutomationAccountName | ConvertTo-EnhancedHTMLFragment @params

# Create HTML report
$params = @{
    'CssStyleSheet' = (Get-Content $stylesheet);
    'Title'         = "Azure Automation Certificates - $((Get-Date).ToShortDateString())";
    'PreContent'    = "<h1>Azure Automation Certificates - $((Get-Date).ToShortDateString())</h1>";
    'HTMLFragments' = @($certificates_html)
}
$body = ConvertTo-EnhancedHTML @params | Out-String

# Email the results to the end-user
$emailcredential = [System.Management.Automation.PSCREDENTIAL]$fromVault
$messageParameters = @{
    Subject    = "Azure Automation Certificates - $((Get-Date).ToShortDateString())"
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
