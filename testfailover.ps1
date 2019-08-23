
# 03 ================================

#region TestFailover

    
    $TFOVnet = New-AzureRmVirtualNetwork -Name $hcname.TFOVnetName -ResourceGroupName $hcname.TFOResourceGroupName -Location $hcname.TFOLocation -AddressPrefix $hcname.TFOAddressPrefix
    Add-AzureRmVirtualNetworkSubnetConfig -Name $hcname.TFOSubnetName -VirtualNetwork $TFOVnet -AddressPrefix $hcname.TFOSubnetAddressPrefix | Set-AzureRmVirtualNetwork
    $TFONetwork= $TFOVnet.Id
   
    $TFOJob = Start-ASRTestFailoverJob -RecoveryPlan $Asrplan -AzureVMNetworkId $TFONetwork  -Direction PrimaryToRecovery

    Get-ASRJob -Job $TFOJob
    Write-Output  $hcname.WriteOutputmsg

#endregion

#region Once testing is complete on the test failed over virtual machine, cleaning up  test copy by starting the cleanup test failover operation. 

    $Job_TFOCleanup = Start-ASRTestFailoverCleanupJob -RecoveryPlan $Asrplan

    Get-ASRJob -Job $Job_TFOCleanup | Select State
    Write-Output  $hcname.WriteOutputmsg

#endregion


