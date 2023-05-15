$gust_pak = "./bin/gust_tools/gust_pak.exe"
$gust_g1t = "./bin/gust_tools/gust_g1t.exe"
$tempRoot = "temp"

function Read-KeyOrTimeout ($prompt, $key){
    $seconds = 9
    $startTime = Get-Date
    $timeOut = New-TimeSpan -Seconds $seconds

    Write-Host "$prompt " -ForegroundColor Yellow

    # Basic progress bar
    [Console]::CursorLeft = 0
    [Console]::Write("[")
    [Console]::CursorLeft = $seconds + 2
    [Console]::Write("]")
    [Console]::CursorLeft = 1

    while (-not [System.Console]::KeyAvailable) {
        $currentTime = Get-Date
        Start-Sleep -s 1
        Write-Host "#" -ForegroundColor Yellow -NoNewline
        if ($currentTime -gt $startTime + $timeOut) {
            [Console]::CursorLeft = [Console]::CursorLeft + 2
            Break
        }
    }
    if ([System.Console]::KeyAvailable) {
        $response = [System.Console]::ReadKey($true).Key
    }
    else {
        $response = $key
    }
    return $response.ToString()
}

function Get-Hash()
{
    # 1.05
    $values = @{
        1.05 = @{
            executable = @{
                path = "\Atelier_Ryza_2.exe"
                hash = "2550316F1574DEEBC2020265FAF97862F608D83BC81DC808E369953E4308ED1A"
            }
            PACK00_01 = @{
                path = "\Data\PACK00_01.PAK"
                hash = "FE9686B1A7A59D6B4D592471EA39E148EF6AE5F37BBA8EE201E12BA0252FACE9"
            }
            PACK00_04_01 = @{
                path = "\Data\PACK00_04_01.PAK"
                hash = "6353A821996CAEBCAC49EE990D5EA4DFFCD9C9706519B95B06F1CCA7DAB41927"
            }
            PACK02 = @{
                path = "\Data\PACK02.PAK"
                hash = "7FDD739CCAFE79952A06519855DDB8A431F04C7BB911B7811A8C7B640333EA68"
            }
        }
    }

    foreach ($version in $values.GetEnumerator()) {
        $misses = 0

        foreach ($package in $version.Value.GetEnumerator()) {
            Write-Host ($package.Value.path) -NoNewline
            [Console]::CursorLeft = [Console]::CursorLeft + 1

            $filePath = $(Join-Path $(Get-Location) -ChildPath ".." | Join-Path -ChildPath $package.Value.path)
            $fileHash = Get-FileHash -Algorithm SHA256 -Path "$filePath" | Select-Object -ExpandProperty Hash

            if ($fileHash -ieq $package.Value.hash) {
                Write-Host "OK" -ForegroundColor Green
            } else {
                Write-Host "Mismatch" -ForegroundColor Yellow
                $misses++
            }
        }

        if (!$misses) {
            Write-Host "Will patch game against `"$($version.Name)`"" -ForegroundColor Green
            return $false
        }
    }

    return $true
}

function Prepare()
{
    If (!(Test-Path -PathType container $tempRoot))
    {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
    }
}

function Cleanup()
{
    If (Test-Path $tempRoot -PathType Container)
    {
        Start-Sleep -Milliseconds 1000
        Remove-Item -Path "$tempRoot" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Patch()
{
    (Get-ChildItem -Path $tempRoot -File -Recurse -Filter "*.PAK") | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $(Join-Path $(Get-Location) -ChildPath ".." | Join-Path -ChildPath "Data") -Force
    }
}

<#
.Description
Process PACK00_01 patch, contains button textures used in battle

prepare directories,
make symbolic link for gust_tools since it doesn't support output path.
copy patch content
find raw texture directories, patch them up
create new PAK
#>
function PACK00_01 {
    $package = "PACK00_01"
    $packageRoot = "$tempRoot\$package"
    $packagArchive = "$tempRoot\$package\$package.PAK"
    $packagJson = "$tempRoot\$package\$package.json"

    If (!(Test-Path -PathType container $packageRoot))
    {
        New-Item -ItemType Directory -Path $packageRoot | Out-Null
    }


    If (!(Test-Path $packagArchive -PathType Leaf))
    {
        & cmd /c mklink "$packagArchive" "..\..\..\Data\$package.PAK" | Out-Null
    }

    If (!(Test-Path $packagJson -PathType Leaf))
    {
        Write-Host "Extracting `"$packagArchive`"" -ForegroundColor Green
        & "$gust_pak" "$(Join-Path $(Get-Location) $packagArchive)" | Out-Null
    }

    $source = "src\$package"
    $destination = "temp\$package"

    # unpack only necessary files
    (Get-ChildItem -Path $source -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
        $textureFileArchive = "$_".Replace($source, $destination) + ".g1t"

        If (Test-Path $textureFileArchive -PathType Leaf)
        {
            Write-Host "Extracting `"$textureFileArchive`"" -ForegroundColor Green
            & "$gust_g1t" "$textureFileArchive"
            Remove-Item -Path "$textureFileArchive" -Force
        }
    }

    # overwrite with new files
    Write-Host "Copying patch files from `"$source`" to `"$destination`"" -ForegroundColor Green
    Copy-Item -Path $($source + "\*") -Destination $destination -Recurse -force

    # pack it back
    (Get-ChildItem -Path $destination -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
        Write-Host "Packing up `"$_`"" -ForegroundColor Green
        & "$gust_g1t" "$_"
    }

    Write-Host "Packing up `"$packagJson`"" -ForegroundColor Green
    & "$gust_pak" "$(Join-Path $(Get-Location) $packagJson)" | Out-Null
}


<#
.Description
Process PACK00_04_01 patch, contains button textures (english language)

prepare directories,
make symbolic link for gust_tools since it doesn't support output path.
copy patch content
find raw texture directories, patch them up
create new PAK
#>
function PACK00_04_01 {
    $package = "PACK00_04_01"
    $packageRoot = "$tempRoot\$package"
    $packagArchive = "$tempRoot\$package\$package.PAK"
    $packagJson = "$tempRoot\$package\$package.json"

    If (!(Test-Path -PathType container $packageRoot))
    {
        New-Item -ItemType Directory -Path $packageRoot | Out-Null
    }


    If (!(Test-Path $packagArchive -PathType Leaf))
    {
        & cmd /c mklink "$packagArchive" "..\..\..\Data\$package.PAK" | Out-Null
    }

    If (!(Test-Path $packagJson -PathType Leaf))
    {
        Write-Host "Extracting `"$packagArchive`"" -ForegroundColor Green
        & "$gust_pak" "$(Join-Path $(Get-Location) $packagArchive)" | Out-Null
    }

    $source = "src\$package"
    $destination = "temp\$package"

    # unpack only necessary files
    (Get-ChildItem -Path $source -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
        $textureFileArchive = "$_".Replace($source, $destination) + ".g1t"

        If (Test-Path $textureFileArchive -PathType Leaf)
        {
            Write-Host "Extracting `"$textureFileArchive`"" -ForegroundColor Green
            & "$gust_g1t" "$textureFileArchive"
            Remove-Item -Path "$textureFileArchive" -Force
        }
    }

    # overwrite with new files
    Write-Host "Copying patch files from `"$source`" to `"$destination`"" -ForegroundColor Green
    Copy-Item -Path $($source + "\*") -Destination $destination -Recurse -force

    # pack it back
    (Get-ChildItem -Path $destination -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
        Write-Host "Packing up `"$_`"" -ForegroundColor Green
        & "$gust_g1t" "$_"
    }

    Write-Host "Packing up `"$packagJson`"" -ForegroundColor Green
    & "$gust_pak" "$(Join-Path $(Get-Location) $packagJson)" | Out-Null
}

<#
.Description
Process PACK02 patch, contains button color animation used in battle

prepare directories,
make symbolic link for gust_tools since it doesn't support output path.
copy patch content
create new PAK
#>
function PACK02 {
    $package = "PACK02"
    $packageRoot = "$tempRoot\$package"
    $packagArchive = "$tempRoot\$package\$package.PAK"
    $packagJson = "$tempRoot\$package\$package.json"

    If (!(Test-Path -PathType container $packageRoot))
    {
        New-Item -ItemType Directory -Path $packageRoot | Out-Null
    }


    If (!(Test-Path $packagArchive -PathType Leaf))
    {
        & cmd /c mklink "$packagArchive" "..\..\..\Data\$package.PAK" | Out-Null
    }

    If (!(Test-Path $packagJson -PathType Leaf))
    {
        Write-Host "Extracting `"$packagArchive`"" -ForegroundColor Green
        & "$gust_pak" "$(Join-Path $(Get-Location) $packagArchive)" | Out-Null
    }

    $source = "src\$package"
    $destination = "temp\$package"

    # # unpack only necessary files
    # (Get-ChildItem -Path $source -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
    #     $textureFileArchive = "$_".Replace($source, $destination) + ".g1t"

    #     If (Test-Path $textureFileArchive -PathType Leaf)
    #     {
    #         Write-Host "Extracting `"$textureFileArchive`"" -ForegroundColor Green
    #         & "$gust_g1t" "$textureFileArchive"
    #         Remove-Item -Path "$textureFileArchive" -Force
    #     }
    # }

    # overwrite with new files
    Write-Host "Copying patch files from `"$source`" to `"$destination`"" -ForegroundColor Green
    Copy-Item -Path $($source + "\*") -Destination $destination -Recurse -force

    # # pack it back
    # (Get-ChildItem -Path $destination -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
    #     Write-Host "Packing up `"$_`"" -ForegroundColor Green
    #     & "$gust_g1t" "$_"
    # }

    Write-Host "Packing up `"$packagJson`"" -ForegroundColor Green
    & "$gust_pak" "$(Join-Path $(Get-Location) $packagJson)" | Out-Null
}

#
# Main script entry point
#
try {
    
    if (Get-Hash) {
        $result = Read-KeyOrTimeout "The patch was not tested with your game version. Continue installation? [Y/n] (default=n)" "n"
        if ($result -eq 'N') {
            throw "Game version mismatch."
        }
        else {
            throw "Please enter valid input key."
        }
    }

    Prepare
    PACK00_01
    PACK00_04_01
    PACK02
    Install-Patch
    Cleanup

    Write-Host "Operation completed" -ForegroundColor Magenta
}
catch [System.Exception] {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
