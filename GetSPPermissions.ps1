# Connect to Azure AD (two methods needed)
#Connect-AzAccount
#az login

# Init data stores
$applicationData = @()
$permissionsDict = @{}

# Get all service principals
$applications = Get-AzADServicePrincipal

# Status vars
$steps = $applications.Length
$i = 0
$stepPercentage = 100/$steps

# Loop through each application
foreach ($app in $applications) {
    ###### Status ######
    $progress = $i*$stepPercentage
    Write-Progress -Activity "Processing Service Principals" -PercentComplete $progress
    $i += 1
    ####################
    
    $appName = $app.DisplayName
    $appId = $app.AppId
    
    # Get permissions for the SP
    $appPermissions = Get-AzureADServiceAppRoleAssignedTo -ObjectId $app.Id 
    
    # if no permissions, just log an empty line
    if ($appPermissions.Length -eq 0) {
        $permissionData = [PSCustomObject]@{
            ApplicationName = $appName
            ApplicationID = $appId
            DateAttributed = "None"
            Resource = "None"
            PermissionName = "None"
        }
        $applicationData += $permissionData
    }

    # Loop through each permission
    foreach ($permission in $appPermissions) {       
        $permissionData = [PSCustomObject]@{
            ApplicationName = $appName
            ApplicationID = $appId
            DateAttributed = $permission.CreationTimestamp
            Resource = $permission.ResourceDisplayName
            PermissionName = ""
        }

        $apiId = $permission.ResourceId

        # Get the name of the permissions (only if not existing to boost perfs)
        if ( -not($permissionsDict.ContainsKey($apiId))) {
            $permissionsDict[$apiId] = @{}
            $apiData = az ad sp show --id $apiId | ConvertFrom-Json
            foreach ($tempPerm in $apiData.appRoles) {
                $permissionsDict[$apiId][$tempPerm.id] = $tempPerm.value
            }
        }

        $permissionData.PermissionName = $permissionsDict[$apiId][$permission.Id]
        $applicationData += $permissionData
    }

}

# Export data to csv
$applicationData | Export-Csv -Path "Entra_SP_Permissions.csv" -NoTypeInformation

Write-Host "Export completed. Results saved to Entra_SP_Permissions.csv"
