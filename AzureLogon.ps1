##################################################################################################
<#
Write-Output "`nProcessing Azure Logon STARTED"
IF ([string]::IsNullOrEmpty($(Get-AzureRmContext).Account))
    {
    Write-Output "Performing Azure Logon process... STARTED"
    Login-AzureRmAccount
    Write-Output "Performing Azure Logon process... FINISHED"
    }
ELSE
    {
    Write-Output "`tYou have ben already logged in as [$($(Get-AzureRmContext).Account)] !!!`n"
    }

Get-AzureRmSubscription
$Subscription1 = Get-AzureRmSubscription -SubscriptionName 'Unit4 SaaS Global Operations'
$Subscription2 = Get-AzureRmSubscription -SubscriptionName 'Global Cloud - EU'
$Subscription3 = Get-AzureRmSubscription -SubscriptionName 'Unit4 Departmental Managed Cloud Global Operations Prod'
$Subscription8 = Get-AzureRmSubscription -SubscriptionName 'Microsoft Azure'
$Subscription9 = Get-AzureRmSubscription -SubscriptionName 'Global Cloud Test Subscription'

Select-AzureRmSubscription -SubscriptionName $Subscription9

Write-Output "Processing Azure Logon FINISHED"
#>

Import-Module -Name AzureRM -NoClobber