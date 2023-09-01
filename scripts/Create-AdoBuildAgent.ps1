<#
.SYNOPSIS
Create Virtual Machine Scale-set
.DESCRIPTION
Create Virtual Machine Scale-set for private build agent using image from the shared compute gallery.
.PARAMETER imageGalleryTenantId
Mandatory. Image Gallery Tenant Id.
.PARAMETER tenantId
Mandatory. Tenant Id.
.PARAMETER subscriptionName
Mandatory. Subscription Name.
.PARAMETER resourceGroup
Mandatory. Resource Group Name.
.PARAMETER vmssName
Mandatory. Virtual Machine Scale-Set name.
.PARAMETER subnetId
Mandatory. Subnet ResourceId.
.PARAMETER imageId
Mandatory. Shared Gallery Image Reference Id.
.PARAMETER adoAgentUser
Mandatory. VM instance login user name.
.PARAMETER adoAgentPass
Mandatory. VM instance login password.
.EXAMPLE
.\Create-AdoBuildAgent.ps1  -imageGalleryTenantId <imageGalleryTenantId> -tenantId <tenantId> -subscriptionName <subscriptionName> -resourceGroup <resourceGroup> `
                            -vmssName <vmssName> -subnetId <subnetId> -imageId <imageId> -adoAgentUser <adoAgentUser> -adoAgentPass <adoAgentPass>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $imageGalleryTenantId,
    [Parameter(Mandatory)]
    [string] $tenantId,
    [Parameter(Mandatory)]
    [string] $subscriptionName,
    [Parameter(Mandatory)]
    [string] $resourceGroup,
    [Parameter(Mandatory)]
    [string] $vmssName,
    [Parameter(Mandatory)]
    [string] $subnetId,
    [Parameter(Mandatory)]
    [string] $imageId,
    [Parameter(Mandatory)]
    [string] $adoAgentUser,
    [Parameter(Mandatory)]
    [string] $adoAgentPass
)

Set-StrictMode -Version 3.0

[string]$functionName = $MyInvocation.MyCommand
[datetime]$startTime = [datetime]::UtcNow

[int]$exitCode = -1
[bool]$setHostExitCode = (Test-Path -Path ENV:TF_BUILD) -and ($ENV:TF_BUILD -eq "true")
[bool]$enableDebug = (Test-Path -Path ENV:SYSTEM_DEBUG) -and ($ENV:SYSTEM_DEBUG -eq "true")

Set-Variable -Name ErrorActionPreference -Value Continue -scope global
Set-Variable -Name InformationPreference -Value Continue -Scope global

if ($enableDebug) {
    Set-Variable -Name VerbosePreference -Value Continue -Scope global
    Set-Variable -Name DebugPreference -Value Continue -Scope global
}

Write-Host "${functionName} started at $($startTime.ToString('u'))"
Write-Debug "${functionName}:imageGalleryTenantId=$imageGalleryTenantId"
Write-Debug "${functionName}:tenantId=$tenantId"
Write-Debug "${functionName}:subscriptionName=$subscriptionName"
Write-Debug "${functionName}:resourceGroup=$resourceGroup"
Write-Debug "${functionName}:vmssName=$vmssName"
Write-Debug "${functionName}:subnetId=$subnetId"
Write-Debug "${functionName}:imageId=$imageId"

try {
    az account clear

    if ($imageGalleryTenantId -ne $tenantId) {
        $output = az login --service-principal -u $env:servicePrincipalId -p $env:servicePrincipalKey --tenant $imageGalleryTenantId
        Write-Debug ([array]$output | Out-String)
        $output = az account get-access-token
    }

    $output = az login --service-principal -u $env:servicePrincipalId -p $env:servicePrincipalKey --tenant $tenantId
    Write-Debug ([array]$output | Out-String)
    $output = az account get-access-token

    $output = az account set --subscription $subscriptionName
    Write-Debug ([array]$output | Out-String)

    $instances = az vmss list --resource-group $resourceGroup | ConvertFrom-Json
    if (-not ($instances.name -contains $vmssName)) {
        Write-Host "Creating VMSS: $vmssName..."
        $output = az vmss create `
            --resource-group $resourceGroup `
            --name $vmssName `
            --computer-name-prefix $vmssName `
            --vm-sku Standard_D4s_v4 `
            --instance-count 2 `
            --subnet $subnetId `
            --image "$imageId" `
            --authentication-type password `
            --admin-username $adoAgentUser `
            --admin-password "$adoAgentPass" `
            --disable-overprovision `
            --upgrade-policy-mode Manual `
            --public-ip-address '""' `
            --tags ServiceName='ADP' ServiceCode='CDO' Name=$vmssName Purpose='ADO Build Agent'
        Write-Debug ([array]$output | Out-String)
    }
    else {
        Write-Host "VMSS: $vmssName already exists!"
    }

    $exitCode = 0
}
catch {
    $exitCode = -2
    Write-Error $_.Exception.ToString()
    throw $_.Exception
}
finally {
    [DateTime]$endTime = [DateTime]::UtcNow
    [Timespan]$duration = $endTime.Subtract($startTime)

    Write-Host "${functionName} finished at $($endTime.ToString('u')) (duration $($duration -f 'g')) with exit code $exitCode"
    if ($setHostExitCode) {
        Write-Debug "${functionName}:Setting host exit code"
        $host.SetShouldExit($exitCode)
    }
    exit $exitCode
}