Add-Type -AssemblyName System.Windows.Forms
#Enable DPI awareness
$code = @"
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
"@
$Win32Helpers = Add-Type -MemberDefinition $code -Name "Win32Helpers" -PassThru
$null = $Win32Helpers::SetProcessDPIAware()

$InterfaceName = "Беспроводная сеть 2"
$IPv4_Primary = "84.21.189.133"
$IPv4_Secondary = "64.188.98.242"
$IPv6_Primary = "2a12:bec4:1460:d5::2"
$IPv6_Secondary = "2a01:ecc0:2c1:2::2"
$DoHTemplate = "https://dns.malw.link/dns-query"

$iconMalw = New-Object System.Drawing.Icon ("$PSScriptRoot\okakDns.ico")
$iconAuto = New-Object System.Drawing.Icon ("$PSScriptRoot\NoDnsCat.ico")

function Set-MalwDNS {
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses ($IPv4_Primary, $IPv4_Secondary)
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ServerAddresses ($IPv6_Primary, $IPv6_Secondary)

    Set-DnsClientDohServerAddress -ServerAddress $IPv4_Primary -DohTemplate $DoHTemplate -AllowFallbackToUdp $false -AutoUpgrade $false
    Set-DnsClientDohServerAddress -ServerAddress $IPv6_Primary -DohTemplate $DoHTemplate -AllowFallbackToUdp $false -AutoUpgrade $false
    
    Update-MenuState
}

function Reset-ToAutoDNS {
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceName -ResetServerAddresses
    Update-MenuState
}

function Open-NetworkSettings {
    Start-Process "ms-settings:network-wifi"
}

function Update-MenuState {
    $ipv4Settings = Get-DnsClientServerAddress -InterfaceAlias $InterfaceName -AddressFamily IPv4
    
    if ($ipv4Settings -and ($ipv4Settings.ServerAddresses -contains $IPv4_Primary)) {
        $SetMalwItem.Checked = $true
        $ResetItem.Checked = $false
        $notifyIcon.Icon = $iconMalw
    }
    else {
        $SetMalwItem.Checked = $false
        $ResetItem.Checked = $true
        $notifyIcon.Icon = $iconAuto
    }
}

$ApplicationContext = New-Object System.Windows.Forms.ApplicationContext

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Text = "Переключатель DNS"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$SetMalwItem = New-Object System.Windows.Forms.ToolStripMenuItem("Установить dns.malw.link")
$ResetItem = New-Object System.Windows.Forms.ToolStripMenuItem("Сбросить на Авто")
$Separator = New-Object System.Windows.Forms.ToolStripSeparator
$SettingsItem = New-Object System.Windows.Forms.ToolStripMenuItem("Открыть настройки Wi-Fi")
$ExitItem = New-Object System.Windows.Forms.ToolStripMenuItem("Выход")

$SetMalwItem.add_Click({ Set-MalwDNS })
$ResetItem.add_Click({ Reset-ToAutoDNS })
$SettingsItem.add_Click({ Open-NetworkSettings })
$ExitItem.add_Click({
    $notifyIcon.Dispose()
    $ApplicationContext.ExitThread()
})

$contextMenu.Items.AddRange(@($SetMalwItem, $ResetItem, $Separator, $SettingsItem, $ExitItem))
$notifyIcon.ContextMenuStrip = $contextMenu
$contextMenu.add_Opening({ Update-MenuState })

Update-MenuState

[System.Windows.Forms.Application]::Run($ApplicationContext)