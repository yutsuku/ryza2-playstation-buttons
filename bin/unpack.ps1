$gameRootData = Join-Path $(Get-Location) ".." | Join-Path -ChildPath "Data"
$gust_pak = "./bin/gust_tools/gust_pak.exe"
$gust_g1t = "./bin/gust_tools/gust_g1t.exe"

Get-ChildItem -path $gameRootData -Recurse -Filter "*.PAK" | ForEach-Object {
    $packageDir = Join-Path $gameRootData $_.BaseName
    $packageTarget = Join-Path $packageDir $_
    $packageTargetJson = $(Join-Path $packageDir $_.BaseName) + ".json"


    If (!(Test-Path -PathType container $packageDir))
    {
        New-Item -ItemType Directory -Path $packageDir | Out-Null
    }

    If (!(Test-Path $packageTarget -PathType Leaf))
    {
        & cmd /c mklink "$packageTarget" "..\$($_)" | Out-Null
    }

    If (!(Test-Path $packageTargetJson -PathType Leaf))
    {
        & "$gust_pak" "$packageTarget" 
    }

    Get-ChildItem -path $packageDir -Recurse -Filter "*.g1t" | ForEach-Object {
        & "$gust_g1t" $($_.FullName)
    }
}
