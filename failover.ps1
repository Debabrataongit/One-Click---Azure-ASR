
#04 =================================

#region  Failover the virtual machine to a specific recovery point.
    
    #Start the failover job
    $Job_Failover = Start-ASRUnplannedFailoverJob -RecoveryPlan $Asrplan -Direction PrimaryToRecovery #-RecoveryPoint $RecoveryPoints[-1]

        do {
                $Job_Failover = Get-ASRJob -Job $Job_Failover;
                sleep 30;
        } while (($Job_Failover.State -eq "InProgress") -or ($JobFailover.State -eq "NotStarted"))

        $Job_Failover.State 
        Write-Output  $hcname.WriteOutputmsg
   
#endregion

#region Starts the commit failover action for a Site Recovery object.

Start-AzureRmRecoveryServicesAsrCommitFailoverJob -RecoveryPlan $Asrplan
   
#endregion



# 05 ================================

#region Updates the replication direction for the specified replication protected item or recovery plan. Used to re-protect/reverse replicate a failed over replicated item or recovery plan.
  
    $job = Update-AzureRmRecoveryServicesAsrProtectionDirection -AzureToAzure -LogStorageAccountId $hcname.LogStorageAccountId -ProtectionContainerMapping $franceToEuropePCMapping -RecoveryAzureStorageAccountId $hcname.RecoveryAzureStorageAccountId -RecoveryResourceGroupId $hcname.RecoveryResourceGroupId -ReplicationProtectedItem $ReplicationProtectedItem.GetValue(1) #-RecoveryAvailabilitySetId $recoveryAVSetIdYtoX    


    $ReplicationProtectedItem = Get-ASRReplicationProtectedItem  -ProtectionContainer $RecoveryProtContainer
    for ($index = 0; $index -lt $ReplicationProtectedItem.Count; $index++)
        {
            $RecoveryPointsFailback = Get-ASRRecoveryPoint -ReplicationProtectedItem $ReplicationProtectedItem

            #The list of recovery points returned may not be sorted chronologically and will need to be sorted first, in order to be able to find the oldest or the latest recovery points for the virtual machine.
            "{0} {1}" -f $RecoveryPointsFailback[0].RecoveryPointType, $RecoveryPointsFailback[-1].RecoveryPointTime


            #Start the failback job
            $Job_Failback = Start-ASRUnplannedFailoverJob -ReplicationProtectedItem $ReplicationProtectedItem -Direction PrimaryToRecovery -RecoveryPoint $RecoveryPointsFailback[-1]


            do {
                    $Job_Failback = Get-ASRJob -Job $Job_Failback;
                    sleep 30;
            } while (($Job_Failback.State -eq "InProgress") -or ($Job_Failback.State -eq "NotStarted"))

            $Job_Failback.State
            Write-Output  $hcname.WriteOutputmsg
        }
#endregion

