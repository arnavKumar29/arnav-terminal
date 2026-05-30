# arnavterminal-shell-integration (PowerShell)
# Emits OSC 7 (cwd) + OSC 133 A/B/D so the host tracks cwd and prompt boundaries.

if ($global:__arnavterminal_HOOKS_LOADED) { return }
$global:__arnavterminal_HOOKS_LOADED = $true

$esc = [char]27

try {
    $os = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).ProductName
    if ($os -match "Windows 10" -and [Environment]::OSVersion.Version.Build -ge 22000) {
        $os = $os -replace "Windows 10", "Windows 11"
    }
    $cpu = (Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -ErrorAction SilentlyContinue).ProcessorNameString.Trim()
    $gpu = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 1).ToString() + " GB"
} catch {}

$art = @(
    "          **********          ",
    "       ****************       ",
    "      ****          ****      ",
    "                    ****      ",
    "       *****************      ",
    "      ******************      ",
    "     ****           ****      ",
    "     ****           ****      ",
    "      ******************  ****",
    "       ****************    ****"
)

$colors = @("38;5;175", "38;5;140", "38;5;116", "38;5;150", "38;5;186", "38;5;175", "38;5;140", "38;5;116", "38;5;150", "38;5;186")
$sysinfo = @("", "  OS:  $os", "  CPU: $cpu", "  RAM: $ram", "  GPU: $gpu", "", "", "", "", "")

Write-Host -NoNewline "${esc}[?25l"
for ($frame = 0; $frame -lt 15; $frame++) {
    for ($i = 0; $i -lt 10; $i++) {
        $colorIdx = (9 - $i + $frame) % $colors.Count
        $col = $colors[$colorIdx]
        $line = $art[$i]
        $info = $sysinfo[$i]
        Write-Host "${esc}[${col}m${line}${esc}[0m${info}"
    }
    Start-Sleep -Milliseconds 40
    if ($frame -lt 14) {
        Write-Host -NoNewline "${esc}[10A"
    }
}
Write-Host -NoNewline "${esc}[?25h"
Write-Host ""

try {
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $global:OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}
catch {}

if (Test-Path Function:prompt) {
    Copy-Item Function:prompt Function:__arnavterminal_user_prompt -Force -ErrorAction SilentlyContinue
}

function global:__arnavterminal_urlencode {
    param([string]$s)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
    $sb = [System.Text.StringBuilder]::new($bytes.Length)
    foreach ($b in $bytes) {
        if (($b -ge 0x30 -and $b -le 0x39) -or
            ($b -ge 0x41 -and $b -le 0x5A) -or
            ($b -ge 0x61 -and $b -le 0x7A) -or
            $b -eq 0x2F -or $b -eq 0x2E -or $b -eq 0x5F -or
            $b -eq 0x7E -or $b -eq 0x2D) {
            [void]$sb.Append([char]$b)
        }
        else {
            [void]$sb.AppendFormat('%{0:X2}', $b)
        }
    }
    $sb.ToString()
}

function global:prompt {
    $lec = $LASTEXITCODE
    if ($null -eq $lec) { $lec = if ($?) { 0 } else { 1 } }
    $esc = [char]27

    $oscD = "$esc]133;D;$lec$esc\"
    $oscA = "$esc]133;A$esc\"
    $oscB = "$esc]133;B$esc\"

    $loc = Get-Location
    $osc7 = ''
    if ($loc.Provider.Name -eq 'FileSystem') {
        $cwd = $loc.ProviderPath -replace '\\', '/'
        if ($cwd -match '^[A-Za-z]:') { $cwd = "/$cwd" }
        $cwdEnc = __arnavterminal_urlencode $cwd
        $hostName = [System.Environment]::MachineName
        $osc7 = "$esc]7;file://$hostName$cwdEnc$esc\"
    }

    $original = if (Test-Path Function:__arnavterminal_user_prompt) {
        try { & __arnavterminal_user_prompt } catch { "PS $((Get-Location).Path)> " }
    }
    else {
        "PS $((Get-Location).Path)> "
    }

    $global:LASTEXITCODE = $lec
    "$oscD$oscA$osc7${original}${oscB}"
}
