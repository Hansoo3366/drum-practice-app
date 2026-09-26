[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [switch]$Offline,
    [ValidateSet("Debug", "Release")]
    [string]$BuildType = "Release",
    [ValidateSet("arm64-v8a", "x86_64")]
    [string]$Abi = "arm64-v8a"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
} else {
    $ProjectRoot = (Resolve-Path $ProjectRoot).Path
}

$lockPath = Join-Path $ProjectRoot "native\lomse_bridge\dependencies.lock.yaml"
$lockText = Get-Content -LiteralPath $lockPath -Raw

function Get-PinnedDependency {
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$LockText
    )

    $pattern = "(?ms)^" + [regex]::Escape($Name) +
        ':\s*\r?\n\s+repository:\s+"([^"]+)"\s*\r?\n\s+commit:\s+"([^"]+)"'
    $match = [regex]::Match($LockText, $pattern)
    if (-not $match.Success) {
        throw "Could not read the pinned $Name dependency from $lockPath."
    }
    return [pscustomobject]@{
        Repository = $match.Groups[1].Value
        Commit = $match.Groups[2].Value
    }
}

function Invoke-Git {
    param([Parameter(Mandatory = $true)] [string[]]$Arguments)

    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Ensure-PinnedCheckout {
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$Repository,
        [Parameter(Mandatory = $true)] [string]$Commit,
        [Parameter(Mandatory = $true)] [string]$Path
    )

    $gitDirectory = Join-Path $Path ".git"
    if (-not (Test-Path -LiteralPath $gitDirectory)) {
        if ($Offline) {
            throw "$Name is not cached at $Path and -Offline was supplied."
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        Invoke-Git @("clone", "--filter=blob:none", "--no-checkout", $Repository, $Path)
    }

    $current = (& git -C $Path rev-parse HEAD 2>$null).Trim()
    if ($current -ne $Commit) {
        if ($Offline) {
            throw "$Name cache is at '$current', expected '$Commit', and -Offline was supplied."
        }
        Invoke-Git @("-C", $Path, "fetch", "--depth", "1", "origin", $Commit)
        Invoke-Git @("-C", $Path, "checkout", "--detach", $Commit)
    }

    $resolved = (& git -C $Path rev-parse HEAD).Trim()
    if ($resolved -ne $Commit) {
        throw "$Name cache resolved to '$resolved', expected '$Commit'."
    }
}

function Get-LocalProperty {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Name
    )

    $line = Get-Content -LiteralPath $Path |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -First 1
    if ($null -eq $line) {
        return ""
    }
    return ($line -replace "^$([regex]::Escape($Name))=", "").Trim().Replace("\\", "\")
}

$lomse = Get-PinnedDependency -Name "lomse" -LockText $lockText
$freetype = Get-PinnedDependency -Name "freetype" -LockText $lockText
$cacheRoot = Join-Path $ProjectRoot "native\.cache"
$lomsePath = Join-Path $cacheRoot "lomse"
$freetypePath = Join-Path $cacheRoot "freetype"

Ensure-PinnedCheckout -Name "Lomse" -Repository $lomse.Repository -Commit $lomse.Commit -Path $lomsePath
Ensure-PinnedCheckout -Name "FreeType" -Repository $freetype.Repository -Commit $freetype.Commit -Path $freetypePath

$sdkRoot = Get-LocalProperty -Path (Join-Path $ProjectRoot "android\local.properties") -Name "sdk.dir"
if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
    $sdkRoot = $env:ANDROID_SDK_ROOT
}
if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
    $sdkRoot = $env:ANDROID_HOME
}
if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
    throw "Android SDK path is not configured in android/local.properties or ANDROID_SDK_ROOT."
}

$cmakeVersion = "3.22.1"
$ndkVersion = "27.0.12077973"
$cmakeExe = Join-Path $sdkRoot "cmake\$cmakeVersion\bin\cmake.exe"
$ninjaExe = Join-Path $sdkRoot "cmake\$cmakeVersion\bin\ninja.exe"
$ndkRoot = Join-Path $sdkRoot "ndk\$ndkVersion"
$toolchainFile = Join-Path $ndkRoot "build\cmake\android.toolchain.cmake"
$runtimeTriple = switch ($Abi) {
    "arm64-v8a" { "aarch64-linux-android" }
    "x86_64" { "x86_64-linux-android" }
}
$cxxRuntime = Join-Path $ndkRoot `
    "toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\$runtimeTriple\libc++_shared.so"
foreach ($requiredPath in @($cmakeExe, $ninjaExe, $toolchainFile, $cxxRuntime)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required Android native build path does not exist: $requiredPath"
    }
}

$bridgeRoot = Join-Path $ProjectRoot "native\lomse_bridge"
$buildRoot = Join-Path $ProjectRoot "build\native\piano-lomse-android"
$buildDir = Join-Path $buildRoot "$Abi\$BuildType"
$jniRoot = Join-Path $ProjectRoot "build\native\piano-jni-libs"
$jniAbiDir = Join-Path $jniRoot $abi
New-Item -ItemType Directory -Force -Path $buildDir, $jniAbiDir | Out-Null

$configureArguments = @(
    "-S", $bridgeRoot,
    "-B", $buildDir,
    "-G", "Ninja",
    "-DCMAKE_MAKE_PROGRAM=$ninjaExe",
    "-DCMAKE_BUILD_TYPE=$BuildType",
    "-DCMAKE_TOOLCHAIN_FILE=$toolchainFile",
    "-DANDROID_ABI=$Abi",
    "-DANDROID_PLATFORM=android-26",
    "-DANDROID_STL=c++_shared",
    "-DLOMSE_SOURCE_DIR=$lomsePath",
    "-DPAGE_LOMSE_FREETYPE_SOURCE_DIR=$freetypePath",
    "-DPAGE_LOMSE_STATIC_LOMSE=ON",
    "-DPAGE_LOMSE_BUILD_SMOKE=OFF",
    "-DLOMSE_BUILD_TESTS=OFF",
    "-DLOMSE_RUN_TESTS=OFF",
    "-DLOMSE_BUILD_EXAMPLE=OFF",
    "-DLOMSE_ENABLE_PNG=OFF",
    "-DLOMSE_ENABLE_COMPRESSION=OFF",
    "-DLOMSE_ENABLE_FONTCONFIG=OFF",
    "-DLOMSE_DOWNLOAD_BRAVURA_FONT=OFF",
    "-DLOMSE_INSTALL_BRAVURA_FONT=OFF"
)

Write-Host "Configuring the piano-only Lomse bridge for $Abi..."
& $cmakeExe @configureArguments
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed with exit code $LASTEXITCODE."
}

Write-Host "Building page_lomse_bridge..."
& $cmakeExe --build $buildDir --target page_lomse_bridge --parallel
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE."
}

$bridgeBinary = Get-ChildItem -LiteralPath $buildDir -Recurse -File -Filter "libpage_lomse_bridge.so" |
    Select-Object -First 1
if ($null -eq $bridgeBinary) {
    throw "CMake completed but libpage_lomse_bridge.so was not produced."
}

$allowedLibraries = @("libpage_lomse_bridge.so", "libc++_shared.so")
$unexpectedLibraries = Get-ChildItem -LiteralPath $jniAbiDir -File -Filter "*.so" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin $allowedLibraries }
if ($unexpectedLibraries) {
    $names = ($unexpectedLibraries | ForEach-Object Name) -join ", "
    throw "The piano JNI staging directory contains unexpected native libraries: $names"
}

Copy-Item -LiteralPath $bridgeBinary.FullName `
    -Destination (Join-Path $jniAbiDir "libpage_lomse_bridge.so") -Force
Copy-Item -LiteralPath $cxxRuntime `
    -Destination (Join-Path $jniAbiDir "libc++_shared.so") -Force

$metadata = [ordered]@{
    lomse_commit = $lomse.Commit
    freetype_commit = $freetype.Commit
    abi = $Abi
    build_type = $BuildType
    output = (Join-Path $jniAbiDir "libpage_lomse_bridge.so")
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $jniRoot "metadata.json") -Encoding utf8

Write-Host "Piano JNI staging ready: $(Join-Path $jniAbiDir 'libpage_lomse_bridge.so')"
