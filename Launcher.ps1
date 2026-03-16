<#
.SYNOPSIS
    Launshell - A Minecraft Launcher made in the wrong language.

.DESCRIPTION
    Windows only minecraft launcher, supports PowerShell 5.1 or higher.
#>

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Warning "PowerShell 5.1 or higher is required."
    Start-Sleep 3
    exit 2
}

#get script root
if (-not [string]::IsNullOrEmpty($PSScriptRoot)) { $root = $PSScriptRoot}
#elseif ($MyInvocation.MyCommand.Path) {$root = Split-Path -Path $MyInvocation.MyCommand.Path -Parent}
else {$root = Get-Location}


Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -Name Window -Namespace Console -MemberDefinition '[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'

Remove-TypeData -ErrorAction Ignore System.Array

if ($psISE -or ($env:TERM_PROGRAM -eq "vscode")) {
    Write-Host "Is in ISE or VS Code."
    function ShowConsole {}
} else {
    $conwin = [Console.Window]::GetConsoleWindow()
    function ShowConsole {
        param([bool]$shown)
        [void][Console.Window]::ShowWindow($conwin, $shown)
    }
}
#$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Console things
function info {
    param($text)
    Write-Host ("[LS] "+(Get-Date -Format "[HH:mm:ss]: ")+$text)
}
function warn {
    param($text)
    Write-Host ("[LS/WRN] "+(Get-Date -Format "[HH:mm:ss]: ")+$text) -ForegroundColor Yellow -BackgroundColor Black
}
function error {
    param($text)
    Write-Host ("[LS/ERR] "+(Get-Date -Format "[HH:mm:ss]: ")+$text) -ForegroundColor Red -BackgroundColor Black
}

#Making powershell more like C#
function JoinPath {
    param (
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$paths
    )
    return [System.IO.Path]::Combine($paths)
}

# More defs =3
$lTemp = JoinPath $env:TEMP "launshell"

#IDK
function DownloadFile {
    param([string]$Uri, [string]$OutFile)
    try {
        return Invoke-WebRequest -Uri $Uri -OutFile $OutFile -TimeoutSec 10
    } catch {
        error "Could not download file: $_"
    }
}

$launchver = "0.5.0"

Write-Host "Launshell $launchver
"

### Launcher

function Get-GameDir {
    param([string]$path="")
    if ($path -eq "") {
        $mchome = JoinPath $env:AppData ".minecraft"
        if (-not [System.IO.Directory]::Exists($mchome)) {[void](New-Item $mchome -Type Directory)}
        return $mchome
    }
    if (-not [System.IO.Directory]::Exists($path)) {[void](New-Item $path -Type Directory)}
    return $path
}

function WriteJson {
    param([string]$name, [string]$obj, $val)
    $var=Get-Variable($name)-ValueOnly
    try {$var.$obj=$val} catch {$var | Add-Member NoteProperty $obj $val}
}

function New-GuidFromString {
    param([string]$inputString)
    $hash = [Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($inputString))
    $guid = [guid]::new($hash).ToString("N")
    return $guid
}

function MergeJson {
    param($from, $into)
    $result = $into | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    foreach ($key in $from.PSObject.Properties.Name) {
        $value = $from.$key
        if ($result.PSObject.Properties.Name -contains $key) {
            if ($result.$key -is [array]) {
                $result.$key += $from.$key
            } elseif ($result.$key -is [PSCustomObject]) {
                $result.$key = MergeJson $from.$key $result.$key
            } else {
                $result.$key = $value
            }
        } else {
            $result | Add-Member -MemberType NoteProperty -Name $key -Value $value
        }
    }
    return $result
}

$arch = if ([Environment]::Is64BitOperatingSystem) { "64" } else { "86" }
$maxram = ([Microsoft.VisualBasic.Devices.ComputerInfo]::new().TotalPhysicalMemory / 1MB)
$OsVersion = [System.Environment]::OSVersion.Version.Major.ToString()

$optimized = @(
    [PSCustomObject]@{
        id="g1gc"
        name="G1 GC"
        args="-XX:+UseG1GC -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:+UseStringDeduplication -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15"
    }
    [PSCustomObject]@{
        id="cms"
        name="CMS"
        args="-XX:+UseConcMarkSweepGC -XX:-UseAdaptiveSizePolicy -XX:+CMSParallelRemarkEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseCMSInitiatingOccupancyOnly"
    }
    [PSCustomObject]@{
        id="shegc"
        name="Shenandoah GC"
        args="-XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:+UseStringDeduplication -XX:+OptimizeStringConcat"
    }
    [PSCustomObject]@{
        id="zgc"
        name="ZGC"
        args="-XX:+UseZGC -XX:ZCollectionInterval=5 -XX:ZAllocationSpikeTolerance=2.0 -XX:+UseStringDeduplication -XX:+OptimizeStringConcat"
    }
)

$common = "-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:MaxGCPauseMillis=200 -XX:+AlwaysPreTouch -XX:+ParallelRefProcEnabled -Dfml.ignoreInvalidMinecraftCertificates=true -Dfml.ignorePatchDiscrepancies=true -Djava.net.useSystemProxies=true -Dfile.encoding=UTF-8"

# function ConvertProfiles {
#     param([string]$path)
#     if (-not (Test-Path $path)) {return}
#     $vprofiles1 = Get-Content $path -Raw | ConvertFrom-Json
#     $vprofiles = [System.Collections.ArrayList]@() 
#     foreach ($value in $vprofiles1.profiles) {
#         $nprof = [PSCustomObject]@{
#             uuid = [guid]::NewGuid().ToString("N")
#             name = ""
#             json = $value.lastVersionId
#             gamedir = ""
#             memory = 0
#             args = ""
#             mineargs = ""
#             opti = 1
#         }

#         if ([string]::IsNullOrEmpty($value.name)) {
#             $nprof.name = $value.lastVersionId+" converted"
#         } else {
#             $nprof.name = $value.name+" converted"
#         }

#         $vprofile.Add($nprof)
#     }
#     return $vprofiles
# }

$u_adj = @("Swift", "Lazy", "Brave", "Silent", "Happy", "Clever", "Dark", "Fuzzy", "Witty", "Mighty", "Muddy", "Mystic", "Shadow", "Oak", "Holy", "Open", "Neat")
$u_nou = @("Fox", "Tiger", "Eagle", "Panda", "Wolf", "Dragon", "Otter", "Bear", "Hawk", "Shark", "Cat", "Llama", "Hamster", "Rabbit", "Owl", "Lion", "Fiber", "Sage", "Clover", "Relic")
function CreateUsername {
    $a = Get-Random $u_adj
    $b = Get-Random $u_nou
    $nums = 15 - "$a$b".Length
    $max = [int][math]::Pow(10, $nums) - 1
    $min = [int][math]::Pow(10, $nums - 1)
    $c = Get-Random -Minimum $min -Maximum ($max + 1)
    return "$a$b$c"
}

function RuleCheck {
    param($rule)
    $out = $rule.action -eq "allow"
    if ($null -ne $rule.os) {
        if (($null -ne $rule.os.name) -and ($rule.os.name -ne "windows")) {
            return -not $out
        }
        if (($null -ne $rule.os.version) -and (-not ($OsVersion -match $rule.os.version))) {
            return -not $out
        }
        if (($null -ne $rule.os.arch) -and ($rule.os.arch.ToLower() -ne $arch)) {
            return -not $out
        }
    }
    return $out
}


$notDownloadedMF = $true
function GetVersionManifest {
    $mfpath = JoinPath $root "version_manifest.json"
    if (-not [System.IO.File]::Exists($mfpath) -or $notDownloadedMF) {
        info "[mf/ALLVER] Getting version manifest"
        DownloadFile "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json" $mfpath
        $global:notDownloadedMF = $false
    }
    $mf = Get-Content $mfpath -Raw | ConvertFrom-Json
    return $mf
}
function GetOnlineVersionList {
    $mf = GetVersionManifest
    return $mf.versions
}

function GetOfflineVersionList {
    $folders = Get-ChildItem -Path "$mchome/versions" -Directory
    $versions = [System.Collections.Generic.List[object]]::new()
    foreach ($folder in $folders) {
        if (Test-Path "$($folder.FullName)/$($folder.Name).json") {
            $ver = Get-Content "$($folder.FullName)/$($folder.Name).json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($null -ne $ver) {
                $versions.Add($ver)
            }
        }
    }
    return $versions
}


$launching = $false
$isconnected = Test-Connection 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue
function GetClassFiles {
    param($manifest, [bool]$rewrite, [bool]$hashes, $call)

    $verFolder = JoinPath $mchome "versions" $manifest.id
    $verNative = JoinPath $verFolder "natives"
    $verFile = JoinPath $verFolder ($manifest.id+".jar")
    $inf = JoinPath $verNative "META-INF"

    $donatives = $false
    if (-not [System.IO.Directory]::Exists($verNative)) {$donatives = $true; [void](New-Item $verNative -Type Directory -Force)}
    
    #Client
    if (-not [System.IO.File]::Exists($verFile) -or $rewrite -or ($hashes -and $manifest.downloads.client.sha1 -and ((Get-FileHash $verFile -Algorithm SHA1).Hash -ne $manifest.downloads.client.sha1))) {
        info "[libs/MC] Downloading $($manifest.id).jar"
        DownloadFile $manifest.downloads.client.url $verFile
    }

    <#if ($manifest.logging.client.file -ne $null) {
        $logFolder = [System.IO.Path]::Combine($mchome, "assets", "logging")
        if (-not (Test-Path $logFolder)) {[void](New-Item $logFolder -Type Directory -Force)}
        $logging = [System.IO.Path]::Combine($logFolder, $manifest.logging.client.file.id)
        if (-not (Test-Path $logging) -or $rewrite) {
            Invoke-WebRequest -Uri $manifest.logging.client.file.url -OutFile $logging
        }
    }#>

    $LibsDir = JoinPath $mchome "libraries"
    
    $cp = [System.Collections.ArrayList]@()
    # Libraries
    $count = $(@($manifest.libraries).Count)
    $index = 0
    info "Checking libraries..."
    foreach ($lib in $manifest.libraries) {
        if (-not $launching) {break}
        $index++
        if ($call -is [ScriptBlock]) {try{&$call $index $count}catch{}}
        if (($null -ne $lib.rules) -and -not ($lib.rules | Where-Object {RuleCheck $_})) {continue}

        $split = [System.Collections.ArrayList]($lib.name.Split(":"))
        $split2 = $split[0].Split(".")
        $split.Remove($split[0])
        $split = $split2 + $split

        if ($null -ne $lib.downloads.artifact) {
            if ($null -ne $lib.downloads.artifact.path) {
                $libpath = $lib.downloads.artifact.path
            } else {
                $libpath = [string]::Join("/", $split)
            }
            $dest = JoinPath $LibsDir $libpath
            $destPath = Split-Path $dest -Parent

            if (-not [System.IO.File]::Exists($dest) -or $rewrite -or ($hashes -and $lib.downloads.artifact.sha1 -and ((Get-FileHash $dest -Algorithm SHA1).Hash -ne $lib.downloads.artifact.sha1)) ) {
                [void](New-Item $destPath -Type Directory -Force)
                info "[libs] Downloading $libpath..."
                DownloadFile $lib.downloads.artifact.url $dest
            }
            if (-not $cp.Contains($dest)) {
                [void]$cp.Add($dest)
            }
        }
        if (($null -ne $lib.downloads.classifiers) -and ($null -ne $lib.natives.windows)) {
            $ckey = $lib.natives.windows.Replace('${arch}', $arch)
            $libcl = $lib.downloads.classifiers.$ckey
            if ($null -eq $libcl) {continue}
            if ($null -ne $libcl.path) {
                $libpath = $libcl.path
            } else {
                $libpath = [string]::Join("/", $split)
            }
            $dest = JoinPath $LibsDir ($libpath+".zip")
            $destPath = Split-Path $dest -Parent
            if (-not [System.IO.File]::Exists($dest) -or $rewrite -or $donatives) {
                [void](New-Item $destPath -Type Directory -Force)
                info "[libs] Downloading $libpath..."
                DownloadFile $libcl.url $dest
                if ($null -ne $lib.extract) {
                    Expand-Archive $dest $verNative -Force
                }
            }
            if (-not ($null -ne $lib.extract) -and -not $cp.Contains($dest)) {
                [void]$cp.Add($dest)
            }
        }
        if ($null -eq $lib.downloads) {
            $pathName = [string]::Join("/", $split)
            $libName = "$($split[-2])-$($split[-1]).jar"

            $destPath = JoinPath $LibsDir $pathName
            $libPath = JoinPath $destPath $libName

            if (($null -ne $lib.url) -and ($lib.url -match "https?:\/\/.+")) {
                if (-not [System.IO.File]::Exists($libPath) -or $rewrite -or ($hashes -and $lib.sha1 -and ((Get-FileHash $libPath -Algorithm SHA1).Hash -ne $lib.sha1))) {
                    [void](New-Item $destPath -Type Directory -Force)
                    info "[libs] Downloading $pathName/$libName..."
                    if ($lib.url -match "https?:\/\/.+\/.+") {
                        DownloadFile $lib.url $libPath
                    } else {
                        $ur = $lib.url
                        if ($ur[-1] -ne "/") {$ur += "/"}
                        $ur += JoinPath $pathName $libName
                        DownloadFile $ur $libPath
                    }
                }
            } elseif (-not [System.IO.File]::Exists($libPath)) {continue}
            if (-not $cp.Contains($libPath)) {
                [void]$cp.Add($libPath)
            }
        }
    }
    [void]$cp.Add($verFile)
    if ([System.IO.Directory]::Exists($inf)) {[System.IO.Directory]::Delete($inf, $true)}
    foreach ($item in (Get-ChildItem $verNative -File)) {
        if ($item.Extension -ne ".dll") {
            Remove-Item $item.FullName -Force
        }
    }
    $str = $cp -join ";"
    return $str.Replace("\", "/")
}

function CheckManifest {
    param([string]$version, [bool]$rewrite)
    $manifestLoc = JoinPath $mchome "versions" $version "$version.json"
    if (-not [System.IO.File]::Exists($manifestLoc) -or $rewrite) {
        $verlist = GetOnlineVersionList
        if ($null -ne $verlist) {
            $verinlist = $verlist.Where({ $_.id -eq $version }, "First")
            if ($null -ne $verinlist) {
                $versionDir = JoinPath $mchome "versions" $version
                [void](New-Item $versionDir -Type Directory -Force)
                info "[mf/VER] Downloading $version"
                DownloadFile $verinlist.url $manifestLoc
            }
        }
    }
    return $manifestLoc
}

function GetAssetDir {
    param($manifest, $gdir)
    $assetDir = JoinPath $mchome "assets"
    $resDir = JoinPath $gdir "resources"
    
    $virtDir = JoinPath $assetDir "virtual" $manifest.assetIndex.id
    $indexFile = JoinPath $assetDir "indexes" "$($manifest.assetIndex.id).json"
    if ([System.IO.File]::Exists($indexFile)) {
        $indexJson = Get-Content $indexFile -Raw | ConvertFrom-Json
        if ($indexJson.map_to_resources) {return $resDir} elseif ($indexJson.virtual) {return $virtDir}
        return $assetDir
    } else {
        return $assetDir
    }
}

function CheckAssets {
    param($manifest, $gdir, [bool]$rewrite, [bool]$hashes, $call)
    $assetIndex = $manifest.assetIndex
    if ($null -eq $assetIndex) {return}

    $assetDir = JoinPath $mchome "assets"
    $resDir = JoinPath $gdir "resources"
    $objectsDir = JoinPath $assetDir "objects"
    $indexesDir = JoinPath $assetDir "indexes"

    $indexFile = JoinPath $indexesDir "$($assetIndex.id).json"
    $virtDir = JoinPath $assetDir "virtual" $assetIndex.id
    if (-not [System.IO.Directory]::Exists($indexesDir)) {[void](New-Item $indexesDir -ItemType Directory -Force)}
    if (-not [System.IO.File]::Exists($indexFile) -or $rewrite) {
        info "[assets/INDEX] Downloading $($assetIndex.id) index"
        DownloadFile $assetIndex.url $indexFile
    }
    if (-not [System.IO.File]::Exists($indexFile)) {return}
    $indexJson = Get-Content $indexFile -Raw | ConvertFrom-Json
    $objects = $indexJson.objects

    
    $props = $objects.PSObject.Properties
    $count = $(@($props).Count)
    $index = 0
    info "Checking assets..."
    foreach ($key in $props.Name) {
        if (-not $launching) {break}
        $index++
        if ($call -is [ScriptBlock]) {try{&$call $index $count}catch{}}
        $hash = $objects.$key.hash
        $subDir = $hash.Substring(0, 2)
        if ($indexJson.map_to_resources) {
            $assetFile = JoinPath $resDir $key
            $assetPath = Split-Path $assetFile -Parent
        } elseif ($indexJson.virtual) {
            $assetFile = JoinPath $virtDir $key
            $assetPath = Split-Path $assetFile -Parent
        } else {
            $assetPath = JoinPath $objectsDir $subDir
            $assetFile = JoinPath $assetPath $hash
        }
        if (-not [System.IO.Directory]::Exists($assetPath)) {[void](New-Item $assetPath -ItemType Directory -Force)}
        if (-not [System.IO.File]::Exists($assetFile) -or $rewrite -or ($hashes -and ((Get-FileHash $assetFile -Algorithm SHA1).Hash -ne $hash)) ) {
            info "[assets] Downloading $key"
            DownloadFile "https://resources.download.minecraft.net/$subDir/$hash" $assetFile
        }
    }
}

function GetJavasList {
    try {
        $mf = Invoke-RestMethod "https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json" -Method Get
    } catch {
        error "Could not get java manifest: $_"
    }
    return $mf.("windows-x"+$arch)
}

function DownloadJava {
    param([string]$javaVer, $rewrite, $call)

    $javalist = GetJavasList
    if ($null -ne $javalist.$javaVer) {
        return
    }

    try {
        $jf = Invoke-RestMethod $javalist.$javaver.manifest.url -Method Get
    } catch {
        warn "Could not get $javaVer manifest: $_"
        return
    }
    if ($null -ne $jf.files) {return}
    $javadir = JoinPath $root "java" $javaVer
    if (-not [System.IO.Directory]::Exists($javadir)) {[void](New-Item $javadir -ItemType Directory -Force)}
    $props = $jf.files.PSObject.Properties
    $count = $(@($props).Count)
    $index = 0
    info "Checking $javaVer files..."
    foreach ($file in $props) {
        if (-not $launching) {break}
        $index++
        if ($call -is [ScriptBlock]) {try{&$call $index $count}catch{}}
        $filePath = JoinPath $javadir $file.Name
        $fileDir = Split-Path $filePath -Parent
        if ($file.Value.type -eq "directory") {continue}
        if (-not [System.IO.Directory]::Exists($fileDir)) {[void](New-Item -ItemType Directory -Path $fileDir -Force)}
        if (-not [System.IO.File]::Exists($filePath) -or $rewrite) {
            info "[java] Downloading $($file.Name)..."
            DownloadFile $file.Value.downloads.raw.url $filePath
        }
    }
}

function GetJava {
    param($rejava, $rewrite, $call)
    if ($null -eq $rejava) {
        $rejava = "jre-legacy"
    }
    $path = JoinPath $root "java" $rejava "bin" "java.exe"
    if (-not [System.IO.File]::Exists($path) -or $rewrite) {
        DownloadJava $rejava $rewrite $call
    }
    return $path
}

function BuildArguments {
    param($manifest, $PSObj, $moreargs="")
    $str = ""

    if ($null -ne $manifest.arguments) {
        foreach ($item in $manifest.arguments.game) {
            if ($item -is [string]) {
                if ($item.Trim() -ne "") {
                    $str += " "+$item
                }
            }  elseif ($item -is [PSCustomObject]) {
                if ($null -ne $item.rules) {continue}
                if (($item.value -is [string]) -and ($item.value.Trim() -ne "")) {
                    $str += " "+[string]$item.value
                }
            }
        }
    } else {
        $str = $manifest.minecraftArguments
    }
    
    if ($moreargs.Trim() -ne '') {
        $str += ' '+$moreargs.Trim()
    }

    $each = @{
	    '${version_name}' = '"'+$manifest.id+'"'
	    '${assets_index_name}' = $manifest.assetIndex.id
	    '${auth_player_name}' = '"'+$PSObj.Username+'"'
	    '${game_directory}' = '"'+$PSObj.GameDir+'"'
	    '${assets_root}' = '"'+$PSObj.AssetDir+'"'
	    '${game_assets}' = '"'+$PSObj.AssetDir+'"'
	    '${auth_uuid}' = $PSObj.Uuid
	    '${auth_xuid}' = '""'
	    '${clientid}' = $PSObj.ClientID
	    '${auth_session}' = $PSObj.Token
	    '${auth_access_token}' = $PSObj.Token
	    '${user_type}' = $PSObj.UserType
	    '${version_type}' = $PSObj.VerType
	    '${user_properties}' = "{}"
    }
    foreach ($key in $each.Keys) {
        $str = $str.Replace($key, $each[$key])
    }

    if ($PSObj.Fullscreen) {$str += ' --fullscreen'}
    if ($PSObj.Width) {$str += ' --width '+$PSObj.Width}
    if ($PSObj.Height) {$str += ' --height '+$PSObj.Height}
    return $str
}

<#if ($manifest.logging.client.file -ne $null) {
    $logging = [System.IO.Path]::Combine($mchome, "assets", "logging", $manifest.logging.client.file.id)
    if (Test-Path $logging) {
        $str += ' '+$manifest.logging.client.argument.Replace('${path}', $logging)
    }
}#>

function BuildJvmArguments {
    param($manifest, $PSObj, $moreargs)
    $str = '-Xmx${xmx}M -Xms${xms}M -ea '+$common

    if ($PSObj.xmx -ge 2048) {
        $str += ' -Xss2M'
    }
    
    if ($null -ne $PSObj.optimized) {
        $str += ' '+$PSObj.optimized.args
    }
        
    foreach ($arg in $moreargs) {
        if (($arg -is [string]) -and ($arg.Trim() -ne "")) {
            $str += ' '+$arg
        }
    }
    
    if ($null -ne $manifest.arguments) {
        foreach ($item in $manifest.arguments.jvm) {
            if ($item -is [string]) {
                if ($item.Trim() -ne "") {
                    $str += ' "'+$item+'"'
                }
            } elseif ($item -is [PSCustomObject]) {
                if ($null -ne $item.rules) {
                    if ($item.rules -and -not ($item.rules | Where-Object {RuleCheck $_})) {continue}
                }
                if (($item.value -is [string]) -and ($item.value.Trim() -ne "")) {
                    $str += ' "'+[string]$item.value+'"'
                }
            }
        }
    } else {
        $str += ' -Djava.library.path="${natives_directory}" -cp "${classpath}"'
    }
    
    $LibsDir = JoinPath $mchome "libraries"

    $each = @{
        '${xmx}' = $PSObj.xmx
        '${xms}' = $PSObj.xms
        '${natives_directory}' = $PSObj.natives
        '${classpath}' = $PSObj.classes
        '${launcher_name}' = "java-minecraft-launcher"
        '${launcher_version}' = "0.3.1"
        '${version_name}' = $manifest.id
        '${library_directory}' = $LibsDir
        '${classpath_separator}' = ';'
    }
    foreach ($key in $each.Keys) {
        $str = $str.Replace($key, $each[$key])
    }

    return $str
}

function Get-AuthLib {
    param($point, [bool]$rewrite, [bool]$hashes)
    info "Checking for authlib updates..."
    $libdir = JoinPath $mchome "libraries" "javaagent"
    $libpath = JoinPath $libdir "authlib-injector.jar"

    try {
        $github = Invoke-RestMethod -Uri "https://api.github.com/repos/yushijinhun/authlib-injector/releases/latest" -Method Get
        if (($null -ne $github) -and ($null -ne $github.assets)) {
            foreach ($asset in $github.assets) {
                if (($asset.content_type -eq "application/java-archive")) {
                    if ((-not [System.IO.File]::Exists($libpath)) -or $rewrite -or ($hashes -and ((Get-FileHash $libpath -Algorithm SHA256).Hash -ne ($asset.digest -replace "^sha256:", "")))) {
                        [void](New-Item $libdir -Type Directory -Force)
                        info "[auth] Downloading authlib-injector.jar"
                        DownloadFile $asset.browser_download_url $libpath
                    }
                    break
                }
            }
        }
    } catch {
        warn "Error getting authlib: $_"
    }

    if ([System.IO.File]::Exists($libpath)) {
        return "`"-javaagent:$libpath=$point`""
    }
}

function CheckForUpdates {
    info "Checking for updates..."

    try {
        $github = Invoke-RestMethod -Uri "https://api.github.com/repos/Lomik8908/Launshell/releases/latest" -Method Get
        if (($null -ne $github) -and ($github.tag_name -is [string]) -and ($null -ne $github.assets) -and ([version]$github.tag_name -gt [version]$launchver)) {
            info "New version found!"
            if ([System.Windows.Forms.MessageBox]::Show(([string]$lang.newver -f $github.tag_name), [string]$lang.updchecker, "YesNo", "Question") -eq "Yes") {
                foreach ($asset in $github.assets) {
                    if ($asset.content_type -eq "application/x-msdownload") {
                        $path = JoinPath $env:TEMP $asset.name
                        info "[ls/UPD] Downloading $($asset.name)"
                        DownloadFile $asset.browser_download_url $path
                        Start-Process -FilePath $path
                        exit
                        break
                    }
                }
            } else {
                return $true;
            }
        }
    } catch {
        warn "Could not check for updates: $_"
    }
    return $false;
}

#Modloaders
##[ModificationLocationModloader]##

#Other
##[ModificationLocationOther]##

function GetLanguage {
    param([string]$langname)
    try {
        return Get-Content "$root/resources/lang/$langname.json" -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        return Get-Content "$root/resources/lang/en_us.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    }
}

try {
    if (-not [System.IO.File]::Exists("$root/settings.json")) {Set-Content "$root/settings.json" '{"res_x": 1280, "res_y": 720, "ram": 2048, "lang": "en_us", "checkupdates": true, "check_assets": true, "check_hash": true, "useauthlib": true, "optimized": 1, "version": "latest-release"}'; $global:first = $true}
    $settings = Get-Content "$root/settings.json" -Raw | ConvertFrom-Json
    if ($null -eq $settings.clientId) {
        WriteJson "settings" "clientId" ([guid]::NewGuid().ToString("N"))
    }
    $mchome = (Get-GameDir $settings.gamedir)
    $lang = GetLanguage $settings.lang
} catch {warn "Error loading jsons: $_"}
Set-Location $mchome

if (-not (Test-Path "$mchome/launshell_profiles.json")) {
    Set-Content "$mchome/launshell_profiles.json" '[{"uuid":  "latest-release", "name":  "Latest Release", "json":  "latest", "opti":  1},{"uuid":  "latest-snapshot", "name":  "Latest Snapshot", "json":  "latest-snapshot", "opti":  1}]'
}

if ($settings.checkupdates) {
    $gotupd = CheckForUpdates
    info "Update avaliable: $gotupd"
}

$edituser = $false
$editver = $false

# function TryLoadImg {
#     param($path)
#     try {return [System.Drawing.Image]::FromFile($path)} catch {return $null}
# }

try {
    ##[ModificationLocationBeforeStyles]##

    [System.Windows.Forms.Application]::EnableVisualStyles()

    ##[ModificationLocationBeforeUI]##

    . "$root/resources/LauncherUI.ps1"

    ##[ModificationLocationAfterUI]##
    
    #Moved here because it might be unsafe to keep in LauncherUI
    $main_ui.launch_box.Items.AddRange(@([string]$lang.hidelaunch, [string]$lang.closelaunch, [string]$lang.donone))
    [void]$other_ui.opti_box.Items.Add([string]$lang.none)
    $version_dialog.opti_box.Items.AddRange(@([string]$lang.none, [string]$lang.default))
    $user_ui.user_type.Items.AddRange(@([string]$lang.offline_type, "Ely.by"))
    $user_ui.user_type.SelectedIndex = 0

    ##[ModificationLocationPreLoad]##


    $main_ui.version_box.DisplayMember = 'dname'
    $version_ui.list_box.DisplayMember = 'dname'
    $main_ui.users_list.DisplayMember = 'name'
    $main_ui.lang_box.DisplayMember = 'name'
    $version_dialog.ver.DisplayMember = 'id'
    $other_ui.opti_box.DisplayMember = 'name'
    $version_dialog.opti_box.DisplayMember = 'name'

    $browsefolder = [System.Windows.Forms.FolderBrowserDialog]@{}
    $browsefolder.Description = [string]$lang.browsedescr
    
    [void]$other_ui.opti_box.Items.AddRange($optimized)
    [void]$version_dialog.opti_box.Items.AddRange($optimized)

    $userTyper = @{
        "plain" = 0
        "elyby" = 1
    }
    $infos = @{
        "plain" = [string]$lang.offline_type
        "elyby" = "Ely.by"
    }

    function UpdateUserInfo {
        $username = $main_ui.users_list.SelectedItem.name
        if ((-not [string]::IsNullOrEmpty($main_ui.users_list.SelectedItem.type)) -and $infos.ContainsKey($main_ui.users_list.SelectedItem.type)) {
            $usertype = $infos[$main_ui.users_list.SelectedItem.type]
        } elseif ($null -eq $main_ui.users_list.SelectedItem) {
            $usertype = [string]$lang.none
            $username = [string]$lang.none
        } else {
            $usertype = $infos["plain"]
        }
        $main_ui.user_info.Text = ([string]$lang.user_info -f $username, $usertype)
        $main_ui.changeuser_btn.Enabled = ($null -ne $main_ui.users_list.SelectedItem)
        $main_ui.user_box.Text = $main_ui.users_list.SelectedItem.name
    }

    function RefreshVersions {
        if ($main_ui.version_box.SelectedIndex -ne -1) {WriteJson "settings" "version" $main_ui.version_box.SelectedItem.uuid}
        $main_ui.version_box.Items.Clear()
        $vprofiles = Get-Content "$mchome/launshell_profiles.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        try {
            foreach ($version in $vprofiles) {
                if ($null -eq $version) {continue}
                if ($main_ui.showver_box.Checked) {
                    WriteJson "version" "dname" "$($version.name) ($($version.json))"
                } else {
                    WriteJson "version" "dname" $version.name
                }
                $idx = $main_ui.version_box.Items.Add($version)
                if ($version.uuid -eq $settings.version) {
                    $main_ui.version_box.SelectedIndex = $idx
                }
            }
        } catch {warn "Error loading versions: $_"}
    }
    function RefreshVersionsUI {
        $version_ui.list_box.SelectedIndex = -1
        $version_ui.list_box.Items.Clear()
        $vprofiles = Get-Content "$mchome/launshell_profiles.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        try {
            foreach ($version in $vprofiles) {
                if ($null -eq $version) {continue}
                WriteJson "version" "dname" "$($version.name) ($($version.json))"
                [void]$version_ui.list_box.Items.Add($version)
            }
        } catch {warn "Error loading versionsui: $_"}
    }
	
	function RefreshUsers {
        if ($main_ui.users_list.SelectedIndex -ne -1) {WriteJson "settings" "user" $main_ui.users_list.SelectedItem.uuid}
        $users = Get-Content "$mchome/launshell_users.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        $main_ui.users_list.Items.Clear()
		$main_ui.user_box.Text = ""
		foreach ($user in $users) {
            if ($null -eq $user) {continue}
			$idx = $main_ui.users_list.Items.Add($user)
			if ($user.uuid -eq $settings.user) {
				$main_ui.users_list.SelectedIndex = $idx
				UpdateUserInfo
			}
		}
	}

    
    function SaveUsers {ConvertTo-Json $main_ui.users_list.Items -Depth 20 | Set-Content "$mchome/launshell_users.json"}
    function SaveProfiles {ConvertTo-Json $main_ui.version_box.Items -Depth 20 | Set-Content "$mchome/launshell_profiles.json"}


    function EndLaunch {
        $global:launching = $false
        $main_ui.play_btn.Enabled = $true
        $main_ui.play_btn.Text = [string]$lang.play
        $main_ui.statustext.Text = ""
    }
    function GameLaunch {
        try {
        if ($launching) {
            $main_ui.play_btn.Enabled = $false
            $global:launching = $false
            $main_ui.play_btn.Text = [string]$lang.canceling
            [System.Windows.Forms.Application]::DoEvents()
            return
        }
        $user = $main_ui.users_list.SelectedItem
        $vprofile = $main_ui.version_box.SelectedItem
        
		if ([string]::IsNullOrEmpty($user.name)) {$main_ui.statustext.Text = [string]$lang.selectacc;return}
		if ($main_ui.version_box.SelectedIndex -eq -1) {$main_ui.statustext.Text = [string]$lang.selectver;return}

        $main_ui.play_btn.Text = [string]$lang.cancel
        $global:isconnected = Test-Connection 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue
        $global:launching = $true

        if (($user.name.Length -lt 3) -or ($user.name.Length -gt 16) -or (-not ($user.name -match "^[A-Za-z0-9_]+$"))) {
            warn "Username too long or contains special characters"
        }

        if (-not $launching) {return EndLaunch}

        #Fallback
        if ([string]::IsNullOrEmpty($user.uuid)) {$usid = (New-GuidFromString $user.name)} else {$usid = $user.uuid}
        if ([string]::IsNullOrEmpty($user.token)) {$ustk = "0"} else {$ustk = $user.token}

        # Validate token, if invalid renew
        if ($main_ui.authlib_box.Checked -and $isconnected) {
            if ($user.type -eq "elyby") {
                $body = @{ accessToken = $ustk; clientToken = $settings.clientId } | ConvertTo-Json -Depth 10
                info "Checking token..."
                try {
                    [void](Invoke-WebRequest -Uri "https://authserver.ely.by/auth/validate" -Method Post -ContentType "application/json" -Body $body)
                    info "Token valid"
                } catch {
                    if ($_.Exception.Response.StatusCode -eq 401) {
                        info "Renewing token..."
                        try {
                            $newTK = Invoke-RestMethod -Uri "https://authserver.ely.by/auth/refresh" -Method Post -ContentType "application/json" -Body $body
                            info "Token renewed successfully"
                            $ustk = $newTK.accessToken
                            $user.token = $newTK.accessToken
                            SaveUsers
                        } catch {
                            warn "Token invalid or error: $_\n    Most likely your client id was reset, in that case please readd your account."
                        }
                    } else {
                        warn "Token error: $_"
                    }
                    # if ([System.Windows.Forms.MessageBox]::Show([string]$lang.ely_invalid, "Ely.by", "YesNo", "Warning") -eq "No") {
                    #     return EndLaunch
                    # }
                }
            }
        }

        $json = $vprofile.json

        
        if ([string]::IsNullOrEmpty($vprofile.gamedir)) {$gdir = (Resolve-Path $mchome).Path}
        else {$gdir = (Resolve-Path $vprofile.gamedir).Path}

        if ($vprofile.memory -le 0) {$mem = $main_ui.mem_box.Value}
        else {$mem = $vprofile.memory}

        $main_ui.statustext.Text = [string]$lang.checkmanifest
        [System.Windows.Forms.Application]::DoEvents()

        if ($vprofile.json -eq "latest") {
            $json = (GetVersionManifest).latest.release
        } elseif ($vprofile.json -eq "latest-snapshot") {
            $json = (GetVersionManifest).latest.snapshot
        }

        $newdown = -not [System.IO.File]::Exists("$mchome/versions/$json/$json.jar")
        $manifestPath = CheckManifest $json $main_ui.redownlib_box.Checked
        

        if (-not [System.IO.File]::Exists($manifestPath)) {warn "Could not find the manifest."; return EndLaunch}
        
        #InheritsFrom
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if (-not [string]::IsNullOrEmpty($manifest.inheritsFrom)) {
            $inheritedPath = CheckManifest $manifest.inheritsFrom $main_ui.redownlib_box.Checked
            if (-not [System.IO.File]::Exists($inheritedPath)) {
                warn "Inherited manifest path not found."
                return EndLaunch
            } else {
                $inherited = Get-Content $inheritedPath -Raw | ConvertFrom-Json
                $merged = MergeJson $manifest $inherited
                $merged.PSObject.Properties.Remove("inheritsFrom")

                $merged | ConvertTo-Json -Depth 50 -Compress | Set-Content $manifestPath
                $manifest = $merged
            }
        }
        
        $main_ui.statustext.Text = [string]$lang.checkfiles
        [System.Windows.Forms.Application]::DoEvents()

        $jva = @($vprofile.args, $other_ui.jvarg_box.Text)

        $classes = GetClassFiles $manifest $main_ui.redownlib_box.Checked $main_ui.checkhash_box.Checked {
            param($i,$c)
            $main_ui.statustext.Text = [string]$lang.checkfiles+" ($i/$c)"
            [System.Windows.Forms.Application]::DoEvents()
        }
        if ($main_ui.authlib_box.Checked -and $isconnected) {
            if ($user.type -eq "elyby") {
                $libarg = Get-AuthLib "ely.by" $main_ui.redownlib_box.Checked $main_ui.checkhash_box.Checked
                if (-not [string]::IsNullOrEmpty($libarg)) {
                    $jva += $libarg
                }
            }
        }
        $main_ui.redownlib_box.Checked = $false
        if (-not $launching) {return EndLaunch}
        
        if ($main_ui.checkass_box.Checked -or $main_ui.redownass_box.Checked -or $newdown) {
            $main_ui.statustext.Text = [string]$lang.checkassets
            [System.Windows.Forms.Application]::DoEvents()
            CheckAssets $manifest $gdir $main_ui.redownass_box.Checked $main_ui.checkhash_box.Checked {
                param($i,$c)
                $main_ui.statustext.Text = [string]$lang.checkassets+" ($i/$c)"
                [System.Windows.Forms.Application]::DoEvents()
            }
            $main_ui.redownass_box.Checked = $false
        }
        if (-not $launching) {return EndLaunch}
        $adir = GetAssetDir $manifest $gdir
        
        $mcargc = [PSCustomObject]@{
            Username=$user.name
            GameDir=$gdir
            AssetDir=$adir
            Uuid=$usid
            Token=$ustk
            ClientID=$settings.clientId
            UserType="msa"
            VerType=$manifest.type
            Fullscreen=$main_ui.fullscreen_box.Checked
            Width=$main_ui.resx_box.Value
            Height=$main_ui.resy_box.Value
        }
        
        $jvargc = [PSCustomObject]@{
            xmx=$mem
            xms=[math]::Min($mem, 2048)
            natives=(JoinPath $mchome "versions" $json "natives").Replace("\", "/")
            classes=$classes
        }

        if (($vprofile.opti -eq 1) -and ($other_ui.opti_box.SelectedIndex -ne 0)) {
            $jva += $optimized[$other_ui.opti_box.SelectedIndex-1].args
        } elseif ($vprofile.opti -ne 0) {
            $jva += $optimized[$vprofile.opti-2].args
        }
        
        $jvarg = BuildJvmArguments $manifest $jvargc $jva
        $mcarg = BuildArguments $manifest $mcargc "$($vprofile.mineargs) $($other_ui.mcarg_box.Text)"

        $main_ui.statustext.Text = [string]$lang.checkjava
        [System.Windows.Forms.Application]::DoEvents()
        $javaexec = GetJava $manifest.javaVersion.component $main_ui.redownjav_box.Checked {
            param($i,$c)
            $main_ui.statustext.Text = [string]$lang.checkjava+" ($i/$c)"
            [System.Windows.Forms.Application]::DoEvents()
        }
        $main_ui.redownjav_box.Checked = $false
        if (-not $launching) {return EndLaunch}
        $main_ui.play_btn.Enabled = $false

        $main_ui.statustext.Text = ""
        if ($main_ui.launch_box.SelectedIndex -le 1) {$main_ui.window.Hide()}

        try {
            Set-Location $gdir
            info "Launching..."
            if ($other_ui.showarg_box.Checked) {
                info "Arguments: $($jvarg, $manifest.mainClass, $mcarg)"
            }
            & "$javaexec" @($jvarg-split' ') $manifest.mainClass @($mcarg-split' ') 2>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) {Write-Host $_ -ForegroundColor Red -BackgroundColor Black}
                else {Write-Host $_}
            }
            info "Exit code: $LASTEXITCODE"
            Set-Location $mchome
            if ($main_ui.launch_box.SelectedIndex -eq 0) {$main_ui.window.Show()}
            if ($LASTEXITCODE -ne 0) {
                [System.Windows.Forms.MessageBox]::Show("Game Crashed!`nSorry for the inconvenience...`nExit code: $LASTEXITCODE")
            }
            if ($main_ui.launch_box.SelectedIndex -eq 1) {$main_ui.window.Close()}
        } catch {warn "Launch error: $_"; Set-Location $mchome; $main_ui.window.Show()}

        $global:launching = $false

        $main_ui.play_btn.Text = [string]$lang.play
        $main_ui.play_btn.Enabled = $true
        } catch {
            [System.Windows.Forms.MessageBox]::Show("$_`nAt line $($_.InvocationInfo.ScriptLineNumber)", "Error", "OK", "Error")
            EndLaunch
        }
    }

    
    if ([System.IO.Directory]::Exists("$root/resources/lang")) {
        foreach ($file in (Get-ChildItem "$root/resources/lang" -File -Filter "*.json")) {
            try {
                $json = Get-Content ("$root/resources/lang/"+$file.name) -Raw | ConvertFrom-Json
                $idx = $main_ui.lang_box.Items.Add([PSCustomObject]@{
                    filename = $file.BaseName
                    name = $json.lang_name
                })
                if ($file.BaseName -eq $settings.lang) {
                    $main_ui.lang_box.SelectedIndex = $idx
                }
            } catch {
                warn "Error adding language $($file.BaseName)"
            }
        }
    }
    if ($main_ui.lang_box.Items.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show("There are no languages present!`nBecause of that every string will be empty.`nInstall a language or reinstall the app.", "Launshell")
    }

    try {
        $main_ui.resx_box.Value = [int]$settings.res_x
        $main_ui.resy_box.Value = [int]$settings.res_y
        $main_ui.fullscreen_box.Checked = [bool]$settings.fullscreen
        $main_ui.console_box.Checked = [bool]$settings.console
        $main_ui.launch_box.SelectedIndex = [int]$settings.on_launch
        $main_ui.dir_box.Text = [string]$settings.gamedir
        $main_ui.checkass_box.Checked = [bool]$settings.check_assets
        $main_ui.checkhash_box.Checked = [bool]$settings.check_hash
        $main_ui.showver_box.Checked = [bool]$settings.show_profile_ver
        $main_ui.authlib_box.Checked = [bool]$settings.useauthlib
        $main_ui.checkupd_box.Checked = [bool]$settings.checkupdates

        $main_ui.mem_box.Value = [math]::Max($main_ui.mem_box.Minimum, [int]$settings.ram)
        $main_ui.mem_slide.Value = [math]::Max($main_ui.mem_slide.Minimum, [int]$settings.ram)
        $main_ui.mem_slide.TickFrequency = $maxram/16

        $main_ui.mem_slide.Maximum = [int]$maxram
        
        $other_ui.mcarg_box.Text = [string]$settings.mc_args
        $other_ui.jvarg_box.Text = [string]$settings.jv_args
        $other_ui.opti_box.SelectedIndex = [int]$settings.optimized
        $other_ui.showarg_box.Checked = [bool]$settings.show_args
    } catch {ShowConsole $true; warn "Error loading settings, press any key to exit: $_"; pause; exit}


    ShowConsole $main_ui.console_box.Checked
    RefreshVersions
	RefreshUsers
    UpdateUserInfo



    $main_ui.mem_slide.Add_ValueChanged({
        param($i)
        $main_ui.mem_box.Value = $i.Value
    })
    $main_ui.mem_box.Add_ValueChanged({
        param($i)
        $main_ui.mem_slide.Value = [Math]::Max($main_ui.mem_slide.Minimum, [Math]::Min($main_ui.mem_slide.Maximum, $i.Value))
    })
    $main_ui.console_box.Add_CheckedChanged({param($i) ShowConsole($i.Checked)})

    $main_ui.dir_btn.Add_Click({
        $browsefolder.SelectedPath = $mchome
        if ($browsefolder.ShowDialog() -eq "OK") {
            $main_ui.dir_box.Text = $browsefolder.SelectedPath
            SaveUsers
            SaveProfiles

            $global:mchome = (Get-GameDir $browsefolder.SelectedPath)
            Set-Location $mchome

            if (-not (Test-Path "$mchome/launshell_profiles.json")) {
                Set-Content "$mchome/launshell_profiles.json" '[{"uuid":  "latest-release", "name":  "Latest Release", "json":  "latest", "opti":  1}]'
            }

            RefreshVersions
            RefreshUsers
            UpdateUserInfo
        }
    })

    $main_ui.folder.Add_Click({
        $vprofile = $main_ui.version_box.SelectedItem
        if ([string]::IsNullOrEmpty($vprofile.gamedir)) {
            explorer.exe $mchome
        } else {
            $main_ui.folder_choose.Show($main_ui.status, "0,$(-$main_ui.status.Height)")
        }
    })
    $main_ui.open_rootf.Add_Click({explorer.exe $mchome})
    $main_ui.open_versf.Add_Click({explorer.exe $main_ui.version_box.SelectedItem.gamedir})

    $main_ui.refresh.Add_Click({RefreshVersions})
    $main_ui.profile.Add_Click({RefreshVersionsUI; $version_ui.window.ShowDialog()})
    $main_ui.refresh_user.Add_Click({RefreshUsers; UpdateUserInfo})

    $main_ui.lang_box.Add_SelectedIndexChanged({
        param($i)
        $global:lang = GetLanguage $i.SelectedItem.filename
        [System.Windows.Forms.MessageBox]::Show([string]$lang.langchange, "Launshell", "OK", "Information")
    })
    $main_ui.dir_def.Add_Click({
        $main_ui.dir_box.Text = ""
        SaveUsers
        SaveProfiles
        $global:mchome = Get-GameDir
        Set-Location $mchome
        if (-not (Test-Path "$mchome/launshell_profiles.json")) {
            Set-Content "$mchome/launshell_profiles.json" '[{"uuid":  "latest-release", "name":  "Latest Release", "json":  "latest", "opti":  1}]'
        }
        RefreshVersions
        RefreshUsers
        UpdateUserInfo
    })
    $main_ui.play_btn.Add_Click({GameLaunch})
    $main_ui.other_btn.Add_Click({$other_ui.window.ShowDialog()})
    $main_ui.checkupd_btn.Add_Click({
        if (-not (CheckForUpdates)) {
            [System.Windows.Forms.MessageBox]::Show([string]$lang.nonewver, [string]$lang.updchecker, "Ok", "Information")
        }
    })

    function UpdateUserThingys {
        if ($user_ui.user_type.SelectedIndex -eq 0) {
            $user_ui.username.Visible = $true
            $user_ui.username.ReadOnly = $false
            $user_ui.randomize.Visible = $true
            $user_ui.randomize.Enabled = $true
            $user_ui.save_btn.Visible = $true
            $user_ui.remove_btn.Visible = $true
            $user_ui.other.Visible = $false
        } elseif ($edituser) {
            $user_ui.username.Visible = $true
            $user_ui.username.ReadOnly = $true
            $user_ui.randomize.Visible = $true
            $user_ui.randomize.Enabled = $false
            $user_ui.save_btn.Visible = $false
            $user_ui.remove_btn.Visible = $true
            $user_ui.other.Visible = $false
        } else {
            $user_ui.username.Visible = $false
            $user_ui.randomize.Visible = $false
            $user_ui.save_btn.Visible = $false
            $user_ui.remove_btn.Visible = $false
            $user_ui.other.Visible = $true
            $user_ui.other.Text = ([string]$lang.login_with -f $user_ui.user_type.SelectedItem)
        }
    }

    $main_ui.adduser_btn.Add_Click({
        $global:edituser = $false
        $user_ui.window.Text = [string]$lang.adduser
        $user_ui.remove_btn.Enabled = $false
        $user_ui.user_type.Enabled = $true
        $user_ui.user_type.SelectedIndex = 0
        $user_ui.username.Text = ""
        $user_ui.info.Text = ""
        $user_ui.window.ShowDialog()
    })
    $main_ui.changeuser_btn.Add_Click({
        $sel_usr = $main_ui.users_list.SelectedItem
        if ($sel_usr) {
            $global:edituser = $true
            $user_ui.window.Text = [string]$lang.changeuser
            $user_ui.remove_btn.Enabled = $true
            $user_ui.user_type.Enabled = $false
            if (-not ([string]::IsNullOrEmpty($sel_usr.type))-and $userTyper.ContainsKey($sel_usr.type)) {
                $user_ui.user_type.SelectedIndex = $userTyper[$sel_usr.type]
            } else { $user_ui.user_type.SelectedIndex = 0 }
            $user_ui
            $user_ui.username.Text = $sel_usr.Name
            $user_ui.info.Text = ""
            UpdateUserThingys
            $user_ui.window.ShowDialog()
        }
    })
    $main_ui.users_list.Add_SelectedIndexChanged({ UpdateUserInfo })

    $user_ui.save_btn.Add_Click({
        $user_ui.info.Text = ""
        if (-not [string]::IsNullOrEmpty($user_ui.username.Text)) {
            if (($user_ui.username.Text.Length -lt 3) -or ($user_ui.username.Text.Length -gt 16) -or (-not ($user_ui.username.Text -match "^[A-Za-z0-9_]+$"))) {
                [System.Windows.Forms.MessageBox]::Show([string]$lang.user_warn, [string]$lang.warn, "OK", "Warning")
            }
            if ($edituser) {
                $item = $main_ui.users_list.SelectedItem
                $main_ui.users_list.Items.Remove($main_ui.users_list.SelectedItem)
                $item.name = $user_ui.username.Text
                $main_ui.users_list.Items.Add($item)
                $main_ui.users_list.SelectedItem = $item
            } else {
                $main_ui.users_list.Items.Add([PSCustomObject]@{
                    name = $user_ui.username.Text
                    uuid = [guid]::NewGuid().ToString("N")
                    token = "0"
                    type = "plain"
                })
            }
            $user_ui.window.Close()
            SaveUsers
        } else {
            $user_ui.info.Text = [string]$lang.user_empty
        }
    })
    $user_ui.remove_btn.Add_Click({
        $user = $main_ui.users_list.SelectedItem
        if ($null -ne $user) {
            if ([System.Windows.Forms.MessageBox]::Show(([string]$lang.userdeletion -f $user.name), [string]$lang.areyousure, "YesNo", "Warning") -eq "Yes") {
                $main_ui.users_list.Items.Remove($main_ui.users_list.SelectedItem)
                $user_ui.window.Close()
                SaveUsers
            }
        }
    })
    $user_ui.randomize.Add_Click({$user_ui.username.Text = [string](CreateUsername)})
    $user_ui.user_type.Add_SelectedIndexChanged({UpdateUserThingys})

    $user_ui.other.Add_Click({
        if ($user_ui.user_type.SelectedIndex -eq 1) {
            $login_ui.window.Text = ([string]$lang.login_with -f "Ely.by")
            $result = $login_ui.window.ShowDialog()
            if ($result -ne "OK") {return}

            $body = @{
                username = $login_ui.username.Text
                password = $login_ui.password.Text
                clientToken = $settings.clientId
                # requestUser = $true
            }
            if (($login_ui.auth_check.Checked) -and ($login_ui.auth_box.Text.Length -ge 6) -and ($login_ui.auth_box.Text -as [int])) {
                $body.password += ":"+$login_ui.auth_box.Text
            }
            $bodys = $body | ConvertTo-Json -Depth 10

            $login_ui.username.Text = ""
            $login_ui.password.Text = ""
            $login_ui.auth_box.Text = ""

            info "Authenticating..."
            try {
                $response = Invoke-RestMethod -Uri "https://authserver.ely.by/auth/authenticate" -Method Post -ContentType "application/json" -Body $bodys
                $main_ui.users_list.Items.Add([PSCustomObject]@{
                    name = $response.selectedProfile.name
                    uuid = $response.selectedProfile.id
                    token = $response.accessToken
                    type = "elyby"
                })
                info "Authenticated!"
                $user_ui.window.Close()
                SaveUsers
            } catch {
                $user_ui.info.Text = [string]$lang.login_error
                error "Auth error: $_"
            }
        }
    })

    $login_ui.auth_box.Add_TextChanged({
        param($i)
        $res = -join ($i.Text.ToCharArray() | Where-Object {[char]::IsDigit($_)})
        if ($i.Text -ne $res) {
            $i.Text = $res
            $i.SelectionStart = $i.Text.Length
        }
        if ($i.Text.Length -gt 6) {
            $i.Text = $i.Text.Substring(0, 6)
            $i.SelectionStart = 6
        }
    })

    $verlist = $null
    function UpdateVersDialog {
        param($id)
        $version_dialog.ver.Items.Clear()

        if ($version_dialog.ver_adv.Checked -or (($id -eq "latest") -or ($id -eq "latest-snapshot"))) {
            $lid = $version_dialog.ver.Items.Add([PSCustomObject]@{id = "latest"})
            if ($id -eq "latest") {
                $version_dialog.ver.SelectedIndex = $lid
            }
            $lsid = $version_dialog.ver.Items.Add([PSCustomObject]@{id = "latest-snapshot"})
            if ($id -eq "latest-snapshot") {
                $version_dialog.ver.SelectedIndex = $lsid
            }
        }

        if ($version_dialog.inst.Checked) {
            foreach ($ver in GetOfflineVersionList) {
                if ($null -eq $ver) {continue}

                if (($ver.type -eq "old_beta") -and (-not $version_dialog.ver_beta.Checked) -and ($ver.id -ne $id)) {continue}
                if (($ver.type -eq "old_alpha") -and (-not $version_dialog.ver_alph.Checked) -and ($ver.id -ne $id)) {continue}
                if (($ver.type -eq "snapshot") -and (-not $version_dialog.ver_snap.Checked) -and ($ver.id -ne $id)) {continue}
                $idx = $version_dialog.ver.Items.Add($ver)
                if ($ver.id -eq $id) {
                    $version_dialog.ver.SelectedIndex = $idx
                }
            }
        } else {
            if ($null -eq $verlist) {$global:verlist = GetOnlineVersionList}
            foreach ($ver in $verlist) {
                if (($null -eq $ver) -or ($null -eq $ver.id)) {continue}
                if (($ver.type -eq "old_beta") -and (-not $version_dialog.ver_beta.Checked) -and ($ver.id -ne $id)) {continue}
                if (($ver.type -eq "old_alpha") -and (-not $version_dialog.ver_alph.Checked) -and ($ver.id -ne $id)) {continue}
                if (($ver.type -eq "snapshot") -and (-not $version_dialog.ver_snap.Checked) -and ($ver.id -ne $id)) {continue}
                $idx = $version_dialog.ver.Items.Add($ver)
                if ($ver.id -eq $id) {
                    $version_dialog.ver.SelectedIndex = $idx
                }
            }
        }
    }

    $version_dialog.ver_beta.Add_CheckedChanged({UpdateVersDialog})
    $version_dialog.ver_alph.Add_CheckedChanged({UpdateVersDialog})
    $version_dialog.ver_snap.Add_CheckedChanged({UpdateVersDialog})
    $version_dialog.ver_adv.Add_CheckedChanged({UpdateVersDialog})

    $version_ui.refresh_btn.Add_Click({RefreshVersionsUI})
    $version_ui.list_box.Add_SelectedIndexChanged({
        param($i)
        $version_ui.delete_btn.Enabled = ($i.SelectedItem -ne $null)
        $version_ui.edit_btn.Enabled = ($i.SelectedItem -ne $null)
    })
    $version_ui.add_btn.Add_Click({
        $global:editver = $false
        $version_dialog.info.Text = ""
        $version_dialog.name.Text = ([string]$lang.newprofile -f ($version_ui.list_box.Items.Count+1))
        $version_dialog.arg.Text = ""
        $version_dialog.mcarg.Text = ""
        $version_dialog.dir.Text = ""
        $version_dialog.mem.Value = 0
        $version_dialog.opti_box.SelectedIndex = 1
        UpdateVersDialog
        
        $version_dialog.window.Text = [string]$lang.addver
        $version_dialog.window.ShowDialog()
    })
    $version_ui.edit_btn.Add_Click({
        $sel = $version_ui.list_box.SelectedItem
        $global:editver = $true
        $version_dialog.info.Text = ""
        $version_dialog.name.Text = $sel.name
        $version_dialog.arg.Text = $sel.args
        $version_dialog.mcarg.Text = $sel.mineargs
        $version_dialog.dir.Text = $sel.gamedir
        $version_dialog.mem.Value = $sel.memory
        $version_dialog.opti_box.SelectedIndex = $sel.opti
        UpdateVersDialog $sel.json
        $version_dialog.window.Text = [string]$lang.editver
        $version_dialog.window.ShowDialog()
    })

    $version_ui.delete_btn.Add_Click({
        $version = $main_ui.version_box.Items | Where-Object {$_.uuid -eq $version_ui.list_box.SelectedItem.uuid}
        if ($null -ne $version) {
            if ([System.Windows.Forms.MessageBox]::Show(([string]$lang.verdeletion -f $version.dname), [string]$lang.areyousure, "YesNo", "Warning") -eq "Yes") {
                $version_ui.list_box.Items.Remove($version_ui.list_box.SelectedItem)
                $main_ui.version_box.Items.Remove($version)
                SaveProfiles
            }
        }
    })

    
    $version_dialog.save_btn.Add_Click({
        if ([string]::IsNullOrEmpty($version_dialog.name.Text)) {
            $version_dialog.info.Text = [string]$lang.ver_empty
            return
        }
        if ([string]::IsNullOrEmpty($version_dialog.ver.SelectedItem.id)) {
            $version_dialog.info.Text = [string]$lang.ver_none
            return
        }
        $version_dialog.window.Close()

        if ($editver) {
            $item = $main_ui.version_box.Items | Where-Object {$_.uuid -eq $version_ui.list_box.SelectedItem.uuid}

            $ver = [PSCustomObject]@{
                uuid=$item.uuid
                name=$version_dialog.name.Text
                dname="" 
                json=$version_dialog.ver.SelectedItem.id
                gamedir=$version_dialog.dir.Text
                memory=$version_dialog.mem.Value
                args=$version_dialog.arg.Text
                mineargs=$version_dialog.mcarg.Text
                opti=$version_dialog.opti_box.SelectedIndex
            }

            if ($main_ui.showver_box.Checked) { $ver.dname = "$($ver.name) ($($ver.json))" }
            else { $ver.dname = $ver.name }

            $idx = $main_ui.version_box.Items.Add($ver)
            if (-not $main_ui.showver_box.Checked) { $ver.dname = "$($ver.name) ($($ver.json))"  }
            $version_ui.list_box.Items.Add($ver)
            if ($item -eq $main_ui.version_box.SelectedItem) {
                $main_ui.version_box.SelectedIndex = $idx
            }

            $main_ui.version_box.Items.Remove($item)
            $version_ui.list_box.Items.Remove($version_ui.list_box.SelectedItem)
            
            SaveProfiles
        } else {
            $ver = [PSCustomObject]@{
                uuid=[guid]::NewGuid().ToString("N")
                name=$version_dialog.name.Text
                dname="" 
                json=$version_dialog.ver.SelectedItem.id
                gamedir=$version_dialog.dir.Text
                memory=$version_dialog.mem.Value
                args=$version_dialog.arg.Text
                mineargs=$version_dialog.mcarg.Text
                opti=$version_dialog.opti_box.SelectedIndex
            }

            if ($main_ui.showver_box.Checked) { $ver.dname = "$($ver.name) ($($ver.json))" }
            else { $ver.dname = $ver.name }
            $main_ui.version_box.Items.Add($ver)
            if (-not $main_ui.showver_box.Checked) { $ver.dname = "$($ver.name) ($($ver.json))"  }
            $version_ui.list_box.Items.Add($ver)
            SaveProfiles
        }
    })

    $version_dialog.inst.Add_CheckedChanged({ UpdateVersDialog $version_dialog.ver.SelectedItem.id })
    $version_dialog.dirdef_btn.Add_Click({ $version_dialog.dir.Text = "" })

    $version_dialog.dir_btn.Add_Click({
        if ([string]::IsNullOrEmpty($version_dialog.dir.Text)) {$browsefolder.SelectedPath = $mchome}
        else {$browsefolder.SelectedPath = $version_dialog.dir.Text}
        if ($browsefolder.ShowDialog() -eq "OK") {
            $version_dialog.dir.Text = $browsefolder.SelectedPath
        }
    })
    
    $main_ui.window.Add_Closing({
        param($i, $e)
        if ($launching) {$e.Cancel = $true}
    })

    [System.Windows.Forms.Application]::Add_ThreadException({
        param($i, $e)
        try {
            throw $e.Exception
        } catch {
            error "$_`n    At line $($_.InvocationInfo.ScriptLineNumber)"
        }
    })

    ##[ModificationLocationAfterLoad]##

    [void]$main_ui.window.ShowDialog()

    ##[ModificationLocationAfterUI]##
    
    WriteJson "settings" "show_args" $other_ui.showarg_box.Checked
    WriteJson "settings" "checkupdates" $main_ui.checkupd_box.Checked 
    WriteJson "settings" "useauthlib" $main_ui.authlib_box.Checked 
    WriteJson "settings" "show_profile_ver" $main_ui.showver_box.Checked 
    WriteJson "settings" "user" $main_ui.users_list.SelectedItem.uuid
    WriteJson "settings" "fullscreen" $main_ui.fullscreen_box.Checked
    WriteJson "settings" "res_x" $main_ui.resx_box.Value
    WriteJson "settings" "res_y" $main_ui.resy_box.Value
    WriteJson "settings" "ram" $main_ui.mem_box.Value
    WriteJson "settings" "on_launch" $main_ui.launch_box.SelectedIndex
    WriteJson "settings" "gamedir" $mchome
    WriteJson "settings" "lang" $main_ui.lang_box.SelectedItem.filename
    WriteJson "settings" "console" $main_ui.console_box.Checked
    WriteJson "settings" "version" $main_ui.version_box.SelectedItem.uuid
    WriteJson "settings" "check_assets" $main_ui.checkass_box.Checked
    WriteJson "settings" "check_hash" $main_ui.checkhash_box.Checked
    WriteJson "settings" "optimized" $other_ui.opti_box.SelectedIndex
    WriteJson "settings" "mc_args" $other_ui.mcarg_box.Text
    WriteJson "settings" "jv_args" $other_ui.jvarg_box.Text
    
    ##[ModificationLocationAfterSettings]##
} catch {
    warn "UI wasn't loaded: $_"
}

ConvertTo-Json $settings -Depth 20 | Set-Content "$root/settings.json"

Set-Location $root
ShowConsole $true