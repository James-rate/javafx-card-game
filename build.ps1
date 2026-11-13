param(
    [string]$JdkPath = $env:JAVA_HOME
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($JdkPath)) {
    throw 'Pass -JdkPath pointing to a JDK 8 distribution that includes JavaFX.'
}

$compilerPath = Join-Path $JdkPath 'bin\javac.exe'
$jarToolPath = Join-Path $JdkPath 'bin\jar.exe'
$javaFxPath = Join-Path $JdkPath 'jre\lib\ext\jfxrt.jar'
foreach ($requiredPath in @($compilerPath, $jarToolPath, $javaFxPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw 'This build script requires a JDK 8 distribution that includes JavaFX.'
    }
}

$sourceRoot = Join-Path $projectRoot 'src'
$buildRoot = Join-Path $projectRoot 'build'
$classesRoot = Join-Path $buildRoot 'classes'
$sourceListPath = Join-Path $buildRoot 'sources.txt'
$archivePath = Join-Path $buildRoot 'javafx-card-game.jar'
New-Item -ItemType Directory -Path $classesRoot -Force | Out-Null

$javaFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.java' | Sort-Object FullName)
if ($javaFiles.Count -eq 0) {
    throw 'No Java sources were found.'
}
$sourceArguments = @($javaFiles | ForEach-Object { '"' + $_.FullName.Replace('\', '/') + '"' })
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($sourceListPath, [string[]]$sourceArguments, $utf8WithoutBom)

& $compilerPath -encoding UTF-8 -d $classesRoot ('@' + $sourceListPath)
if ($LASTEXITCODE -ne 0) {
    throw 'Java compilation failed.'
}

Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Where-Object {
    $_.Extension.ToLowerInvariant() -in @('.fxml', '.css', '.png')
} | ForEach-Object {
    $relativePath = $_.FullName.Substring($sourceRoot.Length + 1)
    $destinationPath = Join-Path $classesRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path $destinationPath -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
}

& $jarToolPath cfe $archivePath App -C $classesRoot .
if ($LASTEXITCODE -ne 0) {
    throw 'JAR packaging failed.'
}

Write-Output "Built $archivePath from $($javaFiles.Count) Java source files."
