# SPDX-License-Identifier: MIT
# Standalone adapter: third-party patch code is fetched from its original source,
# pinned and verified, not redistributed by this project.
[CmdletBinding()]
param(
    [ValidateSet('Check','Install','Rollback','Build')]
    [string]$Action = 'Check',
    [string]$HelperPath,
    [string]$OriginalPath,
    [string]$BackupHome = (Join-Path $env:USERPROFILE '.codex'),
    [string]$CacheDirectory = (Join-Path $env:LOCALAPPDATA 'CodexWin10CaptureFix'),
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$spec = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'profile.json') | ConvertFrom-Json
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Save-Utf8([string]$Path,[string]$Value) {
    [IO.File]::WriteAllText($Path,$Value,[Text.UTF8Encoding]::new($false))
}
if (-not $HelperPath) {
    $runtime = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\runtimes\cua_node'
    $found = @(Get-ChildItem -LiteralPath $runtime -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Join-Path $_.FullName 'bin\node_modules\@oai\sky\bin\windows\codex-computer-use.exe'
        if (Test-Path -LiteralPath $p -PathType Leaf) { $p }
    })
    if ($found.Count -ne 1) { throw 'Specify -HelperPath: runtime selection is missing or ambiguous.' }
    $HelperPath = $found[0]
}
$HelperPath = [IO.Path]::GetFullPath($HelperPath)
if (-not (Test-Path -LiteralPath $HelperPath -PathType Leaf)) { throw 'Helper file does not exist.' }
$current = Hash $HelperPath
$state = if ($current -eq $spec.original_sha256) { 'original-patchable' }
         elseif ($current -eq $spec.patched_sha256) { 'patched' } else { 'unsupported' }
if ($Action -eq 'Check') {
    [pscustomobject]@{ State=$state; Profile=$spec.id; HelperPath=$HelperPath; Sha256=$current }
    return
}
if ($state -eq 'unsupported') { throw 'Unsupported complete helper SHA256; file left untouched.' }
if ($HelperPath -match '(?i)[\\/]WindowsApps[\\/]') { throw 'Do not modify the installed WindowsApps package.' }
if ($Action -eq 'Install' -and $state -eq 'patched') { Write-Output 'Already patched.'; return }
if ($Action -eq 'Rollback' -and $state -eq 'original-patchable') { Write-Output 'Already original.'; return }
if ($Action -eq 'Build' -and -not $OutputPath) { throw '-Build requires -OutputPath.' }
if (-not $OriginalPath -and $state -eq 'original-patchable') { $OriginalPath=$HelperPath }
if (-not $OriginalPath) {
    $backupDir=Join-Path $BackupHome 'backups\computer-use-helper'
    $candidates=@(Get-ChildItem -LiteralPath $backupDir -Recurse -File -Filter 'codex-computer-use.exe.original' -ErrorAction SilentlyContinue |
        Where-Object { (Hash $_.FullName) -eq $spec.original_sha256 })
    if ($candidates.Count -lt 1) { throw 'Exact original backup required. Supply -OriginalPath; do not download an EXE from strangers.' }
    $OriginalPath=$candidates[0].FullName
}
if ((Hash $OriginalPath) -ne $spec.original_sha256) { throw 'Original backup SHA256 mismatch.' }
if ($Action -eq 'Build') {
    $OutputPath=[IO.Path]::GetFullPath($OutputPath)
    if (Test-Path -LiteralPath $OutputPath) { throw 'Build output must be a new file.' }
}
# The source is immutable and the content hash is independently pinned.
New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
$source=Join-Path $CacheDirectory ($spec.upstream.commit+'.ps1')
if (-not (Test-Path -LiteralPath $source)) {
    $download=$source+'.'+[guid]::NewGuid().ToString('N')+'.download'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $spec.upstream.url -OutFile $download
        if ((Hash $download) -ne $spec.upstream.sha256) { throw 'Upstream download integrity check failed.' }
        Move-Item -LiteralPath $download -Destination $source
    } finally { if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download } }
}
if ((Hash $source) -ne $spec.upstream.sha256) { throw 'Cached upstream source was changed; refusing execution.' }
$text=[IO.File]::ReadAllText($source).Replace("`r`n","`n")
$anchor="  [ordered]@{`n    Name = '@oai/sky 0.7.12 helper 6FCC7C64"
$begin=$text.IndexOf($anchor,[StringComparison]::Ordinal)
$end=$text.IndexOf("`n)`n`nfunction Write-Log",$begin,[StringComparison]::Ordinal)
if ($begin -lt 0 -or $end -lt $begin) { throw 'Pinned source layout is not recognized.' }
$profile=$text.Substring($begin,$end-$begin)
$profile=$profile.Replace('0.7.12 helper 6FCC7C64','0.7.13 helper 49C7F43D').Replace("SkyVersion = '0.7.12'","SkyVersion = '0.7.13'")
$profile=$profile.Replace($spec.reference.original_sha256,$spec.original_sha256).Replace($spec.reference.patched_sha256,$spec.patched_sha256)
$originalBytes=[IO.File]::ReadAllBytes($OriginalPath)
foreach ($region in $spec.rebound_original_regions) {
    $bytes=New-Object byte[] $region.length
    [Array]::Copy($originalBytes,[int]$region.offset,$bytes,0,[int]$region.length)
    $hex=([BitConverter]::ToString($bytes)-replace '-','').ToLowerInvariant()
    $pattern="(?<prefix>Name = '"+[regex]::Escape($region.name)+"'\s+Offset = 0x[0-9a-fA-F]+\s+OriginalHex = ')[^']+(?<suffix>')"
    if ([regex]::Matches($profile,$pattern).Count -ne 1) { throw 'Original-region binding is ambiguous.' }
    $profile=[regex]::Replace($profile,$pattern,('${prefix}'+$hex+'${suffix}'))
}
$adapted=$text.Substring(0,$end)+",`n"+$profile+$text.Substring($end)
$adapter=Join-Path $CacheDirectory ('adapter-'+[guid]::NewGuid().ToString('N')+'.ps1')
try {
    Save-Utf8 $adapter $adapted
    if ($Action -eq 'Build') {
        # Candidate is reconstructed from declared regions, then independently
        # checked against the complete output hash by the upstream routine.
        $fixture=Join-Path $CacheDirectory ('fixture-'+[guid]::NewGuid().ToString('N'))
        $fixtureSky=Join-Path $fixture 'sky'
        $fixtureExe=Join-Path $fixtureSky 'bin\windows\codex-computer-use.exe'
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fixtureExe) | Out-Null
            Copy-Item -LiteralPath $OriginalPath -Destination $fixtureExe
            Save-Utf8 (Join-Path $fixtureSky 'package.json') '{"version":"0.7.13"}'
            $candidateHash=& $adapter -HelperPath $fixtureExe -ComputeCandidateHash
            if ($candidateHash -ne $spec.patched_sha256) { throw 'Candidate hash validation failed.' }
            # Evaluate only the immutable declaration prefix, not executable
            # install logic. Its only contents are the pinned profile table.
            $declaration=$adapted.Substring($adapted.IndexOf('$PatchProfiles = @('))
            $declaration=$declaration.Substring(0,$declaration.IndexOf('function Write-Log'))
            $candidateProfiles=& ([scriptblock]::Create($declaration+'; $PatchProfiles'))
            $selected=@($candidateProfiles | Where-Object {$_.OriginalSha256 -eq $spec.original_sha256})
            if ($selected.Count -ne 1) { throw 'Ambiguous generated profile.' }
            $candidate=[byte[]]$originalBytes.Clone()
            foreach($r in $selected[0].Regions) {
                $new=New-Object byte[] ($r.PatchedHex.Length/2)
                for($i=0;$i -lt $new.Length;$i++){$new[$i]=[Convert]::ToByte($r.PatchedHex.Substring($i*2,2),16)}
                [Array]::Copy($new,0,$candidate,$r.Offset,$new.Length)
            }
            $sha=[Security.Cryptography.SHA256]::Create()
            try {$h=([BitConverter]::ToString($sha.ComputeHash($candidate))-replace '-','')} finally {$sha.Dispose()}
            if($h -ne $spec.patched_sha256){throw 'Reconstructed candidate mismatch.'}
            [IO.File]::WriteAllBytes($OutputPath,$candidate)
            Write-Output "Candidate SHA256: $h"
        } finally {
            $resolved=[IO.Path]::GetFullPath($fixture)
            $parent=[IO.Path]::GetFullPath($CacheDirectory).TrimEnd('\')+'\'
            if($resolved.StartsWith($parent,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        }
    } else {
        $invoke=@{HelperPath=$HelperPath; CodexHome=$BackupHome}
        if($Action -eq 'Install'){$invoke.Install=$true}else{$invoke.Rollback=$true}
        & $adapter @invoke
        $expected=if($Action -eq 'Install'){$spec.patched_sha256}else{$spec.original_sha256}
        if((Hash $HelperPath) -ne $expected){throw 'Final installed hash mismatch. Inspect the preserved backup.'}
    }
} finally { if(Test-Path -LiteralPath $adapter){Remove-Item -LiteralPath $adapter} }
