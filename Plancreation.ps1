# 02 ================================
#region Monitor the replication state and replication health for the virtual machine by getting details of the replication protected item corresponding to it....

    Get-ASRReplicationProtectedItem -ProtectionContainer $PrimaryProtContainer | Select FriendlyName, ProtectionState, ReplicationHealth,ProtectableItem

#endregion

#region Creates an ASR recovery plan   
  
    $ReplicationProtectedItem = Get-ASRReplicationProtectedItem  -ProtectionContainer $PrimaryProtContainer 
    $hcname =getConstants
    $RPName=$hcname.RPName 
    $Asrplan = Get-AzureRmRecoveryServicesAsrRecoveryPlan -Name $RPName -ErrorVariable notPresent -ErrorAction SilentlyContinue 
     if ($notPresent){
    $Asrplan = New-AzureRmRecoveryServicesAsrRecoveryPlan -Name $RPName -PrimaryFabric $PrimaryFabric -RecoveryFabric $RecoveryFabric -ReplicationProtectedItem $ReplicationProtectedItem}
    

#endregion

