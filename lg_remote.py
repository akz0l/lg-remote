#!/usr/bin/env python3
"""Control remoto por teclado para TV LG webOS (aiowebostv).

Uso:
    ./venv/bin/python lg_remote.py              # abre el control interactivo
    ./venv/bin/python lg_remote.py --encender    # solo enciende la TV (WOL) y sale
    ./venv/bin/python lg_remote.py --ip 192.168.1.50   # fuerza la IP, sin SSDP
    ./venv/bin/python lg_remote.py --rediscover  # olvida la IP guardada y vuelve a buscar
"""
import argparse
import asyncio
import copy
import json
import re
import socket
import ssl
import sys
import termios
import time
import tty
import urllib.request
from pathlib import Path

from aiowebostv import WebOsClient
from aiowebostv.exceptions import WebOsTvCommandError, WebOsTvPairError
from aiowebostv.handshake import REGISTRATION_MESSAGE
from websockets.client import connect as ws_connect

try:
    from getmac import get_mac_address
except ImportError:
    get_mac_address = None


async def _skip_software_info(self):
    """La TV rechaza este endpoint con el manifiesto sin firma (401); no lo usamos."""
    return {}


WebOsClient.get_software_info = _skip_software_info

# Las TV webOS recientes (webOS 22+/26) bloquean el certificado de firma que
# aiowebostv usa desde 2014 para el emparejamiento ("403 Pairing rejected:
# blacklisted certificate detected"). Un manifiesto sin firmar lo evita (lo
# acepta cualquier firmware, aunque solo otorga los permisos "top-level").
REGISTRATION_MESSAGE["payload"]["manifest"].pop("signatures", None)
REGISTRATION_MESSAGE["payload"]["manifest"].pop("signed", None)

SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SCRIPT_DIR / "config.json"

SSDP_ADDR = "239.255.255.250"
SSDP_PORT = 1900
SSDP_ST = "urn:lge:com:service:webos:second-screen:1"

HELP_TEXT = """
=========================================
 Control remoto LG webOS  (q para salir)
=========================================
 Flechas       -> mover cursor / navegar
 Enter         -> OK / Seleccionar
 Supr/Backspace-> Atras
 h             -> Inicio (Home)
 s             -> Ajustes rapidos
 +  / -        -> Volumen +/-
 m             -> Silencio
 1 2 3 4       -> HDMI 1-4
 y             -> YouTube
 n             -> Netflix
 p             -> Apagar TV
 w             -> Encender TV (Wake-on-LAN)
 ?             -> Mostrar esta ayuda
 q             -> Salir del control
=========================================
"""


def load_config():
    if CONFIG_PATH.exists():
        return json.loads(CONFIG_PATH.read_text())
    return {}


def save_config(cfg):
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))


def _local_ip():
    """Obtiene la IP local usada para salir a internet, sin enviar paquetes reales."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "0.0.0.0"
    finally:
        s.close()


def _parse_location(raw_response):
    match = re.search(r"(?im)^location:\s*(\S+)", raw_response)
    return match.group(1).strip() if match else None


def _looks_like_lg_tv(raw_response, location_url):
    if "lg" in raw_response.lower() or "lge" in raw_response.lower():
        return True
    if not location_url:
        return False
    try:
        with urllib.request.urlopen(location_url, timeout=2) as resp:
            body = resp.read(4096).decode(errors="ignore")
    except Exception:
        return False
    body_low = body.lower()
    return "lg electronics" in body_low or "lge-com" in body_low or "lg.com" in body_low


def discover_tv(timeout=4.0):
    """Busca dispositivos UPnP/SSDP en la red local y filtra los de LG."""
    local_ip = _local_ip()
    msg = (
        "M-SEARCH * HTTP/1.1\r\n"
        f"HOST: {SSDP_ADDR}:{SSDP_PORT}\r\n"
        'MAN: "ssdp:discover"\r\n'
        "MX: 3\r\n"
        "ST: ssdp:all\r\n\r\n"
    ).encode()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(local_ip))
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    sock.bind((local_ip, 0))
    sock.settimeout(timeout)

    found = {}
    try:
        sock.sendto(msg, (SSDP_ADDR, SSDP_PORT))
        sock.sendto(msg, (SSDP_ADDR, SSDP_PORT))  # por si se pierde el primero
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                data, addr = sock.recvfrom(4096)
            except socket.timeout:
                break
            ip = addr[0]
            found.setdefault(ip, data.decode(errors="ignore"))
    finally:
        sock.close()

    lg_ips = []
    for ip, raw in found.items():
        location = _parse_location(raw)
        if _looks_like_lg_tv(raw, location):
            lg_ips.append(ip)

    return lg_ips


def send_wol(mac, broadcast="255.255.255.255", port=9):
    """Envia un magic packet de Wake-on-LAN a la MAC indicada."""
    mac_clean = mac.replace(":", "").replace("-", "").strip().lower()
    if len(mac_clean) != 12:
        raise ValueError(f"MAC invalida: {mac}")
    mac_bytes = bytes.fromhex(mac_clean)
    packet = b"\xff" * 6 + mac_bytes * 16

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    try:
        sock.sendto(packet, (broadcast, port))
    finally:
        sock.close()


async def pair_with_pin(host, pin_timeout=60):
    """Empareja con la TV pidiendo un PIN en pantalla.

    Se usa cuando el boton fisico de la TV no puede aceptar el aviso de
    emparejamiento (por ejemplo, si solo sirve para encender/apagar).
    """
    try:
        ws = await ws_connect(f"ws://{host}:3000", open_timeout=5, close_timeout=5)
    except Exception:
        ssl_context = ssl.SSLContext()
        ws = await ws_connect(f"wss://{host}:3001", ssl=ssl_context, open_timeout=5, close_timeout=5)

    try:
        await ws.send(json.dumps({"id": "hello", "type": "hello"}))
        await ws.recv()

        msg = copy.deepcopy(REGISTRATION_MESSAGE)
        msg["payload"]["client-key"] = None
        msg["payload"]["pairingType"] = "PIN"
        await ws.send(json.dumps(msg))
        resp = json.loads(await ws.recv())
        payload = resp.get("payload", {})
        if payload.get("pairingType") != "PIN" or not payload.get("returnValue"):
            raise RuntimeError(f"La TV no acepto el pedido de PIN: {resp}")

        print("\n>>> MIRA LA TV AHORA: deberia mostrar un codigo PIN en pantalla.")
        loop = asyncio.get_running_loop()
        pin = await loop.run_in_executor(
            None, input, ">>> Escribe aqui el PIN y presiona Enter: "
        )
        pin = pin.strip()

        await ws.send(
            json.dumps(
                {
                    "type": "request",
                    "id": "pin_req",
                    "uri": "ssap://pairing/setPin",
                    "payload": {"pin": pin},
                }
            )
        )

        client_key = None
        deadline = time.time() + pin_timeout
        while time.time() < deadline:
            remaining = deadline - time.time()
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=max(0.1, remaining))
            except asyncio.TimeoutError:
                break
            data = json.loads(raw)
            if data.get("type") == "error":
                raise RuntimeError(f"La TV rechazo el PIN: {data.get('error')}")
            key = data.get("payload", {}).get("client-key")
            if key:
                client_key = key
                break

        if not client_key:
            raise RuntimeError("No recibi la client-key despues de enviar el PIN.")

        return client_key
    finally:
        await ws.close()


async def connect_client(host, client_key):
    """Conecta (y empareja si hace falta) con la TV. Devuelve el cliente conectado."""
    client = WebOsClient(host, client_key=client_key, timeout_connect=8)
    if client_key is None:
        print(
            "\n>>> Mira la TV: va a aparecer un aviso de emparejamiento.\n"
            ">>> Acepta el aviso usando el boton fisico debajo del logo LG\n"
            "    (pulsalo una vez para seleccionar 'Aceptar'/'OK').\n"
        )
    await client.connect()
    return client


async def cache_tv_metadata(client, cfg):
    """Guarda appIds de YouTube/Netflix y el mapeo de entradas HDMI."""
    try:
        apps = await client.get_apps_all()
    except WebOsTvCommandError:
        apps = []

    app_ids = cfg.setdefault("app_ids", {})
    for app in apps or []:
        app_id = app.get("id", "")
        title = (app.get("title") or "").lower()
        low_id = app_id.lower()
        if "youtube" in low_id or "youtube" in title:
            app_ids["youtube"] = app_id
        if "netflix" in low_id or "netflix" in title:
            app_ids["netflix"] = app_id

    try:
        inputs = await client.get_inputs()
    except WebOsTvCommandError:
        inputs = []

    hdmi_map = {}
    for dev in inputs or []:
        dev_id = dev.get("id", "")
        label = (dev.get("label") or "") + dev_id
        for n in "1234":
            if f"hdmi{n}" in label.lower().replace(" ", "").replace("_", ""):
                hdmi_map[n] = dev_id
    cfg["hdmi_map"] = hdmi_map


def get_char():
    """Lee una tecla (o secuencia de escape) del stdin en modo cbreak."""
    ch = sys.stdin.read(1)
    if ch == "\x1b":
        # posible secuencia de flecha: ESC [ A/B/C/D
        seq = ch
        seq += sys.stdin.read(1)
        if seq == "\x1b[":
            seq += sys.stdin.read(1)
        return seq
    return ch


async def ensure_connected(client):
    """Reconecta el cliente si la TV se desconecto (p. ej. tras apagarla/encenderla)."""
    if client.is_connected():
        return True
    try:
        await client.connect()
        return True
    except Exception as exc:  # noqa: BLE001
        print(f"No pude reconectar con la TV todavia: {exc}")
        return False


async def key_loop(client, cfg):
    loop = asyncio.get_running_loop()
    queue = asyncio.Queue()

    def on_stdin():
        queue.put_nowait(get_char())

    loop.add_reader(sys.stdin.fileno(), on_stdin)
    print(HELP_TEXT)
    print("Control activo. Escribe una tecla (sin Enter)...\n")

    hdmi_map = cfg.get("hdmi_map", {})
    app_ids = cfg.get("app_ids", {})

    try:
        while True:
            key = await queue.get()
            try:
                if key == "q":
                    print("Saliendo del control...")
                    break
                elif key == "w":
                    mac = cfg.get("mac")
                    if mac:
                        send_wol(mac)
                        print("-> Wake-on-LAN enviado, esperando que la TV arranque...")
                        await asyncio.sleep(5)
                        if await ensure_connected(client):
                            print("-> Reconectado con la TV.")
                    else:
                        print("No tengo la MAC guardada todavia.")
                    continue
                elif key == "?":
                    print(HELP_TEXT)
                    continue

                if not await ensure_connected(client):
                    continue

                if key in ("\x1b[A",):
                    await client.button("UP")
                elif key in ("\x1b[B",):
                    await client.button("DOWN")
                elif key in ("\x1b[C",):
                    await client.button("RIGHT")
                elif key in ("\x1b[D",):
                    await client.button("LEFT")
                elif key in ("\r", "\n"):
                    await client.button("ENTER")
                elif key in ("\x7f", "\x08"):
                    await client.button("BACK")
                elif key == "h":
                    await client.button("HOME")
                elif key == "s":
                    await client.button("QMENU")
                elif key in ("+", "="):
                    await client.volume_up()
                elif key == "-":
                    await client.volume_down()
                elif key == "m":
                    await client.button("MUTE")
                elif key in ("1", "2", "3", "4"):
                    input_id = hdmi_map.get(key)
                    if input_id:
                        await client.set_input(input_id)
                        print(f"-> HDMI {key} ({input_id})")
                    else:
                        print(f"No encontre el HDMI {key} en la lista de entradas.")
                elif key == "y":
                    yt_id = app_ids.get("youtube", "youtube.leanback.v4")
                    await client.launch_app(yt_id)
                    print("-> YouTube")
                elif key == "n":
                    nf_id = app_ids.get("netflix")
                    if nf_id:
                        await client.launch_app(nf_id)
                    else:
                        await client.button("NETFLIX")
                    print("-> Netflix")
                elif key == "p":
                    await client.power_off()
                    print("-> Apagando TV")
                else:
                    pass  # tecla no mapeada, se ignora
            except WebOsTvCommandError as exc:
                print(f"Error enviando comando: {exc}")
            except (OSError, ConnectionError) as exc:
                print(f"Se perdio la conexion con la TV: {exc}")
                break
    finally:
        loop.remove_reader(sys.stdin.fileno())


async def run_key_loop_with_raw_tty(client, cfg):
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setcbreak(fd)
        await key_loop(client, cfg)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


async def do_encender(cfg):
    mac = cfg.get("mac")
    if not mac:
        print(
            "No tengo la MAC de la TV guardada todavia.\n"
            "Ejecuta el script sin --encender una vez (con la TV encendida)\n"
            "para que la detecte y la guarde."
        )
        return
    print(f"Enviando Wake-on-LAN a {mac} ...")
    send_wol(mac)
    print("Magic packet enviado.")

    host = cfg.get("host")
    client_key = cfg.get("client_key")
    if host and client_key:
        await asyncio.sleep(3)
        try:
            client = await connect_client(host, client_key)
            await client.power_on()
            await client.disconnect()
            print("TV encendida correctamente.")
        except Exception as exc:  # noqa: BLE001
            print(f"WOL enviado; no pude confirmar por websocket ({exc}).")
            print(
                "Si la TV no prende, revisa que 'Encender TV con movil' este activado."
            )


async def main_async(args):
    cfg = load_config()

    if args.rediscover:
        cfg.pop("host", None)

    if args.encender:
        await do_encender(cfg)
        save_config(cfg)
        return

    host = args.ip or cfg.get("host")
    if not host:
        print("Buscando la TV en la red local (SSDP)...")
        candidates = discover_tv()
        if not candidates:
            print(
                "No encontre ninguna TV por SSDP.\n"
                "Pasa la IP manualmente con --ip <IP>."
            )
            return
        host = candidates[0]
        print(f"TV encontrada en {host}")
        if len(candidates) > 1:
            print(f"(Tambien respondieron: {candidates[1:]}, uso la primera)")

    cfg["host"] = host
    client_key = cfg.get("client_key")

    if not client_key:
        print(
            "No hay emparejamiento previo. Como el boton fisico de la TV no\n"
            "puede aceptar el aviso en pantalla, emparejamos por PIN."
        )
        try:
            client_key = await pair_with_pin(host)
        except Exception as exc:  # noqa: BLE001
            print(f"No se pudo emparejar por PIN: {exc}")
            return
        cfg["client_key"] = client_key
        save_config(cfg)
        print("PIN aceptado. Emparejamiento completado.")

    try:
        client = await connect_client(host, client_key)
    except WebOsTvPairError as exc:
        print(f"No se pudo emparejar: {exc}")
        return
    except Exception as exc:  # noqa: BLE001
        print(f"No pude conectar a {host}: {exc}")
        return

    cfg["client_key"] = client.client_key
    save_config(cfg)
    print(f"Conectado y emparejado con {host}. Client key guardada.")

    if get_mac_address is not None:
        mac = get_mac_address(ip=host)
        if mac:
            cfg["mac"] = mac
            print(f"MAC detectada: {mac}")
        else:
            print("No pude detectar la MAC automaticamente (revisa el config.json).")
    else:
        print("getmac no esta instalado; no se guardo la MAC.")

    await cache_tv_metadata(client, cfg)
    save_config(cfg)

    try:
        await run_key_loop_with_raw_tty(client, cfg)
    finally:
        await client.disconnect()
        save_config(cfg)


def main():
    parser = argparse.ArgumentParser(description="Control remoto para LG webOS TV")
    parser.add_argument("--ip", help="IP de la TV (omite la busqueda SSDP)")
    parser.add_argument(
        "--encender", action="store_true", help="Solo encender la TV (Wake-on-LAN) y salir"
    )
    parser.add_argument(
        "--rediscover",
        action="store_true",
        help="Olvida la IP guardada y vuelve a buscar la TV",
    )
    args = parser.parse_args()
    asyncio.run(main_async(args))


if __name__ == "__main__":
    main()
