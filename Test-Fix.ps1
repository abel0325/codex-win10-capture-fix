# SPDX-License-Identifier: MIT
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OriginalPath)
$ErrorActionPreference='Stop'
$fix=Join-Path $PSScriptRoot 'Fix-Capture.ps1'
$spec=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'profile.json') | ConvertFrom-Json
function Assert($value,[string]$message){if(-not $value){throw $message}}
Assert ((Get-FileHash -LiteralPath $OriginalPath -Algorithm SHA256).Hash -eq $spec.original_sha256) 'Wrong original fixture.'
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
$root=Join-Path $tempBase ('capture-fix-test-'+[guid]::NewGuid().ToString('N'))
$helper=Join-Path $root 'sky\bin\windows\codex-computer-use.exe'
$cache=Join-Path $root 'cache'
$backupHome=Join-Path $root 'backups'
try{
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $helper) | Out-Null
    Copy-Item -LiteralPath $OriginalPath -Destination $helper
    [IO.File]::WriteAllText((Join-Path $root 'sky\package.json'),'{"version":"0.7.13"}')
    $common=@{HelperPath=$helper;CacheDirectory=$cache;BackupHome=$backupHome}
    $s=& $fix @common
    Assert ($s.State -eq 'original-patchable') 'Original status failed.'
    Assert (-not(Test-Path -LiteralPath $cache)) 'Check must not create a dependency cache.'
    $candidate=Join-Path $root 'candidate.exe'
    & $fix @common -Action Build -OutputPath $candidate
    Assert ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -eq $spec.patched_sha256) 'Build output mismatch.'
    Assert ((Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash -eq $spec.original_sha256) 'Build changed original.'
    $os=[int](Get-CimInstance Win32_OperatingSystem).BuildNumber
    if($os -ge 22000){
        $rejected=$false
        try{& $fix @common -Action Install}catch{$rejected=$_.Exception.Message -like '*limited to Windows 10*'}
        Assert $rejected 'Windows 11 installation guard failed.'
        Write-Output 'Windows 11: candidate checks passed, installation correctly refused.'
    }else{
        & $fix @common -Action Install
        Assert ((& $fix @common).State -eq 'patched') 'Install failed.'
        & $fix @common -Action Install
        $backups=@(Get-ChildItem -LiteralPath $backupHome -Recurse -Filter '*.original')
        Assert ($backups.Count -eq 1) 'Backup count mismatch.'
        Assert ((Get-FileHash -LiteralPath $backups[0].FullName -Algorithm SHA256).Hash -eq $spec.original_sha256) 'Backup integrity failed.'
        & $fix @common -Action Rollback
        & $fix @common -Action Rollback
        Assert ((& $fix @common).State -eq 'original-patchable') 'Rollback failed.'
    }
    $bytes=[IO.File]::ReadAllBytes($helper)
    $bytes[$bytes.Length-1]=$bytes[$bytes.Length-1] -bxor 1
    [IO.File]::WriteAllBytes($helper,$bytes)
    $unknown=(Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash
    Assert ((& $fix @common).State -eq 'unsupported') 'Unknown input not detected.'
    $rejected=$false
    try{& $fix @common -Action Install}catch{$rejected=$_.Exception.Message -like 'Unsupported complete helper SHA256*'}
    Assert $rejected 'Unknown input was not refused.'
    Assert ((Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash -eq $unknown) 'Rejected input was modified.'
    Write-Output 'ALL_TESTS_PASSED (isolated files only; no screenshot or live deployment test)'
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)){
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
