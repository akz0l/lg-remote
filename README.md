# lg-remote

Control remoto por teclado para TVs LG webOS, usando [`aiowebostv`](https://github.com/home-assistant-libs/aiowebostv).

Pensado para el caso de "se rompió el control remoto": controla la TV desde el
teclado de tu Mac/PC (navegación, volumen, HDMI, apps) y enciéndela por
Wake-on-LAN aunque esté completamente apagada.

## App para la barra de menú (macOS)

En `mac/` hay una app nativa en SwiftUI: un ícono en la barra de menú que abre
un panel con todos los controles. Se usa con clicks o con las mismas teclas del
CLI (la tecla de cada control aparece en su esquina). `Esc` cierra el panel.

Requisitos: macOS 14+ (con Liquid Glass en macOS 26+) y Xcode o las Command
Line Tools.

```bash
cd mac
scripts/build-app.sh            # genera mac/build/LG Remote.app
scripts/build-app.sh --install  # además la copia a /Applications
```

- **Primer uso:** el panel ofrece *Buscar en la red* (SSDP), escribir la IP a
  mano o *Importar config.json del CLI…* (reutiliza el emparejamiento existente,
  sin PIN). Si empareja de cero, pide el PIN que muestra la TV.
- La configuración se guarda en
  `~/Library/Application Support/LGRemote/config.json` (permisos `600`).
- Si la TV no responde, el panel ofrece *Encender* (Wake-on-LAN, tecla `W`).
- Para abrirla al iniciar sesión: Ajustes del Sistema → General → Ítems de inicio.

Desarrollo:

```bash
cd mac
swift test                                                    # tests unitarios
LGREMOTE_LIVE_CONFIG=../config.json swift test --filter LiveTVTests  # contra la TV real (solo lectura)
LGREMOTE_PREVIEW=connected swift run LGRemote                 # panel con TV simulada (connected|unreachable|setup|pin)
```

## CLI

### Requisitos

- Python 3.9+
- La TV y la computadora en la misma red local (cable o WiFi, no importa).

### Instalación

```bash
git clone <este-repo> lg_remote
cd lg_remote
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
```

### Primer uso (emparejamiento)

```bash
./venv/bin/python lg_remote.py
```

- Busca la TV automáticamente por SSDP. Si no la encuentra, pasa la IP a mano
  con `--ip 192.168.1.50`.
- La primera vez te va a pedir un **PIN**: mira la pantalla de la TV y
  escríbelo en la terminal. (No depende del control remoto físico ni de
  aceptar un aviso en la TV — algunos modelos recientes tienen el botón físico
  limitado a encender/apagar y no sirve para aceptar avisos en pantalla.)
- Guarda el `client_key`, la MAC (para Wake-on-LAN) y el mapeo de apps/HDMI en
  `config.json` (no se versiona, es específico de tu TV).

#### Nota técnica: certificado bloqueado

Las TV webOS más recientes (webOS 22+/26) rechazan el manifiesto de
emparejamiento firmado que `aiowebostv` usa desde 2014
(`403 Pairing rejected: blacklisted certificate detected`). Este proyecto
parchea eso en tiempo de ejecución enviando el manifiesto sin firmar (ver
`lg_remote.py`), que es aceptado por cualquier firmware. Por el mismo motivo,
el emparejamiento usa PIN en vez del aviso en pantalla, y se omite la llamada
`getCurrentSWInformation` (requiere un permiso que solo otorgan los
manifiestos firmados).

### Teclas

| Tecla      | Acción                  |
|------------|-------------------------|
| Flechas    | Mover cursor / navegar  |
| Enter      | OK / Seleccionar        |
| Supr/Backspace | Atrás               |
| `h`        | Inicio (Home)           |
| `s`        | Ajustes rápidos         |
| `+` / `-`  | Volumen                 |
| `m`        | Silencio                |
| `1`-`4`    | Cambiar a HDMI 1-4      |
| `y`        | YouTube                 |
| `n`        | Netflix                 |
| `p`        | Apagar TV               |
| `w`        | Encender TV (Wake-on-LAN) |
| `?`        | Mostrar ayuda           |
| `q`        | Salir                   |

### Solo encender la TV

```bash
./venv/bin/python lg_remote.py --encender
```

### Alias para usarlo desde cualquier terminal

Agrega a tu `~/.zshrc`:

```bash
alias lgtv="/ruta/a/lg_remote/lgtv.sh"
```

Luego `source ~/.zshrc` (o abre una terminal nueva) y listo:

```bash
lgtv              # abre el control
lgtv --encender   # solo prende la TV
```

### Otras opciones

- `--ip <IP>`: fuerza la IP de la TV, sin buscarla por SSDP.
- `--rediscover`: olvida la IP guardada y la vuelve a buscar.
