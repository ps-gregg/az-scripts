
$groupName = 'xxxxxxxxxxxxxxxxxxxxxxxxxx'
$subscriptions = (Get-AzManagementGroup -GroupName $groupName -Expand).Children

$allpublicIPs = @()
foreach ($subscription in $subscriptions) {
    Write-verbose "Subscription: $($subscription.Name)" -Verbose
    Set-azcontext -SubscriptionId $subscription.Name | Out-Null

    $subscriptionpublicIPs = Get-AzPublicIpAddress  
    foreach ($publicIP in $subscriptionpublicIPs) {
        $props = @{
            'SubscriptionName'  = $subscription.DisplayName;
            'SubscriptionId'    = $subscription.Id;
            'Name'              = $publicIP.name;
            'IPAddress'         = $publicIP.IPaddress;
            'ResourceGroupName' = $publicIP.ResourceGroupName;
            'Location'          = $publicIP.Location;
            'Id'                = $publicIP.Id;
        }
        $allpublicIPs += New-Object -TypeName PSObject -Property $props
    }        
}

$allpublicIPs | sort ipaddress | Export-Csv .\azAllPublicIPs.csv -NoTypeInformation
