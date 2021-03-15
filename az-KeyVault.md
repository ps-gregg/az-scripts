### Check for all KeyVaults in a removed state
```powershell
$Location = 'eastus'
Get-AzKeyVault -Location $Location -InRemovedState
```

### Check for all KeyVaults in a removed state
```powershell
$resourceGroupName = 'eastus-rg'
$Location = 'eastus'
$keyVaultName = 'eastus-kv'
Undo-AzKeyVaultRemoval -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $Location
```

### How to permanently delete an Azure KeyVault
```powershell
$resourceGroupName = 'eastus-rg'
$Location = 'eastus'
$keyVaultName = 'eastus-kv'
Remove-AzKeyVault -VaultName $keyVaultName -Location $Location -ResourceGroupName $resourceGroupName -Force
Remove-AzKeyVault -VaultName $keyVaultName -Location $Location -InRemovedState -Force
```
