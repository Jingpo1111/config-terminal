# PowerShell Profile for JINGPO (fast, PS 5.1 + 7)
$global:__profSw = [Diagnostics.Stopwatch]::StartNew()
$MaximumHistoryCount = 4096
$env:EDITOR = "code"
$ProgressPreference = 'SilentlyContinue'   # progress bars slow down unzip/downloads a lot
$utf8 = New-Object Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8          # makes Nerd Font icons render correctly
[Console]::InputEncoding = $utf8

# --- Re-add tool folders to PATH for this session (survives PATH damage) ---
foreach ($d in @(
    "$env:LOCALAPPDATA\Programs\oh-my-posh\bin",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
    "$env:LOCALAPPDATA\Microsoft\WindowsApps",
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin",
    "$env:USERPROFILE\.local\bin",
    "$env:APPDATA\npm"
)) {
    if ((Test-Path $d) -and (($env:Path -split ';') -notcontains $d)) { $env:Path += ";$d" }
}

# --- oh-my-posh: pill-style theme (embedded) + cached init ---
# Needs a Nerd Font in your terminal (e.g. "JetBrainsMono Nerd Font") so the icons/rounded ends show.
$themeJson = @'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 3,
  "final_space": true,
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        {
          "type": "text",
          "style": "diamond",
          "leading_diamond": "\ue0b6",
          "trailing_diamond": "\ue0b0",
          "foreground": "#1e1e2e",
          "background": "#c792ea",
          "template": " \uf007 Jingpo "
        },
        {
          "type": "path",
          "style": "powerline",
          "powerline_symbol": "\ue0b0",
          "foreground": "#1e1e2e",
          "background": "#ff4f9a",
          "template": " \uf07b {{ .Path }} ",
          "properties": {
            "style": "folder"
          }
        },
        {
          "type": "executiontime",
          "style": "powerline",
          "powerline_symbol": "\ue0b0",
          "foreground": "#ffffff",
          "background": "#4a4d5e",
          "template": " \uf252 {{ .FormattedMs }} ",
          "properties": {
            "threshold": 0,
            "style": "austin",
            "always_enabled": true
          }
        },
        {
          "type": "status",
          "style": "diamond",
          "trailing_diamond": "\ue0b4",
          "foreground": "#1e1e2e",
          "background": "#2e9599",
          "background_templates": [
            "{{ if gt .Code 0 }}#e5484d{{ end }}"
          ],
          "template": " \uf120 ",
          "properties": {
            "always_enabled": true
          }
        }
      ]
    }
  ]
}
'@
$theme = "$env:LOCALAPPDATA\jingpo.omp.json"
# Write the theme (UTF-8 without BOM) only when it is missing or changed
if (!(Test-Path $theme) -or ([IO.File]::ReadAllText($theme).Trim() -ne $themeJson.Trim())) {
    [IO.File]::WriteAllText($theme, $themeJson, $utf8)
}
$cache = "$env:LOCALAPPDATA\omp-init.ps1"
$ompErr = $null   # shown after the welcome screen, since Clear-Host would hide it
$omp = Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue
if (-not $omp) {
    $ompErr = "oh-my-posh was not found in PATH (install: winget install JanDeDobbeleer.OhMyPosh)"
}
else {
    # Rebuild the cached init when the theme OR oh-my-posh itself is newer than the cache
    $stale = !(Test-Path $cache) -or
             ((Get-Item $theme).LastWriteTime -gt (Get-Item $cache).LastWriteTime) -or
             ((Get-Item $omp.Source).LastWriteTime -gt (Get-Item $cache).LastWriteTime)
    if ($stale) {
        $ompOut = & oh-my-posh init pwsh --config $theme --print 2>&1
        if ($LASTEXITCODE -eq 0 -and $ompOut) { $ompOut | Set-Content $cache -Encoding UTF8 }
        else {
            $ompErr = "oh-my-posh init failed: " + (($ompOut | Out-String).Trim())
            Remove-Item $cache -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path $cache) { . $cache }
}

# --- Lazy-load Terminal-Icons after prompt appears ---
$null = Register-EngineEvent PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Import-Module Terminal-Icons -Global -ErrorAction SilentlyContinue
}

# --- Aliases & Functions ---
Set-Alias grep Select-String
function global:ll { Get-ChildItem -Force @Args }
function global:la { Get-ChildItem -Force -Recurse @Args }
function global:tree { param([string]$Path = ".") cmd /c tree /f /a "$Path" }
function global:mkcd { param([string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null; Set-Location $Path }
function global:up { param([int]$Count = 1) for ($i = 0; $i -lt $Count; $i++) { Set-Location .. } }
function global:reload { . $PROFILE }
function global:ptime { "Profile loaded in $global:ProfileMs ms" }

# --- Slow details: only when you type 'specs' ---
function global:specs {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
    Write-Host "`n --- Detailed Specs ---" -ForegroundColor Cyan
    Write-Host " OS     : $($os.Caption)"
    Write-Host " CPU    : $($cpu.Name)"
    Write-Host " GPU    : $(($gpu -join ', '))"
    Write-Host " Uptime : $((New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)).ToString('d\d\ h\h\ m\m'))"
    Write-Host "`n --- Storage ---" -ForegroundColor Cyan
    [IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
        Write-Host (" {0} : {1:N2} GB free of {2:N2} GB" -f $_.Name, ($_.AvailableFreeSpace / 1GB), ($_.TotalSize / 1GB))
    }
    Write-Host ""
}

# --- Fast welcome (no CIM) ---
Clear-Host
Write-Host @'

        ____  ____  _____   ______         _____         _____           _____    
       |    ||    ||\    \ |\     \    ___|\    \    ___|\    \     ____|\    \   
       |    ||    | \\    \| \     \  /    /\    \  |    |\    \   /     /\    \  
       |    ||    |  \|    \  \     ||    |  |____| |    | |    | /     /  \    \ 
 ____  |    ||    |   |     \  |    ||    |    ____ |    |/____/||     |    |    |
|    | |    ||    |   |      \ |    ||    |   |    ||    ||    |||     |    |    |
|    | |    ||    |   |    |\ \|    ||    |   |_,  ||    ||____|/|\     \  /    /|
|\____\|____||____|   |____||\_____/||\ ___\___/  /||____|       | \_____\/____/ |
| |    |    ||    |   |    |/ \|   ||| |   /____ / ||    |        \ |    ||    | /
 \|____|____||____|   |____|   |___|/ \|___|    | / |____|         \|____||____|/ 
    \(    )/    \(       \(       )/     \( |____|/    \(               \(    )/    
     '    '      '        '       '       '   )/        '                '    '     
                                              '                                   
'@ -ForegroundColor Cyan

# CPU name cached (queried once)
$cf = "$env:LOCALAPPDATA\cpu.txt"
if (!(Test-Path $cf)) { (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim() | Set-Content $cf }
Write-Host " [CPU] " -NoNewline -ForegroundColor Yellow
Write-Host ([IO.File]::ReadAllText($cf).Trim()) -ForegroundColor White

# RAM (used / total), built-in .NET, works in 5.1 and 7
Add-Type -AssemblyName Microsoft.VisualBasic
$ci = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
$total = $ci.TotalPhysicalMemory / 1GB
$used = ($ci.TotalPhysicalMemory - $ci.AvailablePhysicalMemory) / 1GB
Write-Host " [RAM] " -NoNewline -ForegroundColor Yellow
Write-Host ("{0:N1} GB / {1:N1} GB used" -f $used, $total) -ForegroundColor White

# Disks
Write-Host " [DISK] " -NoNewline -ForegroundColor Yellow
foreach ($d in [IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -eq 'Fixed' }) {
    $pct = [int](100 * (1 - $d.AvailableFreeSpace / $d.TotalSize))
    $color = if ($pct -gt 90) { 'Red' } elseif ($pct -gt 70) { 'Yellow' } else { 'Green' }
    Write-Host ("{0}: ({1}%) " -f $d.Name[0], $pct) -NoNewline -ForegroundColor $color
}
Write-Host "`n --------------------------------------" -ForegroundColor DarkGray
Write-Host " Type 'specs' for more info | 'll' for files`n" -ForegroundColor DarkGray
if ($ompErr) { Write-Host " [!] $ompErr`n" -ForegroundColor Red }

# Folder suggestions: one folder per line for cd / Set-Location / pushd
$folderCompleter = {
    param($cmd, $param, $word)
    $w = "$word".Trim('"', "'")
    $width = [Console]::WindowWidth - 2

    $leaf = if ($w -match '[\\/]$') { '' } else { Split-Path $w -Leaf }
    $prefix = $w.Substring(0, $w.Length - $leaf.Length)
    $base = if ($prefix) { $prefix } else { '.' }

    $pattern = [WildcardPattern]::Escape($leaf) + '*'
    Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like $pattern } |
    ForEach-Object {
        $text = "$prefix$($_.Name)\"
        if ($text -match '[\s\[\]\(\)\$&;,]') { $text = "'$text'" }
        [System.Management.Automation.CompletionResult]::new(
            $text, $_.Name.PadRight($width), 'ParameterValue', $_.FullName)
    }
}
Register-ArgumentCompleter -CommandName cd, chdir, sl, pushd, Set-Location, Push-Location `
    -ParameterName Path -ScriptBlock $folderCompleter


# ===== Direct =====
$script:DirectFile = "$HOME\.direct-map.json"

function Save-DirectMap {
    ConvertTo-Json -InputObject @($script:DirectMap) -Depth 3 |
    Set-Content $script:DirectFile -Encoding UTF8
}

# Safe load: rebuilds every entry cleanly
$script:DirectMap = @()
if (Test-Path $script:DirectFile) {
    $raw = [IO.File]::ReadAllText($script:DirectFile)
    if ($raw) {
        $data = $raw | ConvertFrom-Json
        foreach ($e in @($data)) {
            if ($e.Name -and $e.Path) {
                $script:DirectMap += [pscustomobject]@{
                    Name  = [string]$e.Name
                    Path  = [string]$e.Path
                    Alias = @($e.Alias)
                }
            }
        }
    }
}
else {
    Save-DirectMap
}

function Show-DirectMenu {
    $items = @($script:DirectMap)
    if (-not $items) { Write-Host "No paths saved. Use: direct-add name path" -ForegroundColor Yellow; return }

    $height = $items.Count
    1..$height | ForEach-Object { Write-Host }
    $top = [Math]::Max(0, [Console]::CursorTop - $height)
    $w = [Console]::WindowWidth - 1
    $i = 0
    [Console]::CursorVisible = $false

    function Out-Line($row, $text, $fg = 'Gray', $bg = $null) {
        [Console]::SetCursorPosition(0, $top + $row)
        $t = $text.PadRight($w).Substring(0, $w)
        if ($bg) { Write-Host $t -NoNewline -ForegroundColor $fg -BackgroundColor $bg }
        else { Write-Host $t -NoNewline -ForegroundColor $fg }
    }

    try {
        while ($true) {
            for ($n = 0; $n -lt $items.Count; $n++) {
                $txt = "{0,-10} {1}" -f $items[$n].Name, $items[$n].Path
                if ($n -eq $i) { Out-Line $n " $txt" 'Black' 'Gray' }
                else { Out-Line $n " $txt" }
            }
            $k = [Console]::ReadKey($true)
            switch ($k.Key) {
                'Tab' {
                    if ($k.Modifiers -band [ConsoleModifiers]::Shift) { $i = ($i - 1 + $items.Count) % $items.Count }
                    else { $i = ($i + 1) % $items.Count }
                }
                'DownArrow' { $i = ($i + 1) % $items.Count }
                'UpArrow' { $i = ($i - 1 + $items.Count) % $items.Count }
                'Enter' { return $items[$i] }
                'Escape' { return $null }
            }
        }
    }
    finally {
        for ($row = 0; $row -lt $height; $row++) { Out-Line $row '' }
        [Console]::SetCursorPosition(0, $top)
        [Console]::CursorVisible = $true
    }
}
function direct {
    param(
        [Parameter(Position = 0)]
        [Alias('p', 'dir')]
        [string]$Path
    )

    if (-not $Path) {
        $sel = Show-DirectMenu
        if ($sel) { Set-Location $sel.Path }
        return
    }

    $match = $script:DirectMap | Where-Object {
        $_.Name -eq $Path -or @($_.Alias) -contains $Path
    } | Select-Object -First 1

    if ($match) { Set-Location $match.Path }
    elseif (Test-Path $Path) { Set-Location $Path }
    else {
        Write-Host "Unknown alias or path: $Path" -ForegroundColor Red
        direct-list
    }
}

function direct-add {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Position = 1)][string]$Path = (Get-Location).Path,
        [string[]]$Alias = @()
    )
    $full = (Resolve-Path $Path -ErrorAction Stop).Path
    $script:DirectMap = @($script:DirectMap | Where-Object { $_.Name -ne $Name })
    $script:DirectMap += [pscustomobject]@{
        Name  = $Name
        Path  = $full
        Alias = @($Name.ToLower()) + $Alias
    }
    Save-DirectMap
    Write-Host "Added: $Name -> $full" -ForegroundColor Green
}

function direct-remove {
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    $script:DirectMap = @($script:DirectMap | Where-Object { $_.Name -ne $Name })
    Save-DirectMap
    Write-Host "Removed: $Name" -ForegroundColor Yellow
}

function direct-list {
    $script:DirectMap | Select-Object Name, Path | Format-Table -AutoSize
}

# Tab suggestions: one item per line, name -> path
$directCompleter = {
    param($cmd, $param, $word)
    $word = "$word".Trim('"', "'")
    $width = [Console]::WindowWidth - 2
    foreach ($e in $script:DirectMap) {
        if ($e.Name -like "$word*" -or (@($e.Alias) -like "$word*")) {
            $label = ("{0,-10} -> {1}" -f $e.Name, $e.Path).PadRight($width)
            [System.Management.Automation.CompletionResult]::new($e.Name, $label, 'ParameterValue', $e.Path)
        }
    }
}
Register-ArgumentCompleter -CommandName direct -ParameterName Path -ScriptBlock $directCompleter
Register-ArgumentCompleter -CommandName direct-remove -ParameterName Name -ScriptBlock $directCompleter

# Live history suggestions + smoother typing (needs PSReadLine 2.1+)
try {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction Stop
    Set-PSReadLineOption -BellStyle None -HistoryNoDuplicates -ErrorAction Stop
}
catch { }


# Tab: di/dir/dire -> direct | "direct" -> live picker | otherwise -> suggestion menu
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line -match '^\s*(di|dir|dire|direc)$') {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('direct')
    }
    elseif ($line -match '^\s*direct$') {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete()
    }
}


function unzip {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [Alias('d')][string]$Dest
    )
    $zip = (Resolve-Path $Path -ErrorAction Stop).Path
    if (-not $Dest) {
        $Dest = Join-Path (Get-Location) ([IO.Path]::GetFileNameWithoutExtension($zip))
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $Dest -Force
    Write-Host "Extracted to: $Dest" -ForegroundColor Green
}

# --- Record how long this profile took (type 'ptime' to see it) ---
$global:ProfileMs = $global:__profSw.ElapsedMilliseconds
$global:__profSw.Stop()