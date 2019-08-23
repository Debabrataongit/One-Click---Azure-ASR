
#region constants

    $cname = Import-CSV -Path "c:\Cos\DR\LAB\T-EUN\ASRvaultCreation.csv"
    $hcname=@{}
    
    function getConstants 
        {
            $returnObj=@{}
            foreach($index in $cname)
            {
                $returnObj[$index.Name]=$index.Value
            }
            return $returnObj
        }
    $hcname =getConstants
#endregion

#region Set the vault context for the PowerShell session.

    function createVault{

    #Create a resource group for the recovery services vault in the recovery Azure region
    Get-AzureRmResourceGroup -Name $hcname.VaultTargetVMResouceGroupName -Location $hcname.VaultTargetVMLocation -ErrorVariable notPresent -ErrorAction SilentlyContinue 
    if ($notPresent){
    New-AzureRmResourceGroup -Name $hcname.VaultTargetVMResouceGroupName -Location $hcname.VaultTargetVMLocation}

    #Create a new Recovery services vault in the recovery region
    $vault = New-AzureRmRecoveryServicesVault -Name $hcname.ASRRecoveryVaultName -ResourceGroupName $hcname.VaultTargetVMResouceGroupName -Location $hcname.VaultTargetVMLocation
   
    $VaultsettingsfilePath = $hcname.VaultsettingsfilePath

    #Download the vault settings file for the vault.
    $Vaultsettingsfile = Get-AzureRmRecoveryServicesVaultSettingsFile -Vault $vault -SiteRecovery -Path $VaultsettingsfilePath

    #Import the downloaded vault settings file to set the vault context for the PowerShell session.
    Import-AzureRmRecoveryServicesAsrVaultSettingsFile -Path $Vaultsettingsfile.FilePath

    #Delete the downloaded vault settings file
    Remove-Item -Path $Vaultsettingsfile.FilePath

    
    }
#endregion 

#region Prepare the vault to start replicating Azure virtual machines
    function vaultReplication{
    #1.Create a Site Recovery fabric object to represent the primary(source) region

    #Create Primary ASR fabric
    $PrimaryASRJob = New-ASRFabric -Azure -Location $hcname.PrimaryASRfabric_Location  -Name $hcname.PrimaryASRfabric_Name 

    # Track Job status to check for completion
    while (($PrimaryASRJob.State -eq "InProgress") -or ($PrimaryASRJob.State -eq "NotStarted")){ 
            #If the job hasn't completed, sleep for 10 seconds before checking the job status again
            sleep 10; 
            $PrimaryASRJob = Get-ASRJob -Job $PrimaryASRJob
            }

    #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
    Write-Output "Primary fabric object has been created successfully" # $PrimaryASRJob.State
    
    $PrimaryFabric = Get-AsrFabric -Name $hcname.PrimaryASRfabric_Name
    
    #2. Create a Site Recovery fabric object to represent the recovery region

    #Create Recovery ASR fabric
    $RecoveryASRJob = New-ASRFabric -Azure -Location $hcname.RecoveryASRJob_Location  -Name $hcname.RecoveryASRJob_Name 

    # Track Job status to check for completion
    while (($RecoveryASRJob.State -eq "InProgress") -or ($RecoveryASRJob.State -eq "NotStarted")){ 
            sleep 10; 
            $RecoveryASRJob = Get-ASRJob -Job $RecoveryASRJob
            }

    #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
    Write-Output "Recovery fabric object has been created successfully" #$RecoveryASRJob.State

    $RecoveryFabric = Get-AsrFabric -Name $hcname.RecoveryASRJob_Name

    #3. Create a Site Recovery protection container in the primary fabric

    #Create a Protection container in the primary Azure region (within the Primary fabric)
    $PContainerASRJob = New-AzureRmRecoveryServicesAsrProtectionContainer -InputObject $PrimaryFabric -Name $hcname.PContainerASRJob_Name

    #Track Job status to check for completion
    while (($PContainerASRJob.State -eq "InProgress") -or ($PContainerASRJob.State -eq "NotStarted")){ 
            sleep 10; 
            $PContainerASRJob = Get-ASRJob -Job $PContainerASRJob
            }

    Write-Output "Primary protection container object has been created successfully" #$PContainerASRJob.State

    $PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $hcname.PContainerASRJob_Name

    #4. Create a Site Recovery protection container in the recovery fabric
    #Create a Protection container in the recovery Azure region (within the Recovery fabric)
    $RContainerASRJob = New-AzureRmRecoveryServicesAsrProtectionContainer -InputObject $RecoveryFabric -Name $hcname.RContainerASRJob_Name

    #Track Job status to check for completion
    while (($RContainerASRJob.State -eq "InProgress") -or ($RContainerASRJob.State -eq "NotStarted")){ 
            sleep 10; 
            $RContainerASRJob = Get-ASRJob -Job $RContainerASRJob
            }

    #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
    Write-Output "Recovery protection container object has been created successfully" #$RContainerASRJob.State

    $RecoveryProtContainer = Get-ASRProtectionContainer -Fabric $RecoveryFabric -Name $hcname.RContainerASRJob_Name

    #5. Create a replication policy

    #Create replication policy
    $PolicyASRJob = New-ASRPolicy -AzureToAzure -Name $hcname.PolicyASRJob_Name -RecoveryPointRetentionInHours $hcname.PolicyASRJob_Recovery -ApplicationConsistentSnapshotFrequencyInHours $hcname.PolicyASRJob_Snapshot

    #Track Job status to check for completion
    while (($PolicyASRJob.State -eq "InProgress") -or ($PolicyASRJob.State -eq "NotStarted")){ 
            sleep 10; 
            $PolicyASRJob = Get-ASRJob -Job $PolicyASRJob
            }

    #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
    Write-Output "Replication policy object has been created successfully" #$PolicyASRJob.State

    $ReplicationPolicy = Get-ASRPolicy -Name $hcname.PolicyASRJob_Name

    #6. Create a protection container mapping between the primary and recovery protection container

    #Create Protection container mapping between the Primary and Recovery Protection Containers with the Replication policy
    $PContainerASRJob2 = New-ASRProtectionContainerMapping -Name $hcname.PContainerASRJob2_Name -Policy $ReplicationPolicy -PrimaryProtectionContainer $PrimaryProtContainer -RecoveryProtectionContainer $RecoveryProtContainer

    #Track Job status to check for completion
    while (($PContainerASRJob2.State -eq "InProgress") -or ($PContainerASRJob2.State -eq "NotStarted")){ 
            sleep 10; 
            $PContainerASRJob2 = Get-ASRJob -Job $PContainerASRJob2
            }

    #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
    Write-Output "Primary container mapping for failover object has been created successfully"  # $PContainerASRJob2.State

    $PrimaryTorecoveryCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $PrimaryProtContainer -Name $hcname.PContainerASRJob2_Name

    #7. Create a protection container mapping for failback (reverse replication after a failover)

    #Create Protection container mapping (for failback) between the Recovery and Primary Protection Containers with the Replication policy 
    $PContainerASRJob3 = New-ASRProtectionContainerMapping -Name $hcname.PContainerASRJob3_Name -Policy $ReplicationPolicy -PrimaryProtectionContainer $RecoveryProtContainer -RecoveryProtectionContainer $PrimaryProtContainer

    #Track Job status to check for completion
    while (($PContainerASRJob3.State -eq "InProgress") -or ($PContainerASRJob3.State -eq "NotStarted")){ 
            sleep 10; 
            $PContainerASRJob3 = Get-ASRJob -Job $PContainerASRJob3

            #$WeuropeToNeuropePCMapping = Get-ASRProtectionContainerMapping -ProtectionContainer $RecoveryProtContainer -Name $hcname.PContainerASRJob3_Name
            }

    #Check if the Job completed successfully. The updated job state of a successfuly completed job should be "Succeeded"
    Write-Output "Protection container mapping for failback object has been created successfully" #$PContainerASRJob3.State
    }

   
#endregion

#region Create storage accounts to replicate virtual machines
    function getStorageAccount{

    #Create Target storage account in the recovery region. In this case a Standard Storage account
    $TargetStorageAccount = Get-AzureRmStorageAccount -Name $hcname.TargetStorageAccountName -ResourceGroupName $hcname.VaultTargetVMResouceGroupName -ErrorAction Ignore
    if ($TargetStorageAccount.StorageAccountName -ne $hcname.TargetStorageAccountName)  
        {    
            $TargetStorageAccount = New-AzureRmStorageAccount -Name $hcname.TargetStorageAccountName -ResourceGroupName $hcname.VaultTargetVMResouceGroupName -Location $hcname.VaultTargetVMLocation -SkuName Standard_LRS -Kind Storage
        }
      
    #Create Cache storage account for replication logs in the primary region
    $CacheStorageAccount = Get-AzureRmStorageAccount -Name $hcname.CacheStorageAccountName -ResourceGroupName $hcname.SourceVMResouceGroup -ErrorAction Ignore
        if ($CacheStorageAccount.StorageAccountName -ne $hcname.CacheStorageAccountName)  
        {    
            $CacheStorageAccount = New-AzureRmStorageAccount -Name $hcname.CacheStorageAccountName -ResourceGroupName $hcname.SourceVMResouceGroup -Location $hcname.SourceVMLocation -SkuName Standard_LRS -Kind Storage
        }}        
#endregion
