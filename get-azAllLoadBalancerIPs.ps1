
$groupName = 'xxxxxxxxxxxxxxxxxxxxxxxxxx'
$subscriptions = (Get-AzManagementGroup -GroupName $groupName -Expand).Children

$allLoadBalancerIPs = @()
$allazLoadBalancers = @()
foreach ($subscription in $subscriptions) {
    Write-verbose "Subscription: $($subscription.Name)" -Verbose
    Set-AzContext -SubscriptionId $subscription.Name | Out-Null

    $resourcegroups = Get-AzResourceGroup
    foreach ($rgroup in $resourcegroups) {
        Write-verbose "   RG: $($rgroup.resourcegroupname)" -Verbose
        $azLoadBalancers = Get-AzLoadBalancer -ResourceGroupName $rgroup.resourcegroupname
        $allazLoadBalancers += $azLoadBalancers
        foreach ($loadBalancer in $azLoadBalancers) {
            $publicIpAddress = Get-AzResource -ResourceId $loadBalancer.FrontendIpConfigurations.PublicIpAddress.Id
            $IP = (Get-AzLoadBalancer -Name $loadBalancer.Name -ResourceGroupName $loadBalancer.resourcegroupname).FrontendIpConfigurations.PublicIpAddress

            if ($ip -ne $null) {
                foreach ($addr in $ip) {
                    $props = @{
                        'SubscriptionName'  = $subscription.DisplayName;
                        'SubscriptionId'    = $subscription.Id;
                        'ResourceGroupName' = $rgroup.resourcegroupname;
                        'Name'              = $loadBalancer.Name;
                        'IpAddress'         = $loadBalancer.FrontendIpConfigurations.PublicIpAddress.Id;
                    }
                    $allLoadBalancerIPs += New-Object -TypeName PSObject -Property $props
                }
            }
        }
    }
}


$allLoadBalancerIPs | sort IpAddress | Export-Csv .\azAllLoadBalancerIPs.csv -NoTypeInformation
