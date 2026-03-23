# ==============================================================
#  MQTT MANAGER v2 - WINDOWS MQTTwinMon |  Mosquitto Local Broker
#  Opciones: Info IP, Estado broker, Suscribir, Publicar, Dashboard
# ==============================================================

$BROKER_IP   = "localhost"
$BROKER_PORT = "1883"
$WS_PORT     = "9001"
$MQ_DIR      = "C:\Program Files\mosquitto"
$MQ_SUB      = "$MQ_DIR\mosquitto_sub.exe"
$MQ_PUB      = "$MQ_DIR\mosquitto_pub.exe"
$DASH_FILE   = "$env:TEMP\mqtt_dash_v2.html"

function CL($text, $color) {
    if (-not $color) { $color = "White" }
    Write-Host $text -ForegroundColor $color
}
function CW($text, $color) {
    if (-not $color) { $color = "White" }
    Write-Host $text -ForegroundColor $color -NoNewline
}
function Sep { CL "  ------------------------------------------" "DarkGray" }
function Pause { Read-Host "  Enter para continuar" }

function Check-Mosquitto {
    if (-not (Test-Path $MQ_SUB) -or -not (Test-Path $MQ_PUB)) {
        CL ""
        CL "  [ERROR] Binarios de Mosquitto no encontrados en:" "Red"
        CL "          $MQ_DIR" "Yellow"
        CL "  Instala Mosquitto desde https://mosquitto.org/download/" "Red"
        CL ""
        Pause
        exit 1
    }
}

function Show-Menu {
    Clear-Host
    $svc = Get-Service mosquitto -ErrorAction SilentlyContinue
    $status = if ($svc -and $svc.Status -eq "Running") { "RUNNING" } else { "DETENIDO" }
    $statusColor = if ($status -eq "RUNNING") { "Green" } else { "Red" }

    CL ""
    CL "  +============================================+" "Cyan"
    CL "  |                 MQTTwinMon                 |" "Cyan"
    CL "  |              PIXELBITS Studio              |" "Cyan"
    CL "  +============================================+" "Cyan"
    CW "  |  Broker : $BROKER_IP`:$BROKER_PORT   Estado: " "White"
    CW "$status" $statusColor
    CL "         |" "White"
    CL "  +============================================+" "Cyan"
    CL "  |  [1]  Suscribirse a Topic                  |" "White"
    CL "  |  [2]  Enviar Mensaje                       |" "White"
    CL "  |  [3]  Info de Red (IP y puertos)           |" "White"
    CL "  |  [4]  Estado y Monitoreo del Broker        |" "White"
    CL "  |  [5]  Gestionar Servicio Mosquitto         |" "White"
    CL "  |  [6]  Ver Log del Broker                   |" "White"
    CL "  |  [7]  Config MQTT Explorer                 |" "White"
    CL "  |  [8]  Dashboard Web                        |" "White"
    CL "  |  [0]  Salir                                |" "White"
    CL "  +============================================+" "Cyan"
    CL ""
}

function Subscribe-Topic {
    CL ""
    CL "  [ SUSCRIPCION A TOPIC ]" "Yellow"
    CL ""
    $topic = Read-Host "  Topic (ej: casa/sensor/# )"
    if ([string]::IsNullOrWhiteSpace($topic)) {
        CL "  Topic vacio. Cancelando." "Red"
        Start-Sleep -Seconds 1
        return
    }
    $qos = Read-Host "  QoS [0/1/2] (Enter = 0)"
    if ($qos -notin @("0","1","2")) { $qos = "0" }

    CL ""
    CL "  Suscrito a : $topic  (QoS $qos)" "Green"
    CL "  Broker     : $BROKER_IP`:$BROKER_PORT" "Cyan"
    CL "  Ctrl+C para volver al menu." "White"
    Sep
    CL ""
    try {
        & $MQ_SUB -h $BROKER_IP -p $BROKER_PORT -t $topic -q $qos -v 2>&1 | ForEach-Object {
            $ts = Get-Date -Format "HH:mm:ss"
            CL "  [$ts]  $_" "Green"
        }
    } catch {
        CL "  Suscripcion interrumpida." "Yellow"
    }
    CL ""
    Pause
}

function Publish-Message {
    CL ""
    CL "  [ ENVIAR MENSAJE ]" "Yellow"
    CL ""
    $topic   = Read-Host "  Topic (ej: casa/led/cmd)"
    $message = Read-Host "  Mensaje / Payload"
    if ([string]::IsNullOrWhiteSpace($topic) -or [string]::IsNullOrWhiteSpace($message)) {
        CL "  Datos incompletos. Cancelando." "Red"
        Start-Sleep -Seconds 1
        return
    }
    $qos = Read-Host "  QoS [0/1/2] (Enter = 0)"
    if ($qos -notin @("0","1","2")) { $qos = "0" }
    $retain = Read-Host "  Retain? [s/N]"
    $retainFlag = if ($retain -eq "s" -or $retain -eq "S") { "-r" } else { "" }

    try {
        if ($retainFlag) {
            & $MQ_PUB -h $BROKER_IP -p $BROKER_PORT -t $topic -m $message -q $qos -r 2>&1 | Out-Null
        } else {
            & $MQ_PUB -h $BROKER_IP -p $BROKER_PORT -t $topic -m $message -q $qos 2>&1 | Out-Null
        }
        CL ""
        CL "  OK  Mensaje enviado." "Green"
        CL "  Topic   : $topic" "Cyan"
        CL "  Payload : $message" "White"
        CL "  QoS     : $qos   Retain: $(if($retainFlag){'SI'}else{'NO'})" "DarkGray"
    } catch {
        CL "  Error al publicar: $_" "Red"
    }
    CL ""
    Pause
}

function Get-NetworkInfo {
    CL ""
    CL "  [ INFO DE RED Y CONEXION ]" "Yellow"
    Sep
    CL ""

    # IP local de todas las interfaces activas
    $adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown"
    }
    CL "  IPs locales disponibles:" "Cyan"
    foreach ($a in $adapters) {
        $iface = (Get-NetAdapter -InterfaceIndex $a.InterfaceIndex -ErrorAction SilentlyContinue).Name
        CL "    $($a.IPAddress)  [$iface]" "White"
    }
    CL ""

    # IP principal recomendada
    $mainIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown"
    } | Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress

    if ($mainIP) {
        CL "  IP recomendada para MQTT Explorer / ESP32:" "Green"
        CL "    $mainIP" "Yellow"
    }

    CL ""
    CL "  Puertos Mosquitto:" "Cyan"
    CL "    MQTT      : $BROKER_IP`:$BROKER_PORT  (TCP)" "White"
    CL "    WebSocket : $BROKER_IP`:$WS_PORT   (WS)" "White"
    CL ""

    # Verificar si los puertos estan escuchando
    $mqtt_listen = Get-NetTCPConnection -LocalPort 1883 -State Listen -ErrorAction SilentlyContinue
    $ws_listen   = Get-NetTCPConnection -LocalPort 9001 -State Listen -ErrorAction SilentlyContinue

    CW "  Puerto 1883 : " "White"
    if ($mqtt_listen) { CL "ESCUCHANDO" "Green" } else { CL "NO activo" "Red" }
    CW "  Puerto 9001 : " "White"
    if ($ws_listen) { CL "ESCUCHANDO" "Green" } else { CL "NO activo / no configurado" "DarkGray" }

    CL ""
    # Conexiones activas al broker
    $conns = Get-NetTCPConnection -LocalPort 1883 -State Established -ErrorAction SilentlyContinue
    if ($conns) {
        CL "  Clientes conectados ahora (puerto 1883):" "Cyan"
        foreach ($c in $conns) {
            CL "    $($c.RemoteAddress):$($c.RemotePort)" "White"
        }
    } else {
        CL "  Sin clientes conectados actualmente." "DarkGray"
    }
    CL ""
    Sep
    Pause
}

function Get-BrokerStatus {
    CL ""
    CL "  [ ESTADO Y MONITOREO DEL BROKER ]" "Yellow"
    Sep
    CL ""

    # Estado del servicio
    $svc = Get-Service mosquitto -ErrorAction SilentlyContinue
    CW "  Servicio       : " "White"
    if ($svc) {
        $col = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
        CL "$($svc.Status)  (Inicio: $($svc.StartType))" $col
    } else {
        CL "No encontrado" "Red"
    }

    # Proceso
    $proc = Get-Process mosquitto -ErrorAction SilentlyContinue
    if ($proc) {
        CL "  PID            : $($proc.Id)" "White"
        $mem = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        CL "  Memoria RAM    : $mem MB" "White"
        $cpu = $proc.CPU
        CL "  CPU acumulado  : $([math]::Round($cpu,2)) seg" "White"
        $uptime = (Get-Date) - $proc.StartTime
        CL "  Uptime         : $([math]::Floor($uptime.TotalHours))h $($uptime.Minutes)m $($uptime.Seconds)s" "Cyan"
    } else {
        CL "  Proceso        : no encontrado" "Red"
    }

    CL ""
    CL "  Conexiones TCP:" "Cyan"
    $listen = Get-NetTCPConnection -LocalPort 1883 -ErrorAction SilentlyContinue
    $established = $listen | Where-Object { $_.State -eq "Established" }
    $listening   = $listen | Where-Object { $_.State -eq "Listen" }
    CL "    Listen      : $(if($listening){'SI'}else{'NO'})" "White"
    CL "    Establecidas: $($established.Count)" "White"

    CL ""
    CL "  Archivo de configuracion:" "Cyan"
    $conf = "$MQ_DIR\mosquitto.conf"
    if (Test-Path $conf) {
        CL "    $conf" "White"
        $lines = Get-Content $conf | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }
        CL "    Directivas activas:" "DarkGray"
        foreach ($l in $lines) { CL "      $l" "DarkGray" }
    } else {
        CL "    No encontrado o ruta diferente." "DarkGray"
    }

    CL ""
    CL "  Reglas de firewall Mosquitto:" "Cyan"
    $rules = Get-NetFirewallRule -DisplayName "*Mosquitto*" -ErrorAction SilentlyContinue
    if ($rules) {
        foreach ($r in $rules) {
            $col = if ($r.Enabled -eq "True") { "Green" } else { "Red" }
            CL "    [$($r.Direction)] $($r.DisplayName)  Enabled=$($r.Enabled)" $col
        }
    } else {
        CL "    Sin reglas encontradas." "DarkGray"
    }

    CL ""
    Sep
    Pause
}

function Manage-Service {
    CL ""
    CL "  [ GESTIONAR SERVICIO MOSQUITTO ]" "Yellow"
    Sep
    CL ""
    $svc = Get-Service mosquitto -ErrorAction SilentlyContinue
    $col = if ($svc -and $svc.Status -eq "Running") { "Green" } else { "Red" }
    CL "  Estado actual: " "White"
    CL "  $($svc.Status)" $col
    CL ""
    CL "  [1] Iniciar    [2] Detener    [3] Reiniciar" "Cyan"
    CL "  [4] Inicio automatico ON      [5] Inicio automatico OFF" "Cyan"
    CL "  [0] Volver" "DarkGray"
    CL ""
    Write-Host "  Opcion: " -NoNewline -ForegroundColor White
    $o = Read-Host
    switch ($o.Trim()) {
        "1" { Start-Service mosquitto -ErrorAction SilentlyContinue; CL "  Servicio iniciado." "Green" }
        "2" { Stop-Service mosquitto -ErrorAction SilentlyContinue;  CL "  Servicio detenido." "Yellow" }
        "3" { Restart-Service mosquitto -ErrorAction SilentlyContinue; CL "  Servicio reiniciado." "Green" }
        "4" { Set-Service mosquitto -StartupType Automatic; CL "  Inicio automatico activado." "Green" }
        "5" { Set-Service mosquitto -StartupType Manual;    CL "  Inicio automatico desactivado." "Yellow" }
        "0" { return }
    }
    Start-Sleep -Seconds 1
    Pause
}

function View-Log {
    CL ""
    CL "  [ LOG DEL BROKER ]" "Yellow"
    Sep
    CL ""
    $logPath = "$MQ_DIR\logs\mosquitto.log"
    if (-not (Test-Path $logPath)) {
        # buscar alternativas
        $alt = Get-ChildItem "$MQ_DIR\logs\" -Filter "*.log" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($alt) { $logPath = $alt.FullName }
    }
    if (Test-Path $logPath) {
        CL "  Archivo: $logPath" "Cyan"
        CL "  Ultimas 30 lineas:" "DarkGray"
        CL ""
        Get-Content $logPath -Tail 30 | ForEach-Object {
            if ($_ -match "error|Error") { CL "  $_" "Red" }
            elseif ($_ -match "warning|Warning") { CL "  $_" "Yellow" }
            elseif ($_ -match "connect|Connect") { CL "  $_" "Green" }
            else { CL "  $_" "DarkGray" }
        }
    } else {
        CL "  Log no encontrado en $logPath" "Red"
        CL "  Verifica que log_dest file este configurado en mosquitto.conf" "Yellow"
        CL ""
        CL "  Para habilitar el log agrega a mosquitto.conf:" "Cyan"
        CL "    log_dest file C:\Program Files\mosquitto\logs\mosquitto.log" "White"
        CL "    log_type all" "White"
    }
    CL ""
    Sep
    Pause
}

function Show-MQTTExplorerConfig {
    $mainIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown"
    } | Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress

    CL ""
    CL "  [ CONFIG PARA MQTT EXPLORER ]" "Yellow"
    Sep
    CL ""
    CL "  Descarga MQTT Explorer: http://mqtt-explorer.com" "Cyan"
    CL ""
    CL "  --- Conexion desde esta misma maquina ---" "White"
    CL "  Protocol : mqtt://" "White"
    CL "  Host     : localhost   o   127.0.0.1" "Green"
    CL "  Port     : 1883" "Green"
    CL "  Username : (vacio si no configuraste auth)" "DarkGray"
    CL "  Password : (vacio si no configuraste auth)" "DarkGray"
    CL "  TLS      : OFF" "DarkGray"
    CL ""
    if ($mainIP) {
        CL "  --- Conexion desde otra PC / ESP32 en la misma red ---" "White"
        CL "  Protocol : mqtt://" "White"
        CL "  Host     : $mainIP" "Yellow"
        CL "  Port     : 1883" "Yellow"
        CL "  Username : (vacio)" "DarkGray"
        CL "  Password : (vacio)" "DarkGray"
        CL "  TLS      : OFF" "DarkGray"
        CL ""
        CL "  En tu ESP32 / Arduino usa esta IP:" "Cyan"
        CL "  const char* mqtt_server = `"$mainIP`";" "White"
    }
    CL ""
    CL "  --- WebSocket (para dashboards web) ---" "White"
    CL "  Protocol : ws://" "White"
    CL "  Host     : localhost" "Green"
    CL "  Port     : 9001" "Green"
    CL "  (requiere listener WebSocket en mosquitto.conf)" "DarkGray"
    CL ""
    CL "  Para habilitar WebSocket agrega a mosquitto.conf:" "Cyan"
    CL "    listener 9001" "White"
    CL "    protocol websockets" "White"
    CL ""
    Sep
    Pause
}

function Open-Dashboard {
    $mainIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown"
    } | Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress

    if (-not $mainIP) { $mainIP = "127.0.0.1" }

    # --- Build HTML ---
    $h = [System.Collections.Generic.List[string]]::new()

    $h.Add('<!DOCTYPE html>')
    $h.Add('<html lang="es">')
    $h.Add('<head>')
    $h.Add('<meta charset="UTF-8">')
    $h.Add('<meta name="viewport" content="width=device-width,initial-scale=1">')
    $h.Add('<title>MQTTwinMon PIXELBITS Studio</title>')
    $h.Add('<script src="https://cdnjs.cloudflare.com/ajax/libs/paho-mqtt/1.0.1/mqttws31.min.js"></script>')
    $h.Add('<style>')
    $h.Add(':root{')
    $h.Add('  --bg:#f0f4f8;--surface:#ffffff;--surface2:#f8fafc;')
    $h.Add('  --border:#dde3ec;--border2:#c5cfe0;')
    $h.Add('  --accent:#0066cc;--accent-h:#004fa0;')
    $h.Add('  --accent2:#00875a;--accent2-h:#006644;')
    $h.Add('  --warn:#d97706;--danger:#dc2626;')
    $h.Add('  --text:#1a2332;--text2:#4a5568;--dim:#8899aa;')
    $h.Add('  --mono:"Courier New",monospace;--sans:"Segoe UI",system-ui,sans-serif;')
    $h.Add('  --radius:8px;--shadow:0 2px 8px rgba(0,0,0,.08);')
    $h.Add('}')
    $h.Add('[data-theme=dark]{')
    $h.Add('  --bg:#0d1117;--surface:#161b22;--surface2:#1c2230;')
    $h.Add('  --border:#2a3548;--border2:#3a4d6a;')
    $h.Add('  --accent:#58a6ff;--accent-h:#79b8ff;')
    $h.Add('  --accent2:#3fb950;--accent2-h:#56d364;')
    $h.Add('  --warn:#d29922;--danger:#f85149;')
    $h.Add('  --text:#e6edf3;--text2:#8b949e;--dim:#484f58;')
    $h.Add('}')
    $h.Add('*{box-sizing:border-box;margin:0;padding:0;}')
    $h.Add('body{background:var(--bg);color:var(--text);font-family:var(--sans);font-size:14px;min-height:100vh;}')
    $h.Add('a{color:var(--accent);}')
    $h.Add('/* TOPBAR */')
    $h.Add('.topbar{background:var(--surface);border-bottom:1px solid var(--border);padding:12px 20px;display:flex;align-items:center;gap:12px;position:sticky;top:0;z-index:100;box-shadow:var(--shadow);}')
    $h.Add('.topbar .brand{font-size:1rem;font-weight:700;letter-spacing:.5px;color:var(--accent);}')
    $h.Add('.topbar .broker-badge{font-family:var(--mono);font-size:.75rem;background:var(--surface2);border:1px solid var(--border);padding:4px 10px;border-radius:20px;color:var(--text2);}')
    $h.Add('.conn-dot{width:9px;height:9px;border-radius:50%;background:var(--danger);flex-shrink:0;transition:background .3s;}')
    $h.Add('.conn-dot.on{background:var(--accent2);}')
    $h.Add('.conn-label{font-size:.75rem;color:var(--text2);}')
    $h.Add('.topbar-right{margin-left:auto;display:flex;align-items:center;gap:10px;}')
    $h.Add('.theme-btn{background:none;border:1px solid var(--border);border-radius:6px;padding:5px 10px;cursor:pointer;color:var(--text2);font-size:.8rem;}')
    $h.Add('.theme-btn:hover{background:var(--surface2);}')
    $h.Add('/* LAYOUT */')
    $h.Add('.main{padding:20px;max-width:1200px;margin:0 auto;}')
    $h.Add('.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px;}')
    $h.Add('.grid3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;margin-bottom:16px;}')
    $h.Add('@media(max-width:900px){.grid2,.grid3{grid-template-columns:1fr;}}')
    $h.Add('/* CARDS */')
    $h.Add('.card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:18px;box-shadow:var(--shadow);}')
    $h.Add('.card-title{font-size:.7rem;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:var(--dim);margin-bottom:14px;display:flex;align-items:center;gap:6px;}')
    $h.Add('.card-title .ico{font-size:.9rem;}')
    $h.Add('/* CONN PANEL */')
    $h.Add('.conn-row{display:grid;grid-template-columns:1fr 80px 1fr 1fr auto;gap:8px;align-items:end;}')
    $h.Add('@media(max-width:700px){.conn-row{grid-template-columns:1fr;}}')
    $h.Add('/* INPUTS */')
    $h.Add('label{display:block;font-size:.72rem;color:var(--text2);margin-bottom:4px;font-weight:600;}')
    $h.Add('input,select{width:100%;background:var(--surface2);border:1px solid var(--border);color:var(--text);font-family:var(--sans);font-size:.85rem;padding:8px 10px;border-radius:6px;outline:none;transition:border-color .15s;}')
    $h.Add('input:focus,select:focus{border-color:var(--accent);}')
    $h.Add('input::placeholder{color:var(--dim);}')
    $h.Add('/* BUTTONS */')
    $h.Add('.btn{font-family:var(--sans);font-size:.82rem;font-weight:600;border:none;border-radius:6px;padding:8px 16px;cursor:pointer;transition:all .15s;white-space:nowrap;}')
    $h.Add('.btn-primary{background:var(--accent);color:#fff;}')
    $h.Add('.btn-primary:hover{background:var(--accent-h);}')
    $h.Add('.btn-success{background:var(--accent2);color:#fff;}')
    $h.Add('.btn-success:hover{background:var(--accent2-h);}')
    $h.Add('.btn-danger{background:var(--danger);color:#fff;}')
    $h.Add('.btn-outline{background:transparent;border:1px solid var(--border2);color:var(--text);}')
    $h.Add('.btn-outline:hover{background:var(--surface2);}')
    $h.Add('.btn-sm{padding:5px 10px;font-size:.75rem;}')
    $h.Add('.btn-full{width:100%;margin-top:8px;}')
    $h.Add('/* STATUS BAR */')
    $h.Add('.stat-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px;}')
    $h.Add('@media(max-width:700px){.stat-grid{grid-template-columns:1fr 1fr;}}')
    $h.Add('.stat-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:14px 16px;box-shadow:var(--shadow);}')
    $h.Add('.stat-val{font-size:1.5rem;font-weight:700;color:var(--accent);font-family:var(--mono);}')
    $h.Add('.stat-lbl{font-size:.7rem;color:var(--dim);margin-top:2px;text-transform:uppercase;letter-spacing:.5px;}')
    $h.Add('/* SUBS */')
    $h.Add('.chips{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px;}')
    $h.Add('.chip{display:flex;align-items:center;gap:5px;font-family:var(--mono);font-size:.73rem;background:rgba(0,102,204,.08);border:1px solid rgba(0,102,204,.25);color:var(--accent);padding:4px 10px;border-radius:20px;}')
    $h.Add('[data-theme=dark] .chip{background:rgba(88,166,255,.08);border-color:rgba(88,166,255,.25);}')
    $h.Add('.chip .xbtn{cursor:pointer;color:var(--danger);font-weight:700;margin-left:2px;line-height:1;}')
    $h.Add('/* LOG */')
    $h.Add('#log{height:300px;overflow-y:auto;font-family:var(--mono);font-size:.75rem;line-height:1.7;background:var(--surface2);border:1px solid var(--border);border-radius:6px;padding:10px 12px;}')
    $h.Add('#log::-webkit-scrollbar{width:4px;}')
    $h.Add('#log::-webkit-scrollbar-thumb{background:var(--border2);border-radius:2px;}')
    $h.Add('.le{padding:2px 0;border-bottom:1px solid var(--border);}')
    $h.Add('.le:last-child{border-bottom:none;}')
    $h.Add('.ts{color:var(--dim);}')
    $h.Add('.tp{color:var(--accent);font-weight:600;}')
    $h.Add('.mg{color:var(--text);}')
    $h.Add('.sy{color:var(--warn);font-style:italic;}')
    $h.Add('.pb{color:var(--accent2);font-weight:600;}')
    $h.Add('.er{color:var(--danger);}')
    $h.Add('/* NETWORK INFO */')
    $h.Add('.info-row{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--border);font-size:.83rem;}')
    $h.Add('.info-row:last-child{border-bottom:none;}')
    $h.Add('.info-key{color:var(--text2);}')
    $h.Add('.info-val{font-family:var(--mono);color:var(--text);font-weight:600;}')
    $h.Add('.copy-btn{font-size:.7rem;padding:2px 7px;margin-left:8px;}')
    $h.Add('.badge{display:inline-block;padding:2px 8px;border-radius:10px;font-size:.72rem;font-weight:700;}')
    $h.Add('.badge-ok{background:rgba(0,135,90,.12);color:var(--accent2);}')
    $h.Add('.badge-err{background:rgba(220,38,38,.1);color:var(--danger);}')
    $h.Add('.badge-warn{background:rgba(217,119,6,.1);color:var(--warn);}')
    $h.Add('/* HISTORY TABLE */')
    $h.Add('.htable{width:100%;border-collapse:collapse;font-size:.78rem;}')
    $h.Add('.htable th{text-align:left;padding:6px 8px;background:var(--surface2);color:var(--dim);font-size:.7rem;text-transform:uppercase;letter-spacing:.5px;border-bottom:2px solid var(--border);}')
    $h.Add('.htable td{padding:6px 8px;border-bottom:1px solid var(--border);font-family:var(--mono);}')
    $h.Add('.htable tr:last-child td{border-bottom:none;}')
    $h.Add('.htable tr:hover td{background:var(--surface2);}')
    $h.Add('/* NOTE */')
    $h.Add('.note{background:rgba(0,102,204,.06);border:1px solid rgba(0,102,204,.2);border-radius:6px;padding:10px 14px;font-size:.78rem;color:var(--text2);margin-top:12px;line-height:1.7;}')
    $h.Add('[data-theme=dark] .note{background:rgba(88,166,255,.06);border-color:rgba(88,166,255,.2);}')
    $h.Add('.note b{color:var(--accent);}')
    $h.Add('/* TOGGLE */')
    $h.Add('.row-btns{display:flex;gap:8px;margin-top:8px;flex-wrap:wrap;}')
    $h.Add('.section-hdr{display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;}')
    $h.Add('.log-hdr{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;}')
    $h.Add('</style>')
    $h.Add('</head>')
    $h.Add('<body>')

    # TOPBAR
    $h.Add('<div class="topbar">')
    $h.Add('  <div class="brand">MQTTwinMon</div>')
    $h.Add('  <div class="broker-badge" id="brokerBadge">localhost:1883</div>')
    $h.Add('  <div class="conn-dot" id="connDot"></div>')
    $h.Add('  <div class="conn-label" id="connLabel">Desconectado</div>')
    $h.Add('  <div class="topbar-right">')
    $h.Add('    <button class="theme-btn" onclick="toggleTheme()">Tema Oscuro</button>')
    $h.Add('  </div>')
    $h.Add('</div>')

    $h.Add('<div class="main">')

    # STAT CARDS
    $h.Add('<div class="stat-grid">')
    $h.Add('  <div class="stat-card"><div class="stat-val" id="statMsgs">0</div><div class="stat-lbl">Mensajes recibidos</div></div>')
    $h.Add('  <div class="stat-card"><div class="stat-val" id="statPub">0</div><div class="stat-lbl">Mensajes enviados</div></div>')
    $h.Add('  <div class="stat-card"><div class="stat-val" id="statSubs">0</div><div class="stat-lbl">Suscripciones activas</div></div>')
    $h.Add('  <div class="stat-card"><div class="stat-val" id="statUptime">--</div><div class="stat-lbl">Tiempo conectado</div></div>')
    $h.Add('</div>')

    # ROW 1: Conexion + Red
    $h.Add('<div class="grid2">')

    # Card Conexion
    $h.Add('<div class="card">')
    $h.Add('  <div class="card-title"><span class="ico">&#128268;</span>Conexion al Broker (WebSocket)</div>')
    $h.Add('  <div class="conn-row">')
    $h.Add('    <div><label>Host / IP</label><input id="cfgHost" value="localhost"></div>')
    $h.Add('    <div><label>Puerto WS</label><input id="cfgPort" value="9001" type="number"></div>')
    $h.Add('    <div><label>Usuario (opcional)</label><input id="cfgUser" placeholder="vacio si no aplica"></div>')
    $h.Add('    <div><label>Password (opcional)</label><input id="cfgPass" type="password" placeholder="vacio si no aplica"></div>')
    $h.Add('    <div style="padding-top:18px">')
    $h.Add('      <button class="btn btn-primary" id="connBtn" onclick="toggleConnect()">Conectar</button>')
    $h.Add('    </div>')
    $h.Add('  </div>')
    $h.Add('  <div class="note"><b>Nota:</b> El Dashboard usa WebSocket (puerto 9001). Agrega a mosquitto.conf:<br><code>listener 9001 &nbsp; protocol websockets &nbsp; allow_anonymous true</code></div>')
    $h.Add('</div>')

    # Card Red Info
    $h.Add('<div class="card">')
    $h.Add('  <div class="card-title"><span class="ico">&#127760;</span>Info de Red</div>')
    $h.Add("  <div class='info-row'><span class='info-key'>IP Local (broker)</span><span class='info-val'>$mainIP <button class='btn btn-outline btn-sm copy-btn' onclick=""copyText('$mainIP')"">Copiar</button></span></div>")
    $h.Add("  <div class='info-row'><span class='info-key'>localhost</span><span class='info-val'>127.0.0.1</span></div>")
    $h.Add("  <div class='info-row'><span class='info-key'>Puerto MQTT</span><span class='info-val'>1883 (TCP)</span></div>")
    $h.Add("  <div class='info-row'><span class='info-key'>Puerto WebSocket</span><span class='info-val'>9001 (WS)</span></div>")
    $h.Add("  <div class='info-row'><span class='info-key'>Broker</span><span class='info-val'>Mosquitto (local)</span></div>")
    $h.Add('  <div class="note"><b>MQTT Explorer:</b> Host=<b>' + $mainIP + '</b> &nbsp; Port=<b>1883</b> &nbsp; TLS=OFF</div>')
    $h.Add('</div>')
    $h.Add('</div>')

    # ROW 2: Suscribir + Publicar
    $h.Add('<div class="grid2">')

    # Card Suscribir
    $h.Add('<div class="card">')
    $h.Add('  <div class="card-title"><span class="ico">&#128225;</span>Suscribirse a Topic</div>')
    $h.Add('  <label>Topic (soporta wildcards # y +)</label>')
    $h.Add('  <input id="subTopic" placeholder="casa/sensor/# o topic/+" value="#">')
    $h.Add('  <div class="row-btns">')
    $h.Add('    <button class="btn btn-primary" onclick="addSub()">Suscribir</button>')
    $h.Add('    <button class="btn btn-outline" onclick="clearSubs()">Limpiar todas</button>')
    $h.Add('  </div>')
    $h.Add('  <div class="chips" id="subsList"></div>')
    $h.Add('</div>')

    # Card Publicar
    $h.Add('<div class="card">')
    $h.Add('  <div class="card-title"><span class="ico">&#128228;</span>Publicar Mensaje</div>')
    $h.Add('  <label>Topic</label>')
    $h.Add('  <input id="pubTopic" placeholder="casa/led/cmd" style="margin-bottom:8px">')
    $h.Add('  <label>Payload</label>')
    $h.Add('  <input id="pubMsg" placeholder="ON / OFF / {valor}" style="margin-bottom:8px">')
    $h.Add('  <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:8px">')
    $h.Add('    <div><label>QoS</label><select id="pubQos"><option value="0">0 - At most once</option><option value="1">1 - At least once</option><option value="2">2 - Exactly once</option></select></div>')
    $h.Add('    <div><label>Retain</label><select id="pubRetain"><option value="false">No</option><option value="true">Si</option></select></div>')
    $h.Add('  </div>')
    $h.Add('  <button class="btn btn-success btn-full" onclick="publish()">Publicar</button>')
    $h.Add('</div>')
    $h.Add('</div>')

    # ROW 3: Log full width
    $h.Add('<div class="card" style="margin-bottom:16px">')
    $h.Add('  <div class="log-hdr">')
    $h.Add('    <div class="card-title" style="margin-bottom:0"><span class="ico">&#128203;</span>Log de Mensajes</div>')
    $h.Add('    <div style="display:flex;gap:8px">')
    $h.Add('      <button class="btn btn-outline btn-sm" onclick="exportLog()">Exportar</button>')
    $h.Add('      <button class="btn btn-outline btn-sm" onclick="clearLog()">Limpiar</button>')
    $h.Add('    </div>')
    $h.Add('  </div>')
    $h.Add('  <div id="log"></div>')
    $h.Add('</div>')

    # ROW 4: Historial tabla
    $h.Add('<div class="card" style="margin-bottom:16px">')
    $h.Add('  <div class="section-hdr">')
    $h.Add('    <div class="card-title" style="margin-bottom:0"><span class="ico">&#128200;</span>Historial de Topics (ultimos valores)</div>')
    $h.Add('    <button class="btn btn-outline btn-sm" onclick="clearHistory()">Limpiar</button>')
    $h.Add('  </div>')
    $h.Add('  <div style="overflow-x:auto">')
    $h.Add('    <table class="htable"><thead><tr><th>Topic</th><th>Ultimo valor</th><th>Hora</th><th>Cant.</th></tr></thead>')
    $h.Add('    <tbody id="histBody"></tbody></table>')
    $h.Add('  </div>')
    $h.Add('</div>')

    $h.Add('</div>') # /main

    # SCRIPT
    $h.Add('<script>')
    $h.Add('var client=null,connected=false,subs=[],msgCount=0,pubCount=0,connStart=null;')
    $h.Add('var history={};')

    $h.Add('function ts(){return new Date().toLocaleTimeString("es-MX",{hour12:false});}')

    $h.Add('function addLog(cls,topic,msg){')
    $h.Add('  var log=document.getElementById("log");')
    $h.Add('  var d=document.createElement("div");d.className="le";')
    $h.Add('  if(cls==="msg")  d.innerHTML="<span class=ts>["+ts()+"]</span> <span class=tp>"+esc(topic)+"</span> <span class=mg>"+esc(msg)+"</span>";')
    $h.Add('  else if(cls==="pub") d.innerHTML="<span class=ts>["+ts()+"]</span> <span class=pb>PUB</span> <span class=tp>"+esc(topic)+"</span> <span class=mg>"+esc(msg)+"</span>";')
    $h.Add('  else if(cls==="sys") d.innerHTML="<span class=ts>["+ts()+"]</span> <span class=sy>"+esc(topic)+"</span>";')
    $h.Add('  else                 d.innerHTML="<span class=ts>["+ts()+"]</span> <span class=er>"+esc(topic)+"</span>";')
    $h.Add('  log.prepend(d);')
    $h.Add('  if(log.children.length>200)log.removeChild(log.lastChild);')
    $h.Add('}')

    $h.Add('function esc(s){var d=document.createElement("div");d.textContent=String(s);return d.innerHTML;}')

    $h.Add('function updateStats(){')
    $h.Add('  document.getElementById("statMsgs").textContent=msgCount;')
    $h.Add('  document.getElementById("statPub").textContent=pubCount;')
    $h.Add('  document.getElementById("statSubs").textContent=subs.length;')
    $h.Add('  if(connStart){var s=Math.floor((Date.now()-connStart)/1000);document.getElementById("statUptime").textContent=Math.floor(s/60)+"m "+s%60+"s";}')
    $h.Add('}')
    $h.Add('setInterval(updateStats,1000);')

    $h.Add('function toggleConnect(){')
    $h.Add('  if(connected){doDisconnect();}else{doConnect();}')
    $h.Add('}')

    $h.Add('function doConnect(){')
    $h.Add('  var host=document.getElementById("cfgHost").value.trim();')
    $h.Add('  var port=parseInt(document.getElementById("cfgPort").value)||9001;')
    $h.Add('  var user=document.getElementById("cfgUser").value.trim();')
    $h.Add('  var pass=document.getElementById("cfgPass").value;')
    $h.Add('  var cid="mqttmgr_"+Math.random().toString(36).substr(2,8);')
    $h.Add('  document.getElementById("brokerBadge").textContent=host+":"+port;')
    $h.Add('  addLog("sys","Conectando a ws://"+host+":"+port+"...","");')
    $h.Add('  try{')
    $h.Add('    client=new Paho.MQTT.Client(host,port,cid);')
    $h.Add('    client.onConnectionLost=function(r){')
    $h.Add('      connected=false;setConnUI(false);')
    $h.Add('      addLog("err","Conexion perdida: "+r.errorMessage,"");')
    $h.Add('    };')
    $h.Add('    client.onMessageArrived=function(m){')
    $h.Add('      msgCount++;')
    $h.Add('      addLog("msg",m.destinationName,m.payloadString);')
    $h.Add('      updateHistory(m.destinationName,m.payloadString);')
    $h.Add('    };')
    $h.Add('    var opts={onSuccess:function(){')
    $h.Add('      connected=true;connStart=Date.now();setConnUI(true);')
    $h.Add('      addLog("sys","Conectado correctamente","");')
    $h.Add('      resubAll();')
    $h.Add('    },onFailure:function(e){')
    $h.Add('      addLog("err","Error de conexion: "+e.errorMessage,"");')
    $h.Add('    },timeout:5};')
    $h.Add('    if(user)opts.userName=user;')
    $h.Add('    if(pass)opts.password=pass;')
    $h.Add('    client.connect(opts);')
    $h.Add('  }catch(e){addLog("err","Paho no disponible: "+e.message,"");}')
    $h.Add('}')

    $h.Add('function doDisconnect(){')
    $h.Add('  if(client)try{client.disconnect();}catch(e){}')
    $h.Add('  connected=false;connStart=null;setConnUI(false);')
    $h.Add('  addLog("sys","Desconectado","");')
    $h.Add('}')

    $h.Add('function setConnUI(on){')
    $h.Add('  document.getElementById("connDot").className="conn-dot"+(on?" on":"");')
    $h.Add('  document.getElementById("connLabel").textContent=on?"Conectado":"Desconectado";')
    $h.Add('  document.getElementById("connBtn").textContent=on?"Desconectar":"Conectar";')
    $h.Add('  document.getElementById("connBtn").className="btn "+(on?"btn-danger":"btn-primary");')
    $h.Add('}')

    $h.Add('function resubAll(){subs.forEach(function(t){try{client.subscribe(t);}catch(e){}});}')

    $h.Add('function addSub(){')
    $h.Add('  var t=document.getElementById("subTopic").value.trim();')
    $h.Add('  if(!t||subs.indexOf(t)>=0)return;')
    $h.Add('  subs.push(t);renderSubs();')
    $h.Add('  if(connected)try{client.subscribe(t);addLog("sys","Suscrito a: "+t,"");}catch(e){}')
    $h.Add('  else addLog("sys","Suscripcion guardada (conectar para activar): "+t,"");')
    $h.Add('}')

    $h.Add('function removeSub(t){')
    $h.Add('  subs=subs.filter(function(s){return s!==t;});')
    $h.Add('  renderSubs();')
    $h.Add('  if(connected)try{client.unsubscribe(t);addLog("sys","Desuscrito de: "+t,"");}catch(e){}')
    $h.Add('}')

    $h.Add('function clearSubs(){subs.forEach(function(t){if(connected)try{client.unsubscribe(t);}catch(e){}});subs=[];renderSubs();}')

    $h.Add('function renderSubs(){')
    $h.Add('  var el=document.getElementById("subsList");')
    $h.Add('  el.innerHTML="";')
    $h.Add('  subs.forEach(function(t){')
    $h.Add('    var c=document.createElement("div");c.className="chip";')
    $h.Add('    var span=document.createElement("span");span.textContent=t;')
    $h.Add('    var x=document.createElement("span");x.className="xbtn";x.textContent="x";')
    $h.Add('    x.setAttribute("data-t",t);')
    $h.Add('    x.onclick=function(){removeSub(this.getAttribute("data-t"));};')
    $h.Add('    c.appendChild(span);c.appendChild(x);el.appendChild(c);')
    $h.Add('  });')
    $h.Add('}')

    $h.Add('function publish(){')
    $h.Add('  var t=document.getElementById("pubTopic").value.trim();')
    $h.Add('  var m=document.getElementById("pubMsg").value.trim();')
    $h.Add('  var q=parseInt(document.getElementById("pubQos").value);')
    $h.Add('  var r=document.getElementById("pubRetain").value==="true";')
    $h.Add('  if(!t||!m){addLog("err","Topic y payload son requeridos","");return;}')
    $h.Add('  if(!connected){addLog("err","No conectado al broker","");return;}')
    $h.Add('  try{')
    $h.Add('    var msg=new Paho.MQTT.Message(m);')
    $h.Add('    msg.destinationName=t;msg.qos=q;msg.retained=r;')
    $h.Add('    client.send(msg);pubCount++;')
    $h.Add('    addLog("pub",t,m);')
    $h.Add('  }catch(e){addLog("err","Error al publicar: "+e.message,"");}')
    $h.Add('}')

    $h.Add('function updateHistory(topic,val){')
    $h.Add('  if(!history[topic])history[topic]={count:0};')
    $h.Add('  history[topic].last=val;history[topic].time=ts();history[topic].count++;')
    $h.Add('  renderHistory();')
    $h.Add('}')

    $h.Add('function renderHistory(){')
    $h.Add('  var tb=document.getElementById("histBody");tb.innerHTML="";')
    $h.Add('  Object.keys(history).forEach(function(t){')
    $h.Add('    var r=document.createElement("tr");')
    $h.Add('    r.innerHTML="<td>"+esc(t)+"</td><td>"+esc(history[t].last)+"</td><td>"+history[t].time+"</td><td>"+history[t].count+"</td>";')
    $h.Add('    tb.appendChild(r);')
    $h.Add('  });')
    $h.Add('}')

    $h.Add('function clearHistory(){history={};document.getElementById("histBody").innerHTML="";}')
    $h.Add('function clearLog(){document.getElementById("log").innerHTML="";}')

    $h.Add('function exportLog(){')
    $h.Add('  var rows=[].slice.call(document.getElementById("log").children).reverse();')
    $h.Add('  var txt=rows.map(function(r){return r.textContent;}).join("\n");')
    $h.Add('  var a=document.createElement("a");')
    $h.Add('  a.href="data:text/plain;charset=utf-8,"+encodeURIComponent(txt);')
    $h.Add('  a.download="mqtt_log_"+new Date().toISOString().replace(/[:.]/g,"-")+".txt";')
    $h.Add('  a.click();')
    $h.Add('}')

    $h.Add('function copyText(t){')
    $h.Add('  navigator.clipboard.writeText(t).then(function(){addLog("sys","Copiado: "+t,"");}).catch(function(){addLog("err","No se pudo copiar","");});')
    $h.Add('}')

    $h.Add('function toggleTheme(){')
    $h.Add('  var b=document.body;')
    $h.Add('  if(b.getAttribute("data-theme")==="dark"){b.removeAttribute("data-theme");document.querySelector(".theme-btn").textContent="Tema Oscuro";}')
    $h.Add('  else{b.setAttribute("data-theme","dark");document.querySelector(".theme-btn").textContent="Tema Claro";}')
    $h.Add('}')

    $h.Add('addLog("sys","Dashboard listo. Broker esperado: localhost:1883 (MQTT) / 9001 (WS)","");')
    $h.Add('</script>')
    $h.Add('</body>')
    $h.Add('</html>')

    # Write file
    ($h -join "`n") | Out-File -FilePath $DASH_FILE -Encoding UTF8 -Force

    CL ""
    CL "  OK  Dashboard generado:" "Green"
    CL "      $DASH_FILE" "Cyan"
    try {
        Start-Process $DASH_FILE
        CL "  Abierto en el navegador predeterminado." "Green"
    } catch {
        CL "  Abre manualmente: $DASH_FILE" "White"
    }
    CL ""
    Pause
}

# ── MAIN LOOP ──────────────────────────────────────────────────
Check-Mosquitto

while ($true) {
    Show-Menu
    Write-Host "  Opcion: " -NoNewline -ForegroundColor White
    $opt = Read-Host

    switch ($opt.Trim()) {
        "1" { Subscribe-Topic          }
        "2" { Publish-Message          }
        "3" { Get-NetworkInfo          }
        "4" { Get-BrokerStatus         }
        "5" { Manage-Service           }
        "6" { View-Log                 }
        "7" { Show-MQTTExplorerConfig  }
        "8" { Open-Dashboard           }
        "0" {
            CL ""
            CL "  Saliendo..." "Green"
            CL ""
            exit 0
        }
        default {
            CL "  Opcion invalida." "Red"
            Start-Sleep -Seconds 1
        }
    }
}
