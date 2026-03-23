<img width="938" height="512" alt="Image" src="https://github.com/user-attachments/assets/b684af80-b265-416c-8f09-57e3997259d1" />
> Herramienta de terminal para gestión, monitoreo y control de un broker **Mosquitto local** en Windows, con Dashboard Web integrado.

<div align="center">

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=flat-square&logo=powershell)
![Mosquitto](https://img.shields.io/badge/Mosquitto-2.0%2B-purple?style=flat-square)
![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?style=flat-square&logo=windows)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

</div>

---

## 📋 Contenido

<details>
<summary><strong>Ver índice completo</strong></summary>

- [Características](#-características)
- [Requisitos](#-requisitos)
- [Instalación de Mosquitto](#-instalación-de-mosquitto)
- [Configuración del broker](#-configuración-del-broker)
- [Ejecución del script](#-ejecución-del-script)
- [Opciones del menú](#-opciones-del-menú)
- [Dashboard Web](#-dashboard-web)
- [Conexión desde MQTT Explorer](#-conexión-desde-mqtt-explorer)
- [Conexión desde ESP32](#-conexión-desde-esp32)
- [Solución de problemas](#-solución-de-problemas)
- [Créditos](#-créditos)

</details>

---

## ✨ Características

| Función | Descripción |
|---|---|
| 📡 Suscribirse | Escucha topics en tiempo real con timestamps y QoS configurable |
| 📤 Publicar | Envía mensajes con QoS 0/1/2 y opción Retain |
| 🌐 Info de red | Muestra todas las IPs locales y estado de puertos |
| 📊 Estado broker | PID, RAM, uptime, conexiones activas, firewall |
| ⚙️ Gestionar servicio | Iniciar / detener / reiniciar Mosquitto |
| 📄 Ver log | Últimas líneas del log con color por severidad |
| 🔗 Config MQTT Explorer | Parámetros listos para copiar |
| 🖥️ Dashboard Web | Interfaz completa con tema claro/oscuro, WebSocket real |

---

## 🔧 Requisitos

- **Windows 10 / 11**
- **PowerShell 5.1 o superior** (incluido en Windows)
- **Eclipse Mosquitto 2.0+** ([descargar aquí](https://mosquitto.org/download/))
- Permisos de **Administrador** para configurar el broker y el firewall

---

## 📦 Instalación de Mosquitto

<details>
<summary><strong>Paso 1 — Descargar e instalar Mosquitto</strong></summary>

1. Ve a [mosquitto.org/download](https://mosquitto.org/download/)
2. Descarga el instalador `.exe` para Windows (64-bit)
3. Ejecuta el instalador como **Administrador**
4. Ruta de instalación por defecto: `C:\Program Files\mosquitto\`
5. Asegúrate de marcar **"Install as a service"** durante la instalación

</details>

<details>
<summary><strong>Paso 2 — Crear carpetas necesarias</strong></summary>

Abre **PowerShell como Administrador** y ejecuta:

```powershell
New-Item -Path "C:\Program Files\mosquitto\logs" -ItemType Directory -Force
New-Item -Path "C:\Program Files\mosquitto\data" -ItemType Directory -Force
icacls "C:\Program Files\mosquitto\logs" /grant Everyone:F
icacls "C:\Program Files\mosquitto\data" /grant Everyone:F
```

</details>

<details>
<summary><strong>Paso 3 — Abrir puertos en el Firewall</strong></summary>

```powershell
New-NetFirewallRule -DisplayName "Mosquitto MQTT" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow
New-NetFirewallRule -DisplayName "Mosquitto WebSocket" -Direction Inbound -Protocol TCP -LocalPort 9001 -Action Allow
```

</details>

---

## ⚙️ Configuración del broker

<details>
<summary><strong>Configurar mosquitto.conf (requerido para WebSocket)</strong></summary>

Abre el archivo de configuración como **Administrador**:

```powershell
Start-Process notepad "C:\Program Files\mosquitto\mosquitto.conf" -Verb RunAs
```

Borra todo el contenido y pega exactamente lo siguiente:

```ini
# Puerto MQTT estándar (ESP32, MQTT Explorer, terminal)
listener 1883
socket_domain ipv4
allow_anonymous true

# Puerto WebSocket (Dashboard web / navegador)
listener 9001
protocol websockets
socket_domain ipv4
allow_anonymous true

# Log
log_dest file C:\mosquitto\logs\mosquitto.log
log_type all
```

> ⚠️ **Importante:** usa `C:\mosquitto\logs\` (sin espacios) para evitar errores en la ruta del log.

Crea esa carpeta también:

```powershell
New-Item -Path "C:\mosquitto\logs" -ItemType Directory -Force
icacls "C:\mosquitto\logs" /grant Everyone:F
```

Guarda el archivo y reinicia el servicio:

```powershell
Restart-Service mosquitto
```

Verifica que el puerto 9001 esté activo:

```powershell
netstat -ano | findstr ":9001"
```

Debe mostrar una línea con `LISTENING`.

</details>

---

## 🚀 Ejecución del script

<details>
<summary><strong>Clonar el repositorio</strong></summary>

```bash
git clone https://github.com/Pacheco55/mqtt-manager-windows.git
cd mqtt-manager-windows
```

</details>

<details>
<summary><strong>Ejecutar en PowerShell como Administrador</strong></summary>

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\mqtt_manager_windows.ps1
```

> 💡 El flag `-Scope Process` solo aplica la política para esta sesión — no modifica la configuración global del sistema.

</details>

Al ejecutar verás el menú principal con el estado del broker en tiempo real:


<img width="641" height="975" alt="Image" src="https://github.com/user-attachments/assets/174b0c20-20d4-4e43-a84f-fe06a63fc54a" />


---

## 📟 Opciones del menú

<details>
<summary><strong>[1] Suscribirse a Topic</strong></summary>

Escucha mensajes en tiempo real. Soporta wildcards MQTT:

- `#` — todos los topics
- `casa/#` — todos los subtopics bajo `casa/`
- `sensor/+/temp` — un nivel comodín

Presiona `Ctrl+C` para volver al menú.

</details>

<details>
<summary><strong>[2] Enviar Mensaje</strong></summary>

Publica en cualquier topic con:
- **QoS** 0, 1 o 2
- **Retain** activable (el broker guarda el último mensaje)

</details>

<details>
<summary><strong>[3] Info de Red</strong></summary>

Muestra todas las IPs locales disponibles, la IP recomendada para ESP32 y MQTT Explorer, y el estado actual de los puertos 1883 y 9001.

</details>

<details>
<summary><strong>[4] Estado del Broker</strong></summary>

- PID del proceso
- RAM y CPU consumidos
- Uptime desde el último inicio
- Número de conexiones TCP activas
- Directivas activas en `mosquitto.conf`
- Reglas de firewall relacionadas

</details>

<details>
<summary><strong>[5] Gestionar Servicio</strong></summary>

Control directo del servicio Windows de Mosquitto: iniciar, detener, reiniciar, y configurar inicio automático.

</details>

<details>
<summary><strong>[6] Ver Log</strong></summary>

Muestra las últimas 30 líneas del log con resaltado por color:
- 🔴 Rojo — errores
- 🟡 Amarillo — advertencias
- 🟢 Verde — conexiones nuevas

</details>

<details>
<summary><strong>[7] Config MQTT Explorer</strong></summary>

Muestra los parámetros exactos para conectar desde:
- Esta misma PC (localhost)
- Otra PC en la misma red (con la IP local)
- Un ESP32 o microcontrolador

</details>

---

## 🖥️ Dashboard Web

La opción `[8]` genera y abre un archivo HTML con interfaz completa:

- **Conexión real** al broker vía WebSocket (Paho MQTT JS)
- **Suscripciones** con chips eliminables y soporte de wildcards
- **Publicar** con QoS, Retain y validación
- **Log en vivo** con exportación a `.txt`
- **Historial de topics** con último valor y conteo
- **Estadísticas** en tiempo real
- **Tema claro / oscuro** con toggle

> Para que el Dashboard se conecte al broker, el puerto 9001 WebSocket debe estar activo (ver [Configuración del broker](#-configuración-del-broker)).

**Parámetros de conexión en el Dashboard:**

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Puerto WS | `9001` |
| Usuario | *(vacío)* |
| Password | *(vacío)* |

<img width="1846" height="681" alt="Image" src="https://github.com/user-attachments/assets/adeac9ec-c8ff-4c27-8020-d667565ac8bc" />
<img width="1835" height="885" alt="Image" src="https://github.com/user-attachments/assets/16b540b8-e8bb-4b9c-a84d-b8dd608a7795" />
<img width="1838" height="845" alt="Image" src="https://github.com/user-attachments/assets/a02267c0-721f-4392-b3cb-ad01edeb23b8" />

---

## 🔌 Conexión desde MQTT Explorer

1. Descarga MQTT Explorer desde [mqtt-explorer.com](http://mqtt-explorer.com)
2. Crea una nueva conexión con estos datos:

| Campo | Valor |
|---|---|
| Protocol | `mqtt://` |
| Host | `localhost` o tu IP local |
| Port | `1883` |
| Username | *(vacío)* |
| Password | *(vacío)* |
| TLS | OFF |

---

## 📡 Conexión desde ESP32

Usa la IP local que muestra la opción `[3]` del menú (ej. `192.168.1.X`):

```cpp
#include <PubSubClient.h>

const char* mqtt_server = "192.168.1.X";  // IP que muestra la opción [3]
const int   mqtt_port   = 1883;

WiFiClient espClient;
PubSubClient client(espClient);
```

---

## 🛠️ Solución de problemas

<details>
<summary><strong>El servicio inicia pero el puerto 9001 no aparece</strong></summary>

Ejecuta Mosquitto manualmente para ver el error exacto:

```powershell
Stop-Service mosquitto
& "C:\Program Files\mosquitto\mosquitto.exe" -c "C:\Program Files\mosquitto\mosquitto.conf" -v
```

Si no muestra output, verifica que la ruta del log no tenga espacios (usa `C:\mosquitto\logs\`).

</details>

<details>
<summary><strong>Error: "El término '.\mqtt_manager_windows.ps1' no se reconoce"</strong></summary>

El script no está en la carpeta actual. Usa la ruta completa o navega a la carpeta donde lo descargaste:

```powershell
cd C:\Users\TuUsuario\Downloads
.\mqtt_manager_windows.ps1
```

</details>

<details>
<summary><strong>Error de política de ejecución</strong></summary>

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

</details>

<details>
<summary><strong>El Dashboard dice "Desconectado" aunque el broker corre</strong></summary>

El Dashboard usa WebSocket (puerto 9001), no MQTT directo (1883). Verifica:

```powershell
netstat -ano | findstr ":9001"
```

Si no hay resultado, el WebSocket no está configurado — revisa el `mosquitto.conf`.

</details>

---

## 📁 Estructura del repositorio

```
mqtt-manager-windows/
├── mqtt_manager_windows.ps1   # Script principal
└── README.md                  # Esta documentación
```

---

## 📜 Créditos

<div align="center">

```
╔═══════════════════════════════════════╗
║         PIXELBITS Studio              ║
║   Julio César Pacheco Rojas           ║
║   Ingeniería en Software              ║
║   PIXELBITS Studios                   ║
╚═══════════════════════════════════════╝
```

[![GitHub](https://img.shields.io/badge/GitHub-Pacheco55-181717?style=flat-square&logo=github)](https://github.com/Pacheco55)

</div>

---

<div align="center">
<sub>Desarrollado con PowerShell · Eclipse Mosquitto · Paho MQTT JS</sub>
</div>
