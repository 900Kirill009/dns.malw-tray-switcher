Add-Type -AssemblyName System.Windows.Forms
#Enable DPI awareness
$code = @"
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
"@
$Win32Helpers = Add-Type -MemberDefinition $code -Name "Win32Helpers" -PassThru
$null = $Win32Helpers::SetProcessDPIAware()

$InterfaceName = "Беспроводная сеть 2"

# --- CONFIG MALW.LINK ---
$Malw_IPv4_Primary = "84.21.189.133"
$Malw_IPv4_Secondary = "64.188.98.242"
$Malw_IPv6_Primary = "2a12:bec4:1460:d5::2"
$Malw_IPv6_Secondary = "2a01:ecc0:2c1:2::2"
$Malw_DoHTemplate = "https://dns.malw.link/dns-query"

# --- CONFIG GEOHIDE.RU ---
$Geo_IPv4_Primary = "95.182.120.241"
$Geo_IPv4_Secondary = "185.87.51.182"
$Geo_IPv6_Primary = "2a0c:9300:0:54::1"
$Geo_IPv6_Secondary = $Malw_IPv6_Secondary 
$Geo_DoHTemplate = "https://dns.geohide.ru:444/dns-query"
$Geo_StatusUrl = "https://status.dns.geohide.ru/ru"

# --- ICONS ---
$iconMalw = New-Object System.Drawing.Icon ("$PSScriptRoot\okakDns.ico")
$iconGeo  = New-Object System.Drawing.Icon ("$PSScriptRoot\ghDns.ico")
$iconAuto = New-Object System.Drawing.Icon ("$PSScriptRoot\NoDnsCat.ico")

# --- FUNCTIONS ---

function Set-MalwDNS {
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses ($Malw_IPv4_Primary, $Malw_IPv4_Secondary)
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses ($Malw_IPv6_Primary, $Malw_IPv6_Secondary)
    Set-DnsClientDohServerAddress -ServerAddress $Malw_IPv4_Primary -DohTemplate $Malw_DoHTemplate -AllowFallbackToUdp $false -AutoUpgrade $false
    Set-DnsClientDohServerAddress -ServerAddress $Malw_IPv6_Primary -DohTemplate $Malw_DoHTemplate -AllowFallbackToUdp $false -AutoUpgrade $false
    Update-MenuState
}

function Set-GeoDNS {
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses ($Geo_IPv4_Primary, $Geo_IPv4_Secondary)
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses ($Geo_IPv6_Primary, $Geo_IPv6_Secondary)
    Set-DnsClientDohServerAddress -ServerAddress $Geo_IPv4_Primary -DohTemplate $Geo_DoHTemplate -AllowFallbackToUdp $false -AutoUpgrade $false
    Set-DnsClientDohServerAddress -ServerAddress $Geo_IPv6_Primary -DohTemplate $Geo_DoHTemplate -AllowFallbackToUdp $false -AutoUpgrade $false
    Update-MenuState
}

function Reset-ToAutoDNS {
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ResetServerAddresses
    Remove-DnsClientDohServerAddress -ServerAddress $Malw_IPv4_Primary -ErrorAction SilentlyContinue
    Remove-DnsClientDohServerAddress -ServerAddress $Malw_IPv6_Primary -ErrorAction SilentlyContinue
    Remove-DnsClientDohServerAddress -ServerAddress $Geo_IPv4_Primary -ErrorAction SilentlyContinue
    Remove-DnsClientDohServerAddress -ServerAddress $Geo_IPv6_Primary -ErrorAction SilentlyContinue
    Update-MenuState
}

function Open-NetworkSettings {
    Start-Process "ms-settings:network-wifi"
}

function Update-MenuState {
    $ipv4Settings = Get-DnsClientServerAddress -InterfaceAlias $InterfaceName -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    $SetMalwItem.Checked = $false
    $SetGeoItem.Checked = $false
    $ResetItem.Checked = $false

    if ($ipv4Settings -and ($ipv4Settings.ServerAddresses -contains $Malw_IPv4_Primary)) {
        $SetMalwItem.Checked = $true
        $notifyIcon.Icon = $iconMalw
    }
    elseif ($ipv4Settings -and ($ipv4Settings.ServerAddresses -contains $Geo_IPv4_Primary)) {
        $SetGeoItem.Checked = $true
        $notifyIcon.Icon = $iconGeo
    }
    else {
        $ResetItem.Checked = $true
        $notifyIcon.Icon = $iconAuto
    }
}

# --- UI SETUP ---

$ApplicationContext = New-Object System.Windows.Forms.ApplicationContext

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Text = "Переключатель DNS"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Создаем пункты меню
$SetMalwItem = New-Object System.Windows.Forms.ToolStripMenuItem("Установить dns.malw.link")

$SetGeoItem  = New-Object System.Windows.Forms.ToolStripMenuItem("Установить dns.geohide.ru")
# Добавляем пробелы в начале названия для визуального отступа (группировки)
$GeoStatusItem = New-Object System.Windows.Forms.ToolStripMenuItem("   Статус GeoHide (с WARP)")

$ResetItem   = New-Object System.Windows.Forms.ToolStripMenuItem("Сбросить на Авто")
$Separator   = New-Object System.Windows.Forms.ToolStripSeparator
$SettingsItem = New-Object System.Windows.Forms.ToolStripMenuItem("Открыть настройки Wi-Fi")
$ExitItem    = New-Object System.Windows.Forms.ToolStripMenuItem("Выход")

# Привязываем действия
$SetMalwItem.add_Click({ Set-MalwDNS })
$SetGeoItem.add_Click({ Set-GeoDNS })
# Просто открываем ссылку
$GeoStatusItem.add_Click({ Start-Process $Geo_StatusUrl })
$ResetItem.add_Click({ Reset-ToAutoDNS })
$SettingsItem.add_Click({ Open-NetworkSettings })
$ExitItem.add_Click({
    $notifyIcon.Dispose()
    $ApplicationContext.ExitThread()
})

# Формируем порядок меню
# GeoStatus идет сразу после установки Geo, создавая логическую группу
$contextMenu.Items.AddRange(@($ResetItem, $SetMalwItem, $SetGeoItem, $GeoStatusItem, $Separator, $SettingsItem, $ExitItem))

$notifyIcon.ContextMenuStrip = $contextMenu
$contextMenu.add_Opening({ Update-MenuState })

Update-MenuState

[System.Windows.Forms.Application]::Run($ApplicationContext)