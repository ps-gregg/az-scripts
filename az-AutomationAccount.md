
### Build a keyvault and automation account
```powershell
$aaParameters = @{
    automationAccountName = 'eastus-automation'
    SubscriptionId        = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    TenantId              = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Location              = 'eastus'
    resourceGroupName     = 'eastus-rg'
    keyVaultName          = 'eastus-kv'
    ObjectIDWorker        = $null
}
If ($null -eq (Get-AzAutomationAccount -Name $aaParameters.automationAccountName -ResourceGroupName $aaParameters.resourceGroupName -ErrorAction SilentlyContinue)) {
    $aaParameters.ObjectIDWorker = (Get-AzureADUser -ObjectId (Get-AzContext).Account.Id).ObjectId
    .\new-AzAutomationAccount @aaParameters
}
```

### Add module to Automation Account
```powershell
automationAccountName = 'eastus-automation'
$resourceGroupName = 'eastus-rg'
$ModuleName = 'StorageDsc'
$ModuleContentUrl = "https://www.powershellgallery.com/api/v2/package/$ModuleName"
do {
    $ModuleContentUrl = (Invoke-WebRequest -Uri $ModuleContentUrl -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location
} while ($ModuleContentUrl -notlike "*.nupkg")
New-AzAutomationModule -ResourceGroupName $resourceGroupName -AutomationAccountName $AutomationAccountName -Name $ModuleName -ContentLink $ModuleContentUrl
```

### Remove Automation Account
```powershell
$automationAccountName = 'eastus-automation'
$resourceGroupName = 'eastus-rg'
Remove-AzAutomationAccount -Name $automationAccountName -ResourceGroupName $resourceGroupName -Force
```

### Remove Service Principal
```powershell
$automationAccountName = 'eastus-automation'
$ServicePrincipal = Get-AzADServicePrincipal -SearchString $automationAccountName
Get-AzRoleAssignment -ObjectId $ServicePrincipal.Id | % { $_ | Remove-AzRoleAssignment }
Remove-AzADServicePrincipal -ObjectId $ServicePrincipal.Id -Force
```
