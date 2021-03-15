
$groupName = 'xxxxxxxxxxxxxxxxxxxxxxxxxx'
$subscriptions = (Get-AzManagementGroup -GroupName $groupName -Expand).Children

$allPrivateIPs = @()
foreach ($subscription in $subscriptions) {
    Write-verbose "Subscription: $($subscription.Name)" -Verbose
    Set-AzContext -SubscriptionId $subscription.Name | Out-Null

    $azResourceGroups = Get-AzResourceGroup
    foreach ($rgroup in $azResourceGroups) {
        $azNetworkInterfaces = Get-AzNetworkInterface -ResourceGroupName $rgroup.resourcegroupname
        foreach ($nic in $azNetworkInterfaces) {
            $ipcfg = Get-AzNetworkInterfaceIpConfig -NetworkInterface $nic
            foreach ($cfg in $ipcfg) {
                $props = @{
                    'SubscriptionName'     = $subscription.DisplayName;
                    'SubscriptionId'       = $subscription.Id;
                    'ResourceGroupName'    = $nic.resourceGroupName;
                    'Location'             = $nic.Location;
                    'NetworkInterfaceName' = $nic.Name;
                    'NetworkInterfaceId'   = $nic.Id;
                    'PrivateIpAddress'     = $cfg.PrivateIpAddress;
                }
                $allPrivateIPs += New-Object -TypeName PSObject -Property $props
            }
        }
    }
}

$allPrivateIPs | sort PrivateIpAddress | Export-Csv .\azAllPrivateIPs.csv -NoTypeInformation
