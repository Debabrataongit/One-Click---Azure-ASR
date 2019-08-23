
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
##################################################################################################

#$VMs_Names = @()
#$VMs_Names = get-AzureRMVM | where {($_.Name -match 'DC0') -OR ($_.Name -match 'EUN-CXA0') -OR ($_.Name -match 'EUN-CXC0') -OR ($_.Name -match 'EUN-CXD0') -OR ($_.Name -match 'FTP') -OR ($_.Name -match 'SUS0') -OR ($_.Name -match 'LIC0') -OR ($_.Name -match 'BW-SQLP01') -OR ($_.Name -match 'BW-WEBP01') -OR ($_.Name -match 'BW-APPP01') -OR ($_.Name -match 'MFN-WEBP01') -OR ($_.Name -match 'MFN-SQLP01') -OR ($_.Name -match 'EUNPV-APPP01') -OR ($_.Name -match 'EUNPV-SQLP01') -OR ($_.Name -match 'EUNPV-CXA0') -OR ($_.Name -match 'RD1SM')}
#$VMs_Names  = $VMs_Names | Get-AzureRMVm

$VMs_Names = get-AzureRMVM | where {($_.Name -match 'FTP9')}
$VMs_Names  = $VMs_Names | Get-AzureRMVm

######################################################################
# FUNCTIONS
######################################################################

$DR_Prefix = "ASR-"
$DR_SAPrefix = "asr"

Function Convert-ObjectName
{
  [CmdletBinding()]
  param([String]$Name, [String]$PRI, [String]$DR, [Boolean]$IsSA=$False, [Boolean]$IsASRCache=$False)
  IF ($Name -eq "GatewaySubnet")
  {
    $NewName = $Name
  }
  ELSE
  {
    IF ($IsSA -eq $True)
    {
      $PRI = $PRI.ToLower()
      $DR = $DR.ToLower()
      $Name = $Name.ToLower()
      IF ($IsASRCache -eq $True)
        {
        $NewName = $DR_SAPrefix + $Name + 'stndcache'
        }
      ELSE
        {
        $NewName = $DR_SAPrefix + $Name.Replace($PRI,$DR)
        }
      $NewName = ($NewName.Replace("-","")).ToLower()
      }
    ELSE
      {
      $NewName = $DR_Prefix + $Name.Replace($PRI,$DR)
      }
  }
  Return $NewName
}

Function Find-Region
{
  [CmdletBinding()]
  param ($RegionNameORCode,[ValidateSet('MyRegion','DRRegion',ignorecase = $False)]$Type)
  SWITCH ($RegionNameORCode)
  {
    'northeurope' {$Result = @('northeurope','EUN','100','westeurope','EUW')}
    'southcentralus' {$Result = @('southcentralus','USS','110','northcentralus','USN')}
    'canadaeast' {$Result = @('canadaeast','CAE','130','canadacentral','CAC')}
    'uksouth' {$Result = @('uksouth','UKS','140','ukwest','UKW')}
    'australiasoutheast' {$Result = @('australiasoutheast','AUS','120','australiaeast','AUE')}
    'southeastasia' {$Result = @('southeastasia','ASG','105','eastasia','ASE')}
    'EUN' {$Result = @('northeurope','EUN','100','westeurope','EUW')}
    'USS' {$Result = @('southcentralus','USS','110','northcentralus','USN')}
    'CAE' {$Result = @('canadaeast','CAE','130','canadacentral','CAC')}
    'UKS' {$Result = @('uksouth','UKS','140','ukwest','UKW')}
    'AUS' {$Result = @('australiasoutheast','AUS','120','australiaeast','AUE')}
    'ASG' {$Result = @('southeastasia','ASG','105','eastasia','ASE')}
  }
  SWITCH ($Type)
  {
    'MyRegion' {$Result = $Result[0,1,2]}
    'DRRegion' {$Result = $Result[3,4]}
  }
  Return $Result
}

$ALL_VMs = @()

ForEach ($VM_Name in $VMs_Names)
    {
    $VM_Name.Name
    $VM = Get-AzureRMVM -name $VM_Name.Name -ResourceGroupName $VM_Name.ResourceGroupName
    $My_RegionName = (Find-Region -RegionNameORCode $VM.Location -Type MyRegion)[0]
    $My_Region = (Find-Region -RegionNameORCode $VM.Location -Type MyRegion)[1]
    $DR_RegionName = (Find-Region -RegionNameORCode $VM.Location -Type DRRegion)[0]
    $DR_Region = (Find-Region -RegionNameORCode $VM.Location -Type DRRegion)[1]
    $DR_RGName = Convert-ObjectName -Name $($VM.ResourceGroupName) -PRI $My_Region -DR $DR_Region
    $RV_RGName = Convert-ObjectName -Name $DR_Region -PRI $My_Region -DR $DR_Region
    $RV_Name = $RV_RGName + "-RV1"
    $RecoveryPlan_Name = "RecoveryPlan-001"
    $ASRPolicyName = "Recovery24H-Snapshot1H"
    $VM_NIC = Get-AzureRMNetworkInterface -Name (($VM.NetworkProfile.NetworkInterfaces[0].Id).Split("/")[-1]) -ResourceGroupName $VM.ResourceGroupName
    $VM_VNETName = COnvert-ObjectName -name ($VM_NIC.IpConfigurations[0].Subnet.Id).Split("/")[-3] -PRI $My_Region -DR $DR_Region
    $VM_SUBNETName = COnvert-ObjectName -name ($VM_NIC.IpConfigurations[0].Subnet.Id).Split("/")[-1] -PRI $My_Region -DR $DR_Region
    $VM_SAName = Convert-ObjectName -name (($VM.StorageProfile.OsDisk.Vhd.Uri).Split("/")[2]).Split(".")[0] -PRI $My_Region -DR $DR_Region -IsSA $True -IsASRCache $False
    $VM_CAcheSAName = Convert-ObjectName -name $VM_Name.ResourceGroupName -PRI $My_Region -DR $DR_Region -IsSA $True -IsASRCache $True
    $VM_VNET = Get-AzureRMVirtualNetwork | where {$_.Name -eq $VM_VNETName}
    $VM_VNETAddress = $VM_VNET.AddressSpace.AddressPrefixes
    $VM_SUBNETAddress = (Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VM_VNET -Name $VM_SUBNETName).AddressPrefix
    $VM_AVSETName = Convert-ObjectName -Name ($VM.AvailabilitySetReference.Id).Split("/")[-1] -PRI $My_Region -DR $DR_Region
    $ThisVM = $VM | Select-Object @{Name="SourceVMName"; Expression={$_.Name}},@{Name="SourceVMResouceGroup"; Expression={$_.ResourceGroupName}},@{Name="SourceVMLocation"; Expression={$My_RegionName}},@{Name="TargetVMResouceGroup"; Expression={$DR_RGName}},@{Name="TargetVMLocation"; Expression={$DR_RegionName}},@{Name="ASRRecoveryVaultName"; Expression={$RV_Name}},@{Name="ASRRecoveryVaultGroup"; Expression={$RV_RGName}},@{Name="RecoveryPlan"; Expression={$RecoveryPlan_Name}},@{Name="ASRPolicyName"; Expression={$ASRPolicyName}},@{Name="TargetVNetName"; Expression={$VM_VNETName}},@{Name="TargetSubnetName"; Expression={$VM_SUBNETName}},@{Name="TargetStorageAccountName"; Expression={$VM_SAName}},@{Name="CacheStorageAccountName"; Expression={$VM_CAcheSAName}},@{Name="AddressPrefixVnet"; Expression={$VM_VNETAddress}},@{Name="AddressPrefixSubnet"; Expression={$VM_SUBNETAddress}},@{Name="TargetAVSET"; Expression={$VM_AVSETName}}
    $ALL_VMs+= $ThisVM
    }
$ALL_VMs | Select-Object SourceVMName,SourceVMResouceGroup,SourceVMLocation,TargetVMResouceGroup,TargetVMLocation,ASRRecoveryVaultName,ASRRecoveryVaultGroup,RecoveryPlan,ASRPolicyName,TargetVNetName,TargetSubnetName,TargetStorageAccountName,CacheStorageAccountName,AddressPrefixVnet,AddressPrefixSubnet,TargetAVSET | ConvertTo-CSV -Delimiter ";" -NoTypeInformation | % {$_.Replace('"','')} | Out-File -FilePath C:\Cos\DR\LAB\T-EUN\TEUN_list.csv -Encoding ascii -Force
