#requires -module @{ModuleName = 'Az.Accounts'; ModuleVersion = '1.5.2'}
#requires -version 6.2

function Get-AzSentinelPlayBook {
    <#
      .SYNOPSIS
      Get Logic App Playbook
      .DESCRIPTION
      This function is used for resolving the Logic App and testing the compability with Azure Sentinel
      .PARAMETER SubscriptionId
      Enter the subscription ID, if no subscription ID is provided then current AZContext subscription will be used
      .PARAMETER Name
      Enter the Logic App name
      .EXAMPLE
      Get-AzSentinelPlayBook -Name ""
      This example will get search for the Logic app within the current subscripbtio and test to see if it's compatible for Sentinel
      .NOTES
      NAME: Get-AzSentinelPlayBook
    #>
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter()]
        [ValidateSet("AzureUsGovernment")]
        [string]$Environment
    )

    begin {
        precheck
    }

    process {

        $triggerName = 'When_a_response_to_an_Azure_Sentinel_alert_is_triggered'

        if ($SubscriptionId) {
            Write-Verbose "Getting LogicApp from Subscription $($subscriptionId)"
            switch ($EnvironmentName) {
                AzureUsGovernment { $uri = $uri = "https://management.usgovcloudapi.net/subscriptions/$($subscriptionId)/providers/Microsoft.Logic/workflows?api-version=2016-06-01" }
                default { $uri = "https://management.usgovcloudapi.net/subscriptions/$($subscriptionId)/providers/Microsoft.Logic/workflows?api-version=2016-06-01" }
            }
        }
        elseif ($script:subscriptionId) {
            Write-Verbose "Getting LogicApp from Subscription $($script:subscriptionId)"
            switch ($EnvironmentName) {
                AzureUsGovernment { $uri = "https://management.usgovcloudapi.net/subscriptions/$($script:subscriptionId)/providers/Microsoft.Logic/workflows?api-version=2016-06-01" }
                default { $uri = "https://management.azure.com/subscriptions/$($script:subscriptionId)/providers/Microsoft.Logic/workflows?api-version=2016-06-01" }
            }
        }
        else {
            $return = "No SubscriptionID provided"
            return $return
        }

        try {
            $logicappRaw = (Invoke-RestMethod -Uri $uri -Method Get -Headers $script:authHeader)
            $logicapp = $logicappRaw.value
            while ($logicappRaw.nextLink) {
                $logicappRaw = (Invoke-RestMethod -Uri $($logicappRaw.nextLink) -Headers $script:authHeader -Method Get)
                $logicapp += $logicappRaw.value
            }
            $playBook = $logicapp | Where-Object { $_.name -eq $Name }
            if ($playBook){
                switch ($EnvironmentName) {
                    AzureUsGovernment { $uri1 = "https://management.usgovcloudapi.net$($playBook.id)/triggers/$($triggerName)/listCallbackUrl?api-version=2016-06-01" }
                    default { $uri1 = "https://management.azure.com$($playBook.id)/triggers/$($triggerName)/listCallbackUrl?api-version=2016-06-01" }
                }

                try {
                    $playbookTrigger = (Invoke-RestMethod -Uri $uri1 -Method Post -Headers $script:authHeader)
                    $playbookTrigger | Add-Member -NotePropertyName ResourceId -NotePropertyValue $playBook.id -Force

                    return $playbookTrigger
                }
                catch {
                    $return = "Playbook $($Name) doesn't start with 'When_a_response_to_an_Azure_Sentinel_alert_is_triggered' step! Error message: $($_.Exception.Message)"
                    Write-Error $return
                }
            }
            else {
                Write-Warning "Unable to find LogicApp $Name under Subscription Id: $($script:subscriptionId)"
            }
        }
        catch {
            $return = $_.Exception.Message
            Write-Error $return
        }
    }
}
