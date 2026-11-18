# Builds Fireplace.apk (the sideloaded phone app) without Android Studio or Gradle.
# Run from PowerShell:   .\app\build.ps1
# Needs: Java in C:\Android\jdk and the Android SDK in C:\Android\sdk
# (build-tools and one platform). The signing key lives in private\ and is
# never uploaded. Every later version MUST be signed with that same key, or
# phones will refuse to update the app.
param(
    # Raise both for every new build, or phones won't install it over the old one
    [int]$VersionCode = 2,
    [string]$VersionName = "1.1"
)
$ErrorActionPreference = 'Stop'

$Jdk = "C:\Android\jdk"
$Sdk = "C:\Android\sdk"
$App = $PSScriptRoot
$Root = Split-Path $App -Parent
$Out = Join-Path $App "build"
$KeyStore = Join-Path $Root "private\fireplace-app.keystore"
$KeyPass = Join-Path $Root "private\fireplace-app.keystore.pass"

$env:JAVA_HOME = $Jdk
$env:Path = "$Jdk\bin;$env:Path"

$bt = Get-ChildItem "$Sdk\build-tools" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$plat = Get-ChildItem "$Sdk\platforms" -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $bt -or -not $plat) { throw "Android build-tools or platform missing in $Sdk" }
$AndroidJar = Join-Path $plat.FullName "android.jar"
"Using build-tools $($bt.Name), $($plat.Name)"

function Invoke-Step([string]$What, [scriptblock]$Do) {
    "== $What"
    & $Do
    if ($LASTEXITCODE -ne 0) { throw "$What failed (exit $LASTEXITCODE)" }
}

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force "$Out\gen", "$Out\classes", "$Out\dex" | Out-Null

Invoke-Step "Compile resources" {
    & "$($bt.FullName)\aapt2.exe" compile --dir "$App\res" -o "$Out\res.zip"
}
Invoke-Step "Link resources" {
    & "$($bt.FullName)\aapt2.exe" link -o "$Out\unsigned.apk" -I $AndroidJar `
        --manifest "$App\AndroidManifest.xml" --java "$Out\gen" `
        --min-sdk-version 26 --target-sdk-version 34 `
        --version-code $VersionCode --version-name $VersionName "$Out\res.zip"
}
$sources = @(Get-ChildItem "$App\src", "$Out\gen" -Recurse -Filter *.java | ForEach-Object { $_.FullName })
Invoke-Step "Compile Java" {
    & "$Jdk\bin\javac.exe" --release 11 -Xlint:-options -classpath $AndroidJar -d "$Out\classes" $sources
}
$classes = @(Get-ChildItem "$Out\classes" -Recurse -Filter *.class | ForEach-Object { $_.FullName })
Invoke-Step "Convert to dex" {
    & "$($bt.FullName)\d8.bat" --lib $AndroidJar --min-api 26 --release --output "$Out\dex" $classes
}
Invoke-Step "Add code to the apk" {
    # append classes.dex without touching the entries aapt2 wrote
    & python -c "import sys, zipfile; z = zipfile.ZipFile(sys.argv[1], 'a', zipfile.ZIP_DEFLATED); z.write(sys.argv[2], 'classes.dex'); z.close()" "$Out\unsigned.apk" "$Out\dex\classes.dex"
}
Invoke-Step "Align" {
    & "$($bt.FullName)\zipalign.exe" -f -p 4 "$Out\unsigned.apk" "$Out\aligned.apk"
}

if (-not (Test-Path $KeyStore)) {
    "== Making the signing key (first build only)"
    New-Item -ItemType Directory -Force (Split-Path $KeyStore) | Out-Null
    $bytes = New-Object byte[] 24
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [IO.File]::WriteAllText($KeyPass, [Convert]::ToBase64String($bytes).Replace('/', 'x').Replace('+', 'y'))
    & "$Jdk\bin\keytool.exe" -genkeypair -keystore $KeyStore -storepass:file $KeyPass -keypass:file $KeyPass `
        -alias fireplace -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Fireplace Remote"
    if ($LASTEXITCODE -ne 0) { throw "keytool failed" }
}
Invoke-Step "Sign" {
    & "$($bt.FullName)\apksigner.bat" sign --ks $KeyStore --ks-key-alias fireplace `
        --ks-pass "file:$KeyPass" --out "$Out\Fireplace.apk" "$Out\aligned.apk"
}
Invoke-Step "Verify" {
    & "$($bt.FullName)\apksigner.bat" verify --verbose "$Out\Fireplace.apk"
}
"Done: $Out\Fireplace.apk  ($([math]::Round((Get-Item "$Out\Fireplace.apk").Length / 1KB)) KB)"
