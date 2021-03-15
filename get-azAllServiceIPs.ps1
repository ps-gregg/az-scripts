
Import-Module Azure
Add-AzureAccount -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

$allServiceIPs = @()
$subs = Get-AzureSubscription | Sort-Object SubscriptionName
foreach ($subscription in $subs) {
    Set-AzureSubscription -SubscriptionId $subscription.SubscriptionId | Out-Null
    
    $services = Get-AzureService | Group-Object -Property ServiceName
    foreach ($service in $services) {
        try {
            $IPAddress = $null
            $deployment = Get-AzureDeployment -ServiceName $service.Name -ErrorAction SilentlyContinue
            $IPAddress = $deployment.VirtualIPs[0].Address
            Write-Verbose "$($subscription.Name) - Cloud Service:  $($service.Name) - $IPAddress" -Verbose
        } catch {
            Write-Verbose "$($subscription.Name) - Cloud Service:  $($service.Name) - No deployments were found" -Verbose
        }
        
        if ($IPAddress -eq $null) { $IPAddress = "NoDeployments" }
        
        $props = [ordered]@{
            'SubscriptionName' = $subscription.Name;
            'SubscriptionId'   = $subscription.Id;
            'CloudServiceName' = $service.Name;
            'IPAddress'        = $IPAddress
        }
        $allServiceIPs += New-Object -TypeName PSObject -Property $props
    }
}

$allServiceIPs | sort ipaddress | Export-Csv .\azAllServiceIPs.csv -NoTypeInformation
