<#
.SYNOPSIS
    Launshell - A Minecraft Launcher made in the wrong language.

.DESCRIPTION
    Windows only minecraft launcher, an supports only PowerShell 5.1.
#>

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Warning "PowerShell 5.1 or higher is required."
    Start-Sleep 3
    exit 1
}

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

if ($PSScriptRoot) { $root = $PSScriptRoot}
#elseif ($MyInvocation.MyCommand.Path) {$root = Split-Path -Path $MyInvocation.MyCommand.Path -Parent}
else {$root = Get-Location}

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

function JoinPath {
    param ([Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$paths)
    return [System.IO.Path]::Combine($paths)
}
function DownloadFile {
    param([string]$Uri, [string]$OutFile)
    try {
        return Invoke-WebRequest -Uri $Uri -OutFile $OutFile
    } catch {
        error "Could not download file: $_"
    }
}


$launchver = "0.4.7"

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

$arch = if ([Environment]::Is64BitOperatingSystem) { "64" } else { "86" }
$maxram = ([Microsoft.VisualBasic.Devices.ComputerInfo]::new().TotalPhysicalMemory / 1MB)
$OsVersion = [System.Environment]::OSVersion.Version.ToString()

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
#$log4j = "-Dlog4j2.formatMsgNoLookups=true"
$crack = "-Dminecraft.api.auth.host=http:// -Dminecraft.api.account.host=http:// -Dminecraft.api.session.host=http:// -Dminecraft.api.services.host=http://"

<#function ConvertProfiles {
    param([string]$path)
    if (-not (Test-Path $path)) {return}
    $profiles1 = Get-Content($path)-Raw|ConvertFrom-Json
    $profiles = @{}
    foreach ($temp in $profiles1.PSObject.Properties) {
        $value = $temp.Value
        $key = $temp.Name
        $profiles.uuid = $key
        if ($value.name -eq "") {
            $profiles.name = $value.lastVersionId+" converted"
        } else {
            $profiles.name = $value.name+" converted"
        }
        $profiles.json = $value.lastVersionId
        $profiles.gamedir = "!global!"
        $profiles.memory = "!global!"
        $profiles.optimized = "global"
        $profiles.args = "!global!"
        $profiles.mineargs = "!global!"
    }
    return $profiles
}#>

$u_a = @("Swift", "Lazy", "Brave", "Silent", "Happy", "Clever", "Dark", "Fuzzy", "Witty", "Mighty", "Muddy", "Mystic", "Shadow", "Oak", "Holy", "Open", "Neat")
$u_c = @("Fox", "Tiger", "Eagle", "Panda", "Wolf", "Dragon", "Otter", "Bear", "Hawk", "Shark", "Cat", "Llama", "Hamster", "Rabbit", "Owl", "Lion", "Fiber", "Sage", "Clover", "Relic")
function CreateUsername {
    $a = Get-Random $u_a
    $b = Get-Random $u_c
    $nums = 15 - "$a$b".Length
    $max = [int][math]::Pow(10, $nums) - 1
    $min = [int][math]::Pow(10, $nums - 1)
    $c = Get-Random -Minimum $min -Maximum ($max + 1)
    return "$a$b$c"
}

function RuleCheck {
    param($rule)
    $out = $rule.action -eq "allow"
    if ($rule.os) {
        if ($rule.os.name -and ($rule.os.name -ne "windows")) {
            return -not $out
        }
        if ($rule.os.version -and (-not ($OsVersion -match $rule.os.version))) {
            return -not $out
        }
        if ($rule.os.arch -and ($rule.os.arch.ToLower() -ne $arch)) {
            return -not $out
        }
    }
    return $out
}

function GetClassFiles {
    param($manifest, [bool]$rewrite, [bool]$hashes, $call)

    $verFolder = JoinPath $mchome "versions" $manifest.id
    $verNative = JoinPath $verFolder "natives"
    $verFile = JoinPath $verFolder ($manifest.id+".jar")
    $inf = JoinPath $verNative "META-INF"

    $donatives = $false
    if (-not [System.IO.Directory]::Exists($verNative)) {$donatives = $true; [void](New-Item $verNative -Type Directory -Force)}
    
    #Client
    if (-not [System.IO.File]::Exists($verFile) -or $rewrite -or ($hashes -and ((Get-FileHash $verFile -Algorithm SHA1).Hash -ne $manifest.downloads.client.sha1))) {
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
    
    $cp = ""
    # Libraries
    $count = $(@($manifest.libraries).Count)
    $index = 0
    foreach ($lib in $manifest.libraries) {
        $index++
        if ($call -is [ScriptBlock]) {try{&$call $index $count}catch{}}
        if ($lib.rules -and -not ($lib.rules | Where-Object {RuleCheck $_})) {continue}

        if ($lib.downloads.artifact) {
            $libpath = $lib.downloads.artifact.path
            $dest = JoinPath $LibsDir $libpath
            $destPath = Split-Path $dest -Parent

            if (-not [System.IO.File]::Exists($dest) -or $rewrite -or ($hashes -and ((Get-FileHash $dest -Algorithm SHA1).Hash -ne $lib.downloads.artifact.sha1)) ) {
                [void](New-Item $destPath -Type Directory -Force)
                DownloadFile $lib.downloads.artifact.url $dest
            }
            $cp += $dest + ";"
        }
        if ($lib.downloads.classifiers -and $lib.natives.windows) {
            $ckey = $lib.natives.windows.Replace('${arch}', $arch)
            $libcl = $lib.downloads.classifiers.$ckey
            if (-not $libcl) {continue}
            $libpath = $libcl.path
            $dest = JoinPath $LibsDir "$libpath.zip"
            $destPath = Split-Path $dest -Parent
            if (-not [System.IO.File]::Exists($dest) -or $rewrite -or $donatives) {
                [void](New-Item $destPath -Type Directory -Force)
                DownloadFile $libcl.url $dest
                if ($rewrite) {
                    Expand-Archive $dest $verNative
                } else {
                    Expand-Archive $dest $verNative -Force
                }
            }
        }
    }
    $cp += $verFile
    if ([System.IO.Directory]::Exists($inf)) {[System.IO.Directory]::Delete($inf, $true)}
    foreach ($item in (Get-ChildItem $verNative -File)) {
        if ($item.Extension -ne ".dll") {
            Remove-Item $item.FullName -Force
        }
    }
    return $cp.Replace("\", "/")
}

function CheckManifest {
    param([string]$version, [bool]$rewrite)
    $manifestLoc = JoinPath $mchome "versions" $version "$version.json"
    if (-not [System.IO.File]::Exists($manifestLoc) -or $rewrite) {
        $verlist = GetOnlineVersionList
        if ($verlist) {
            $verinlist = $verlist.Where({ $_.id -eq $version }, "First")
            if ($verinlist) {
                $versionDir = JoinPath $mchome "versions" $version
                [void](New-Item $versionDir -Type Directory -Force)
                DownloadFile $verinlist.url $manifestLoc
            }
        }
    }
    return $manifestLoc
}

function GetAssetDir {
    param($manifest)
    $assetDir = JoinPath $mchome "assets"
    $resDir = JoinPath $mchome "resources"
    
    $virtDir = JoinPath $assetDir "virtual" $manifest.id
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
    param($manifest, [bool]$rewrite, [bool]$hashes, $call)

    $assetIndex = $manifest.assetIndex
    if (-not $assetIndex) {return}

    $assetDir = JoinPath $mchome "assets"
    $resDir = JoinPath $mchome "resources"
    $objectsDir = JoinPath $assetDir "objects"
    $indexesDir = JoinPath $assetDir "indexes"

    $indexFile = JoinPath $indexesDir "$($assetIndex.id).json"
    $virtDir = JoinPath $assetDir "virtual" $assetIndex.id
    if (-not [System.IO.Directory]::Exists($indexesDir)) {[void](New-Item $indexesDir -ItemType Directory -Force)}
    if (-not [System.IO.File]::Exists($indexFile) -or $rewrite) {
        DownloadFile $assetIndex.url $indexFile
    }
    if (-not [System.IO.File]::Exists($indexFile)) {return}
    $indexJson = Get-Content $indexFile -Raw | ConvertFrom-Json
    $objects = $indexJson.objects

    
    $props = $objects.PSObject.Properties
    $count = $(@($props).Count)
    $index = 0
    foreach ($key in $props.Name) {
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
        if (-not [System.IO.File]::Exists($assetFile) -or $rewrite -or $hashes -and ((Get-FileHash $assetFile -Algorithm SHA1).Hash -ne $hash) ) {
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
    if (-not $javalist.$javaVer) {
        return
    }

    try {
        $jf = Invoke-RestMethod $javalist.$javaver.manifest.url -Method Get
    } catch {
        error "Could not get $javaVer manifest: $_"
        return
    }
    if (-not $jf.files) {return}
    $javadir = JoinPath $root "java" $javaVer
    if (-not [System.IO.Directory]::Exists($javadir)) {[void](New-Item $javadir -ItemType Directory -Force)}
    $props = $jf.files.PSObject.Properties
    $count = $(@($props).Count)
    $index = 0
    foreach ($file in $props) {
        $index++
        if ($call -is [ScriptBlock]) {try{&$call $index $count}catch{}}
        $filePath = JoinPath $javadir $file.Name
        $fileDir = Split-Path $filePath -Parent
        if ($file.Value.type -eq "directory") {continue}
        if (-not [System.IO.Directory]::Exists($fileDir)) {[void](New-Item -ItemType Directory -Path $fileDir -Force)}
        if (-not [System.IO.File]::Exists($filePath) -or $rewrite) {
            DownloadFile $file.Value.downloads.raw.url $filePath
        }
    }
}

function GetJava {
    param($manifest, $rewrite, $call)
    $rejava = $manifest.javaVersion.component
    if (-not $rejava) {
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

    if ($manifest.arguments) {
        foreach ($item in $manifest.arguments.game) {
            if ($item -is [string]) {
                if ($item.Trim() -ne "") {
                    $str += ' "'+$item+'"'
                }
            }  elseif ($item -is [PSCustomObject]) {
                if ($item.rules) {continue}
                if ($item.value -and ($item.value.Trim() -ne "")) {
                    $str += ' "'+[string]$item.value+'"'
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
	    '${auth_xuid}' = $PSObj.Uuid
	    '${clientid}' = $PSObj.Uuid
	    '${auth_session}' = $PSObj.Uuid
	    '${auth_access_token}' = $PSObj.Uuid
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
    $str = '-Xmx${xmx}m -Xms${xms}m -ea '+$common

    if ($PSObj.xmx -ge 2048) {
        $str += ' -Xss2M'
    }
    
    if ($PSObj.optimized) {
        $str += ' '+$PSObj.optimized.args
    }
        
    foreach ($arg in $moreargs) {
        if ($arg -and $arg.Trim() -ne "") {
            $str += ' '+$arg
        }
    }
    
    if ($manifest.arguments) {
        foreach ($item in $manifest.arguments.jvm) {
            if ($item -is [string]) {
                if ($item.Trim() -ne "") {
                    $str += ' '+$item
                }
            } elseif ($item -is [PSCustomObject]) {
                if ($item.rules) {
                    if ($item.rules -and -not ($item.rules | Where-Object {RuleCheck $_})) {continue}
                }
                if ($item.value -and ($item.value.Trim() -ne "")) {
                    $str += ' "'+[string]$item.value+'"'
                }
            }
        }
    } else {
        $str += ' -Djava.library.path=${natives_directory} -cp ${classpath}'
    }

    $each = @{
        '${xmx}' = $PSObj.xmx
        '${xms}' = $PSObj.xms
        '${natives_directory}' = '"'+$PSObj.natives+'"'
        '${classpath}' = '"'+$PSObj.classes+'"'
        '${launcher_name}' = "java-minecraft-launcher"
        '${launcher_version}' = "0.3.1"
    }
    foreach ($key in $each.Keys) {
        $str = $str.Replace($key, $each[$key])
    }

    return $str
}

#Other

function GetLanguage {
    param([string]$langname)
    try {
        return Get-Content "$root/resources/lang/$langname.json" -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        return Get-Content "$root/resources/lang/en_us.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    }
}

try {
    if (-not [System.IO.File]::Exists("$root/settings.json")) {Set-Content "$root/settings.json" '{"res_x": 1280, "res_y": 720, "ram": 1024, "lang": "en_us", "check_assets": true, "check_hash": true, "optimized": 1, "version": "latest-release"}'; $global:first = $true}
    $settings = Get-Content "$root/settings.json" -Raw | ConvertFrom-Json
    $mchome = (Get-GameDir $settings.gamedir)
    $lang = GetLanguage $settings.lang
} catch {warn "Error loading jsons: $_"}
Set-Location $mchome

function GetVersionManifest {
    $mfpath = JoinPath $root "version_manifest.json"
    DownloadFile "https://launchermeta.mojang.com/mc/game/version_manifest.json" $mfpath
    $mf = Get-Content $mfpath -Raw | ConvertFrom-Json
    return $mf
}
function GetOnlineVersionList {
    $mf = GetVersionManifest
    return $mf.versions
}

function GetOfflineVersionList {
    $files = Get-ChildItem -Path "$mchome/versions" -Recurse -Filter *.json
    $versions = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $ver = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        $versions.Add($ver)
    }
    return $versions
}

if (-not (Test-Path "$mchome/launshell_profiles.json")) {
    Set-Content "$mchome/launshell_profiles.json" '[{"uuid":  "latest-release", "name":  "Latest Release", "json":  "latest", "opti":  1},{"uuid":  "latest-snapshot", "name":  "Latest Snapshot", "json":  "latest-snapshot", "opti":  1}]'
}

$launching = $false

try {
    $resources = @{
        main_icon = [System.Drawing.Icon]::new("$root\resources\icons\minecraft.ico")
        folder_status = [System.Drawing.Image]::FromFile("$root\resources\icons\folder_status.png")
        refresh = [System.Drawing.Image]::FromFile("$root\resources\icons\refresh.png")
        refresh_status = [System.Drawing.Image]::FromFile("$root\resources\icons\refresh_status.png")
        profiles_status = [System.Drawing.Image]::FromFile("$root\resources\icons\vermgr_status.png")
        add = [System.Drawing.Image]::FromFile("$root\resources\icons\add.png")
        delete = [System.Drawing.Image]::FromFile("$root\resources\icons\delete.png")
        edit = [System.Drawing.Image]::FromFile("$root\resources\icons\edit.png")
        filter = [System.Drawing.Image]::FromFile("$root\resources\icons\filter.png")
        random = [System.Drawing.Image]::FromFile("$root\resources\icons\random.png")
        fox = [System.Drawing.Image]::FromFile("$root\resources\icons\fox.png")
        person = [System.Drawing.Image]::FromFile("$root\resources\icons\person.png")
    }

    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    . "$root\resources\LauncherUI.ps1"
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

    function Get-ProfileDP {

    }
    function RefreshVersions {
        if ($main_ui.version_box.SelectedIndex -ne -1) {WriteJson "settings" "version" $main_ui.version_box.SelectedItem.uuid}
        $main_ui.version_box.Items.Clear()
        $profiles = Get-Content "$mchome/launshell_profiles.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        try {
            foreach ($version in $profiles) {
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
        $profiles = Get-Content "$mchome/launshell_profiles.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        try {
            foreach ($version in $profiles) {
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
				$main_ui.user_box.Text = $user.name
				$main_ui.changeuser_btn.Enabled = $true
			}
		}
	}

    
    function SaveUsers {ConvertTo-Json $main_ui.users_list.Items -Depth 100 | Set-Content "$mchome/launshell_users.json"}
    function SaveProfiles {ConvertTo-Json $main_ui.version_box.Items -Depth 100 | Set-Content "$mchome/launshell_profiles.json"}

    function GameLaunch {
		if ([string]::IsNullOrEmpty($main_ui.users_list.SelectedItem.name)) {$main_ui.statustext.Text = [string]$lang.selectacc;return}
		if ($main_ui.version_box.SelectedIndex -eq -1) {$main_ui.statustext.Text = [string]$lang.selectver;return}

        $profile = $main_ui.version_box.SelectedItem
        $main_ui.play_btn.Enabled = $false

        $launching = $true

        $json = $profile.json

        if ($profile.json -eq "latest") {
            $json = (GetVersionManifest).latest.release
        } elseif ($profile.json -eq "latest-snapshot") {
            $json = (GetVersionManifest).latest.snapshot
        }

        $main_ui.statustext.Text = [string]$lang.checkmanifest
        [System.Windows.Forms.Application]::DoEvents()

        $newdown = -not [System.IO.File]::Exists("$mchome/versions/$json/$json.jar")
        $manifestPath = CheckManifest $json $main_ui.redownlib_box.Checked
        

        if (-not [System.IO.File]::Exists($manifestPath)) {warn "Could not find the version json."; return}
        
        $manifest = Get-Content ($manifestPath) -Raw | ConvertFrom-Json
        
        $main_ui.statustext.Text = [string]$lang.checkfiles
        [System.Windows.Forms.Application]::DoEvents()

        $classes = GetClassFiles $manifest $main_ui.redownlib_box.Checked $main_ui.checkhash_box.Checked {
            param($i,$c)
            $main_ui.statustext.Text = [string]$lang.checkfiles+" ($i/$c)"
            [System.Windows.Forms.Application]::DoEvents()
        }
        $main_ui.redownlib_box.Checked = $false
        
        if ($main_ui.checkass_box.Checked -or $main_ui.redownass_box.Checked -or $newdown) {
            $main_ui.statustext.Text = [string]$lang.checkassets
            [System.Windows.Forms.Application]::DoEvents()
            CheckAssets $manifest $main_ui.redownass_box.Checked $main_ui.checkhash_box.Checked {
                param($i,$c)
                $main_ui.statustext.Text = [string]$lang.checkassets+" ($i/$c)"
                [System.Windows.Forms.Application]::DoEvents()
            }
            $main_ui.redownass_box.Checked = $false
        }
        $adir = GetAssetDir $manifest

        if ([string]::IsNullOrEmpty($profile.gamedir)) {$gdir = (Resolve-Path $mchome).Path}
        else {$gdir = (Resolve-Path $profile.gamedir).Path}

        if ($profile.memory -le 0) {$mem = $main_ui.mem_box.Value}
        else {$mem = $profile.memory}
        
        if ([string]::IsNullOrEmpty($main_ui.users_list.SelectedItem.uuid)) {$usid = (New-GuidFromString $main_ui.users_list.SelectedItem.name)} else {$usid = $main_ui.users_list.SelectedItem.uuid}
        if ([string]::IsNullOrEmpty($main_ui.users_list.SelectedItem.token)) {$ustk = $usid} else {$ustk = $main_ui.users_list.SelectedItem.token}
        $mcargc = [PSCustomObject]@{
            Username=$main_ui.users_list.SelectedItem.name
            GameDir=$gdir
            AssetDir=$adir
            Uuid=$usid
            Token=$ustk
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

        $jva = @($profile.args, $other_ui.jvarg_box.Text)
        if ($other_ui.opti_box.SelectedIndex -ne 0) {
            $jva += $optimized[$other_ui.opti_box.SelectedIndex-1].args
        }
        if ($other_ui.auth_box.Checked) {
            $jva += $crack
        }
        
        $jvarg = BuildJvmArguments $manifest $jvargc $jva
        $mcarg = BuildArguments $manifest $mcargc "$($profile.mineargs) $($other_ui.mcarg_box.Text)"

        $main_ui.statustext.Text = [string]$lang.checkjava
        [System.Windows.Forms.Application]::DoEvents()
        $javaexec = GetJava $manifest $main_ui.redownjav_box.Checked {
            param($i,$c)
            $main_ui.statustext.Text = [string]$lang.checkjava+" ($i/$c)"
            [System.Windows.Forms.Application]::DoEvents()
        }
        $main_ui.redownjav_box.Checked = $false

        $main_ui.statustext.Text = ""
        if ($main_ui.launch_box.SelectedIndex -le 1) {$main_ui.window.Hide()}

        try {
            Set-Location $gdir
            info "Arguments: $($jvarg, $manifest.mainClass, $mcarg)"
            & "$javaexec" @($jvarg-split' ') $manifest.mainClass @($mcarg-split' ') | ForEach-Object { Write-Host $_ }
            Set-Location $mchome
        } catch {warn "Java error: $_"; Set-Location $mchome}

        $launching = $false

        if ($main_ui.launch_box.SelectedIndex -eq 0) {$main_ui.window.Show()}
        if ($main_ui.launch_box.SelectedIndex -eq 1) {$main_ui.window.Close()}
        $main_ui.play_btn.Enabled = $true
    }

    
    try {foreach ($file in (Get-ChildItem "$root\resources\lang" -File)) {
        $json = Get-Content("$root\resources\lang\"+$file.name)-Raw|ConvertFrom-Json
        $idx = $main_ui.lang_box.Items.Add([PSCustomObject]@{
            filename = $file.BaseName
            name = $json.lang_name
        })
        if ($file.BaseName -eq $settings.lang) {
            $main_ui.lang_box.SelectedIndex = $idx
        }
    }} catch {warn "Error adding languages: $_"}

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

        $main_ui.mem_box.Value = [math]::Max($main_ui.mem_box.Minimum, [int]$settings.ram)
        $main_ui.mem_slide.Value = [math]::Max($main_ui.mem_slide.Minimum, [int]$settings.ram)
        $main_ui.mem_slide.TickFrequency = $maxram/16

        $main_ui.mem_slide.Maximum = [int]$maxram
        
        $other_ui.auth_box.Checked = [bool]$settings.replace_auth
        $other_ui.mcarg_box.Text = [string]$settings.mc_args
        $other_ui.jvarg_box.Text = [string]$settings.jv_args
        $other_ui.opti_box.SelectedIndex = [int]$settings.optimized
    } catch {ShowConsole $true; warn "Error loading settings, press any key to exit: $_"; pause; exit}


    ShowConsole $main_ui.console_box.Checked
    RefreshVersions
	RefreshUsers



    $main_ui.mem_slide.Add_ValueChanged({
        param($i)
        $main_ui.mem_box.Value = $i.Value
    })
    $main_ui.mem_box.Add_ValueChanged({
        param($i)
        $main_ui.mem_slide.Value = [Math]::Max($main_ui.mem_slide.Minimum, [Math]::Min($main_ui.mem_slide.Maximum, $i.Value))
    })
    $main_ui.console_box.Add_CheckedChanged({param($i) ShowConsole($i.Checked)})
    $main_ui.adduser_btn.Add_Click({
        $user_ui.window.Text = [string]$lang.adduser
        $user_ui.remove_btn.Enabled = $false
        $user_ui.username.Text = ""
        $user_ui.info.Text = ""
        $user_ui.window.ShowDialog()
    })
    $main_ui.changeuser_btn.Add_Click({
        $sel_usr = $main_ui.users_list.SelectedItem
        if ($sel_usr) {
            $user_ui.window.Text = [string]$lang.changeuser
            $user_ui.remove_btn.Enabled = $true
            $user_ui.username.Text = $sel_usr.Name
            $user_ui.info.Text = ""
            $user_ui.window.ShowDialog()
        }
    })
    $main_ui.users_list.Add_SelectedIndexChanged({
        param($i)
        $main_ui.changeuser_btn.Enabled = ($i.SelectedItem -ne $null)
        $main_ui.user_box.Text = $i.SelectedItem.name
    })

    $main_ui.dir_btn.Add_Click({
        $browsefolder.SelectedPath = $main_ui.dir_box.Text
        $sure = $browsefolder.ShowDialog()
        if ($sure -eq "OK") {
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
        }
    })
    $main_ui.folder.Add_Click({
        $profile = $main_ui.version_box.SelectedItem
        if ([string]::IsNullOrEmpty($profile.gamedir)) {
            explorer.exe $mchome
        } else {
            $main_ui.folder_choose.Show($main_ui.status, "0,0")
        }
    })
    $main_ui.open_rootf.Add_Click({explorer.exe $mchome})
    $main_ui.open_versf.Add_Click({explorer.exe $main_ui.version_box.SelectedItem.gamedir})
    $main_ui.refresh.Add_Click({RefreshVersions})
    $main_ui.profile.Add_Click({RefreshVersionsUI; $version_ui.window.ShowDialog()})
    $main_ui.refresh_user.Add_Click({RefreshUsers})

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
    })
    $main_ui.play_btn.Add_Click({GameLaunch})
    $main_ui.other_btn.Add_Click({$other_ui.window.ShowDialog()})

    $user_ui.save_btn.Add_Click({
        $user_ui.info.Text = ""
        if (-not [string]::IsNullOrEmpty($user_ui.username.Text)) {
            if ($user_ui.remove_btn.Enabled) {
                $item = $main_ui.users_list.SelectedItem
                $main_ui.users_list.Items.Remove($main_ui.users_list.SelectedItem)
                $item.name = $user_ui.username.Text
                $main_ui.users_list.Items.Add($item)
                $main_ui.users_list.SelectedItem = $item
            } else {
                $main_ui.users_list.Items.Add([PSCustomObject]@{
                    name = $user_ui.username.Text
                    uuid = [guid]::NewGuid().ToString("N")
                    token = "token:"+[guid]::NewGuid().ToString("N")
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
        if ($user) {
            $sure = [System.Windows.Forms.MessageBox]::Show(([string]$lang.userdeletion).Replace("!usr!", $user.name), [string]$lang.areyousure, "YesNo", "Warning")
            if ($sure -eq "Yes") {
                $main_ui.users_list.Items.Remove($main_ui.users_list.SelectedItem)
                $user_ui.window.Close()
                SaveUsers
            }
        }
        
    })
    $user_ui.randomize.Add_Click({$user_ui.username.Text = [string](CreateUsername)})

    $verlist = $null
    function UpdateVersDialog {
        param($id)
        $version_dialog.ver.Items.Clear()
        if ($version_dialog.inst.Checked) {
            foreach ($ver in GetOfflineVersionList) {
                if ($null -eq $ver) {continue}
                if (($ver.type -eq "old_beta") -and (-not $version_dialog.ver_beta.Checked)) {continue}
                if (($ver.type -eq "old_alpha") -and (-not $version_dialog.ver_alph.Checked)) {continue}
                if (($ver.type -eq "snapshot") -and (-not $version_dialog.ver_snap.Checked)) {continue}
                $idx = $version_dialog.ver.Items.Add($ver)
                if ($ver.id -eq $id) {
                    $version_dialog.ver.SelectedIndex = $idx
                }
            }
        } else {
            
            if ($version_dialog.ver_adv.Checked) {
                $lid = $version_dialog.ver.Items.Add([PSCustomObject]@{id = "latest"})
                if ($id -eq "latest") {
                    $version_dialog.ver.SelectedIndex = $lid
                }
                $lsid = $version_dialog.ver.Items.Add([PSCustomObject]@{id = "latest-snapshot"})
                if ($id -eq "latest-snapshot") {
                    $version_dialog.ver.SelectedIndex = $lsid
                }
            }

            if (-not $verlist) {$verlist = GetOnlineVersionList}

            foreach ($ver in $verlist) {
                if ($null -eq $ver) {continue}
                if (($ver.type -eq "old_beta") -and (-not $version_dialog.ver_beta.Checked)) {continue}
                if (($ver.type -eq "old_alpha") -and (-not $version_dialog.ver_alph.Checked)) {continue}
                if (($ver.type -eq "snapshot") -and (-not $version_dialog.ver_snap.Checked)) {continue}
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
        $version_dialog.edit = $false
        $version_dialog.info.Text = ""
        $version_dialog.name.Text = ""
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
        $version_dialog.edit = $true
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
        if ($version) {
            $sure = [System.Windows.Forms.MessageBox]::Show(([string]$lang.verdeletion).Replace("!ver!", $version.dname), [string]$lang.areyousure, "YesNo", "Warning")
            if ($sure -eq "Yes") {
                $version_ui.list_box.Items.Remove($version_ui.list_box.SelectedItem)
                $main_ui.version_box.Items.Remove($version)
                SaveProfiles
            }
        }
    })

    
    $version_dialog.save_btn.Add_Click({
        if ($version_dialog.edit) {
            if ([string]::IsNullOrEmpty($version_dialog.name.Text)) {
                $version_dialog.info.Text = [string]$lang.ver_empty
                return
            }
            if ([string]::IsNullOrEmpty($version_dialog.ver.SelectedItem.id)) {
                $version_dialog.info.Text = [string]$lang.ver_none
                return
            }
            $version_dialog.window.Close()
            $item = $main_ui.version_box.Items | Where-Object {$_.uuid -eq $version_ui.list_box.SelectedItem.uuid}

            $ver = [PSCustomObject]@{
                uuid=[guid]::NewGuid().ToString("N")
                name=$version_dialog.name.Text
                json=$version_dialog.ver.SelectedItem.id
                gamedir=$version_dialog.dir.Text
                memory=$version_dialog.mem.Value
                args=$version_dialog.arg.Text
                mineargs=$version_dialog.mcarg.Text
                opti=$version_dialog.opti_box.SelectedIndex
            }
            if ($main_ui.showver_box.Checked) {
                $ver | Add-Member NoteProperty "dname" "$($ver.name) ($($ver.json))"
            } else {
                $ver | Add-Member NoteProperty "dname" $ver.name
            }
            $idx = $main_ui.version_box.Items.Add($ver)
            $version_ui.list_box.Items.Add($ver)
            if ($item -eq $main_ui.version_box.SelectedItem) {
                $main_ui.version_box.SelectedIndex = $idx
            }
            $main_ui.version_box.Items.Remove($item)
            $version_ui.list_box.Items.Remove($version_ui.list_box.SelectedItem)
            SaveProfiles
        } else {
            if ([string]::IsNullOrEmpty($version_dialog.name.Text)) {
                $version_dialog.info.Text = [string]$lang.ver_empty
                return
            }
            if ([string]::IsNullOrEmpty($version_dialog.ver.SelectedItem.id)) {
                $version_dialog.info.Text = [string]$lang.ver_none
                return
            }
            $version_dialog.window.Close()
            $ver = [PSCustomObject]@{
                uuid=[guid]::NewGuid().ToString("N")
                name=$version_dialog.name.Text
                json=$version_dialog.ver.SelectedItem.id
                gamedir=$version_dialog.dir.Text
                memory=$version_dialog.mem.Value
                args=$version_dialog.arg.Text
                mineargs=$version_dialog.mcarg.Text
                opti=$version_dialog.opti_box.SelectedIndex
            }
            $ver | Add-Member NoteProperty "dname" "$($ver.name) ($($ver.json))"
            $main_ui.version_box.Items.Add($ver)
            $version_ui.list_box.Items.Add($ver)
            SaveProfiles
        }
    })

    $version_dialog.inst.Add_CheckedChanged({
        UpdateVersDialog $version_dialog.ver.SelectedItem.id
    })

    $version_dialog.dirdef_btn.Add_Click({
        $version_dialog.dir.Text = ""
    })

    $version_dialog.dir_btn.Add_Click({
        $browsefolder.SelectedPath = $version_dialog.dir.Text
        $sure = $browsefolder.ShowDialog()
        if ($sure -eq "OK") {
            $version_dialog.dir.Text = $browsefolder.SelectedPath
        }
    })

    $main_ui.window.Add_Closing({
        param($s, $e)
        if ($launching) {$e.Cancel = $true}
    })

    ##[ModificationLocationAfterLoad]##

    [void]$main_ui.window.ShowDialog()
    
    WriteJson "settings" "show_profile_ver" $main_ui.showver_box.Checked 
    WriteJson "settings" "user" $main_ui.users_list.SelectedItem.uuid
    WriteJson "settings" "fullscreen" $main_ui.fullscreen_box.Checked
    WriteJson "settings" "res_x" $main_ui.resx_box.Value
    WriteJson "settings" "res_y" $main_ui.resy_box.Value
    WriteJson "settings" "ram" $main_ui.mem_box.Value
    WriteJson "settings" "on_launch" $main_ui.launch_box.SelectedIndex
    WriteJson "settings" "gamedir" $main_ui.dir_box.Text
    WriteJson "settings" "lang" $main_ui.lang_box.SelectedItem.filename
    WriteJson "settings" "console" $main_ui.console_box.Checked
    WriteJson "settings" "version" $main_ui.version_box.SelectedItem.uuid
    WriteJson "settings" "check_assets" $main_ui.checkass_box.Checked
    WriteJson "settings" "check_hash" $main_ui.checkhash_box.Checked
    WriteJson "settings" "optimized" $other_ui.opti_box.SelectedIndex
    WriteJson "settings" "replace_auth" $other_ui.auth_box.Checked
    WriteJson "settings" "mc_args" $other_ui.mcarg_box.Text
    WriteJson "settings" "jv_args" $other_ui.jvarg_box.Text
} catch {
    warn "UI wasn't loaded: $_"
}

ConvertTo-Json $settings -Depth 100 | Set-Content "$root/settings.json"
ShowConsole $true