
# 01 =============================== 

#region Get details of the virtual machine

#$csv = Import-Csv -LiteralPath 'c:\Cos\DR\LAB\T-EUN\TEUN_TestGlobalSaaS-ASR.csv' -Delimiter ","
$csv = Import-Csv -LiteralPath 'C:\Users\deb\Desktop\T-EUN\ASRcollection.csv'

Import-Module -Name "C:\Users\deb\Desktop\T-EUN\ASRvaultCreation.ps1"
    
for ($index = 0; $index -lt $csv.Length; $index++)
{ 
        #pause
        $VM = Get-AzureRmVM -ResourceGroupName $csv[$index].SourceVMResouceGroup -Name $csv[$index].SourceVMName

        
        
#endregion

#region Create a Recovery Services vault.
   
    if($index-eq 0){
    createVault
    vaultReplication
    getStorageAccount
    $PrimaryFabric = Get-AsrFabric -Name $hcname.PrimaryASRfabric_Name
    $RecoveryFabric = Get-AsrFabric -Name $hcname.RecoveryASRJob_Name
    $PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $hcname.PContainerASRJob_Name
    $RecoveryProtContainer = Get-ASRProtectionContainer -Fabric $RecoveryFabric -Name $hcname.RContainerASRJob_Name
    $ReplicationPolicy = Get-ASRPolicy -Name $hcname.PolicyASRJob_Name
    $PrimaryTorecoveryCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $PrimaryProtContainer -Name $hcname.PContainerASRJob2_Name
    $TargetStorageAccount = Get-AzureRmStorageAccount -Name $hcname.TargetStorageAccountName -ResourceGroupName $hcname.VaultTargetVMResouceGroupName 
    $CacheStorageAccount = Get-AzureRmStorageAccount -Name $hcname.CacheStorageAccountName -ResourceGroupName $hcname.SourceVMResouceGroup
    }
    
#endregion

#region Create network mappings.

    #Create a Recovery Network in the recovery region
     $RecoveryVnet = Get-AzureRmVirtualNetwork -Name $csv[$index].TargetVNetName -ResourceGroupName $csv[$index].TargetVMResouceGroup -ErrorVariable notPresent -ErrorAction SilentlyContinue 
     if ($notPresent){
     $RecoveryVnet = New-AzureRmVirtualNetwork -Name $csv[$index].TargetVNetName -ResourceGroupName $csv[$index].TargetVMResouceGroup -Location $csv[$index].TargetVMLocation -AddressPrefix $csv[$index].AddressPrefixVnet
     Add-AzureRmVirtualNetworkSubnetConfig -Name $csv[$index].TargetSubnetName -VirtualNetwork $RecoveryVnet -AddressPrefix $csv[$index].AddressPrefixSubnet | Set-AzureRmVirtualNetwork
     }
     $RecoveryNetwork = $RecoveryVnet.Id

    #Retrieve the virtual network that the virtual machine is connected to

     #Get first network interface card(nic) of the virtual machine
     $SplitNicArmId = $VM.NetworkProfile.NetworkInterfaces[0].Id.split("/")

     #Extract resource group name from the ResourceId of the nic
     $NICRG = $SplitNicArmId[4]

     #Extract resource name from the ResourceId of the nic
     $NICname = $SplitNicArmId[-1]

     #Get network interface details using the extracted resource group name and resourec name
     $NIC = Get-AzureRmNetworkInterface -ResourceGroupName $NICRG -Name $NICname

     #Get the subnet ID of the subnet that the nic is connected to
     $PrimarySubnet = $NIC.IpConfigurations[0].Subnet

     # Extract the resource ID of the Azure virtual network the nic is connected to from the subnet ID
     $PrimaryNetwork = (Split-Path(Split-Path($PrimarySubnet.Id))).Replace("\","/")

     $P2RnetASRJob = $null
     if($index-gt 0){$P2RnetASRJob = Get-ASRNetworkMapping -PrimaryFabric $PrimaryFabric}
     if ([string]::IsNullOrEmpty($P2RnetASRJob))
     {
     #Create an ASR network mapping between the primary Azure virtual network and the recovery Azure virtual network
     $P2RnetASRJob = New-ASRNetworkMapping -AzureToAzure -Name $hcname.P2RnetASRJobName -PrimaryFabric $PrimaryFabric -PrimaryAzureNetworkId $PrimaryNetwork -RecoveryFabric $RecoveryFabric -RecoveryAzureNetworkId $RecoveryNetwork
     }
          
     #Track Job status to check for completion
     while (($P2RnetASRJob.State -eq $hcname.inprogress) -or ($P2RnetASRJob.State -eq $hcname.notstarted)){ 
             sleep 10; 
             $P2RnetASRJob = Get-ASRJob -Job $P2RnetASRJob
     }

     Write-Output  $hcname.WriteOutputmsg
    
     $F2RnetASRJob = $null
     if($index-gt 0){$F2RnetASRJob = Get-ASRNetworkMapping -PrimaryFabric $RecoveryFabric}
     if ([string]::IsNullOrEmpty($F2RnetASRJob))
     {
     #Create an ASR network mapping for failback between the recovery Azure virtual network and the primary Azure virtual network
     $F2RnetASRJob = New-ASRNetworkMapping -AzureToAzure -Name $hcname.F2RnetASRJobName -PrimaryFabric $RecoveryFabric -PrimaryAzureNetworkId $RecoveryNetwork -RecoveryFabric $PrimaryFabric -RecoveryAzureNetworkId $PrimaryNetwork
     }

     #Track Job status to check for completion
     while (($F2RnetASRJob.State -eq $hcname.inprogress) -or ($F2RnetASRJob.State -eq $hcname.notstarted)){ 
            sleep 10; 
            $F2RnetASRJob = Get-ASRJob -Job $F2RnetASRJob
      }

      Write-Output  $hcname.WriteOutputmsg
        
#endregion

#region  Replicate Azure virtual machines to a recovery region for disaster recovery.
    
    #Disk replication configuration for the OS disk
    $OSdiskId = $VM.StorageProfile.OsDisk.ManagedDisk.Id
    $RecoveryOSDiskAccountType = $VM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
    $RecoveryReplicaDiskAccountType =  $VM.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
    $RecoveryRG = Get-AzureRmResourceGroup -Name "A2ARECOVERYRG" -Location 'East US 2'

    #$OSDiskReplicationConfig = New-AzureRmRecoveryServicesAsrAzureToAzureDiskReplicationConfig -ManagedDisk $OSDiskVhdURI -LogStorageAccountId $CacheStorageAccount.Id -RecoveryAzureStorageAccountId $TargetStorageAccount.Id
    $OSDiskReplicationConfig = New-AzureRmRecoveryServicesAsrAzureToAzureDiskReplicationConfig -ManagedDisk -LogStorageAccountId $CacheStorageAccount.Id -DiskId $OSdiskId -RecoveryResourceGroupId  $RecoveryRG.ResourceId -RecoveryReplicaDiskAccountType  $RecoveryReplicaDiskAccountType -RecoveryTargetDiskAccountType $RecoveryOSDiskAccountType 
    $diskconfigs = @()
    $diskconfigs += $OSDiskReplicationConfig
    if ($VM.StorageProfile.DataDisks.Count -gt 0){
    for($dindex=0;$dindex -lt $VM.StorageProfile.DataDisks.Count;$dindex++){

    $DataDisk1VhdURI = $VM.StorageProfile.DataDisks[$dindex].ManagedDisk.Id

    #Disk replication configuration for data disk
    $DataDisk1ReplicationConfig = New-AzureRmRecoveryServicesAsrAzureToAzureDiskReplicationConfig -ManagedDisk $DataDisk1VhdURI -LogStorageAccountId $CacheStorageAccount.Id -RecoveryAzureStorageAccountId $TargetStorageAccount.Id}
    
    #Create a list of disk replication configuration objects for the disks of the virtual machine that are to be replicated.
    $diskconfigs += $DataDisk1ReplicationConfig
    }
    else{}

    #Get the resource group that the virtual machine must be created in when failed over.
    $RecoveryRG = Get-AzureRmResourceGroup -Name $csv[$index].TargetVMResouceGroup -Location $csv[$index].TargetVMLocation
    #$RecoveryAVSET = Get-AzureRmAvailabilitySet -Name $csv[$index].TargetAVSET -ResourceGroup $RecoveryRG

    #$PrimaryTorecoveryCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $PrimaryProtContainer -Name $hcname.PContainerASRJob2_Name

    #Start replication by creating replication protected item. Using a GUID for the name of the replication protected item to ensure uniqueness of name.  
    $RPIASRJob = New-ASRReplicationProtectedItem -AzureToAzure -AzureVmId $VM.Id -Name (New-Guid).Guid -ProtectionContainerMapping $PrimaryTorecoveryCMapping -AzureToAzureDiskReplicationConfiguration $diskconfigs -RecoveryResourceGroupId $RecoveryRG.ResourceId 
                 #New-ASRReplicationProtectedItem -AzureToAzure -AzureVmId $VM.Id -Name (New-Guid).Guid -ProtectionContainerMapping $EuropeToCfrancePCMapping -AzureToAzureDiskReplicationConfiguration $diskconfigs -RecoveryResourceGroupId $RecoveryRG.ResourceId
    #Track Job status to check for completion
    while ($RPIASRJob.State -eq $hcname.notstarted){ 
            sleep 10; 
            $RPIASRJob = Get-ASRJob -Job $RPIASRJob
    }

}
   Write-Output  $hcname.WriteOutputmsg

#endregion 
