################################################################################
##  File:  Install-Toolset.ps1
##  Team:  CI-Build
##  Desc:  Install toolset
################################################################################

Function Install-Asset {
    param(
        [Parameter(Mandatory = $true)]
        [object] $ReleaseAsset
    )

    Write-Host "Download $($ReleaseAsset.filename)"
    wget $ReleaseAsset.download_url -nv --retry-connrefused --tries=10

    Write-Host "Extract $($ReleaseAsset.filename) content..."
    $assetFolderPath = Join-Path './var/lib/waagent/custom-script/download/1/' $($ReleaseAsset.filename)
    try{
    New-Item -ItemType Directory -Path $assetFolderPath
    tar -xzf $ReleaseAsset.filename -C $assetFolderPath
    }
    catch{
    if($_.Exception -like '*item exists*') {
    Write-Host "Item exists already. Moving on" }
    }
    Write-Host "Invoke installation script..."
    Push-Location -Path $assetFolderPath
    Invoke-Expression "bash ./setup.sh"
    Pop-Location
}

$ErrorActionPreference = "Stop"

# Get toolset content
$toolset = Get-Content -Path "./toolset-2004.json" -Raw

$tools = ConvertFrom-Json -InputObject $toolset | Select-Object -ExpandProperty toolcache | Where-Object {$_.url -ne $null }

foreach ($tool in $tools) {
    # Get versions manifest for current tool
    $assets = Invoke-RestMethod $tool.url

    # Get github release asset for each version
    foreach ($toolVersion in $tool.versions) {
        $asset = $assets | Where-Object version -like $toolVersion `
        | Select-Object -ExpandProperty files `
        | Where-Object { ($_.platform -eq $tool.platform) -and ($_.platform_version -eq $tool.platform_version)} `
        | Select-Object -First 1

        Write-Host "Installing $($tool.name) $toolVersion $($tool.arch)..."
        if ($null -ne $asset) {
            Install-Asset -ReleaseAsset $asset
        } else {
            Write-Host "Asset was not found in versions manifest"
            exit 1
        }
    }
    chown -R "$($env:SUDO_USER):$($env:SUDO_USER)" "/opt/hostedtoolcache/$($tool.name)"
}
