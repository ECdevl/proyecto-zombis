#!/usr/bin/env python3
"""Verifica las conexiones de senal declaradas en los .tscn del proyecto.

Para cada linea [connection] comprueba que:
  1) el nodo destino existe,
  2) el metodo destino esta definido en el script de ese nodo (o en una de sus
     clases base del proyecto),
  3) la senal de origen existe: la declara el script del nodo origen o es una
     senal del motor.

Las escenas instanciadas se expanden, asi que tambien se revisan las
conexiones que viven dentro de ellas.

La tabla de senales del motor se genera con tools/dump_engine_signals.gd.

Uso:
    python3 tools/check_tscn_connections.py [raiz_del_proyecto]

Codigo de salida: 1 si hay alguna conexion rota, 0 si no.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from engine_signals import ENGINE_SIGNALS  # noqa: E402

RAIZ = sys.argv[1] if len(sys.argv) > 1 else "."

ATTR_RE = re.compile(r'(\w+)="([^"]*)"')
EXT_RESOURCE_RE = re.compile(r'^\[ext_resource\s+.*id="([^"]+)"')
CONN_RE = re.compile(
    r'^\[connection\s+signal="([^"]+)"\s+from="([^"]+)"\s+to="([^"]+)"\s+method="([^"]+)"'
)
SCRIPT_RE = re.compile(r'^script\s*=\s*ExtResource\("([^"]+)"\)')
INSTANCE_RE = re.compile(r'^instance=ExtResource\("([^"]+)"\)')
CLASS_NAME_RE = re.compile(r'\bclass_name\s+(\w+)')
EXTENDS_RE = re.compile(r'\bextends\s+([\w./"\']+)')
FUNC_RE = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)\s*\(')
SIGNAL_RE = re.compile(r'^\s*signal\s+(\w+)')

_cache_scripts = {}
_cache_escenas = {}


# --------------------------------------------------------------------------
# Scripts
# --------------------------------------------------------------------------

def leer(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def parse_script(path):
    """{metodos, senales, clase_base, class_name} de un .gd"""
    if path in _cache_scripts:
        return _cache_scripts[path]
    info = {"metodos": set(), "senales": set(), "base": None, "clase": None}
    if os.path.isfile(path):
        for linea in leer(path).splitlines():
            if linea.strip().startswith("#"):
                continue
            m = CLASS_NAME_RE.search(linea)
            if m:
                info["clase"] = m.group(1)
            # "class_name X extends Y" esta todo en la misma linea: no hay
            # que cortar el bucle tras detecting el class_name.
            m = EXTENDS_RE.search(linea)
            if m and info["base"] is None:
                info["base"] = m.group(1).strip('"').strip("'")
            m = FUNC_RE.match(linea)
            if m:
                info["metodos"].add(m.group(1))
            m = SIGNAL_RE.match(linea)
            if m:
                info["senales"].add(m.group(1))
    _cache_scripts[path] = info
    return info


def indice_clases(raiz):
    """class_name global -> ruta del .gd que la declara"""
    indice = {}
    for dirpath, dirs, files in os.walk(raiz):
        dirs[:] = [d for d in dirs if d not in (".godot", ".git")]
        for f in files:
            if f.endswith(".gd"):
                ruta = os.path.join(dirpath, f)
                clase = parse_script(ruta)["clase"]
                if clase:
                    indice[clase] = ruta
    return indice


def heredar_script(ruta, indice, vistos=None):
    """(metodos, senales) del script y de sus clases base del proyecto"""
    if vistos is None:
        vistos = set()
    if not ruta or ruta in vistos:
        return set(), set()
    vistos.add(ruta)
    info = parse_script(ruta)
    metodos = set(info["metodos"])
    senales = set(info["senales"])
    base = info["base"]
    if base and not base.startswith("res://") and not base.endswith(".gd"):
        ruta_base = indice.get(base)
        if ruta_base:
            m, s = heredar_script(ruta_base, indice, vistos)
            metodos |= m
            senales |= s
    return metodos, senales


# --------------------------------------------------------------------------
# Escenas
# --------------------------------------------------------------------------

def parse_scene(ruta):
    """(ext_resources, nodos, conexiones) de un .tscn

    nodos: ruta_relativa -> {"script", "tipo", "instancia"}
    La raiz de la escena se indexa tambien como "." (asi la escriben las
    conexiones) y con su nombre.
    """
    ext = {}
    nodos = {}
    conexiones = []
    actual = None
    raiz_nombre = None

    for linea in leer(ruta).splitlines():
        if linea.startswith("[ext_resource"):
            m = EXT_RESOURCE_RE.match(linea)
            p = re.search(r'path="([^"]+)"', linea)
            if m and p:
                ext[m.group(1)] = p.group(1)
            actual = None
            continue
        if linea.startswith("[node "):
            cab = linea[len("[node "):]
            attrs = dict(ATTR_RE.findall(cab))
            nombre = attrs.get("name", "")
            if "parent" not in attrs:
                raiz_nombre = nombre
                ruta_rel = "."          # la raiz
            else:
                padre = attrs["parent"]
                ruta_rel = nombre if padre == "." else padre + "/" + nombre
            actual = {"ruta": ruta_rel, "nombre": nombre, "script": None,
                      "tipo": attrs.get("type", ""), "instancia": None}
            # la instancia puede venir en la propia cabecera del nodo
            m = re.search(r'instance=ExtResource\("([^"]+)"\)', cab)
            if m:
                actual["instancia"] = ext.get(m.group(1))
            nodos[ruta_rel] = actual
            continue
        m = CONN_RE.match(linea)
        if m:
            conexiones.append(m.groups())
            actual = None
            continue
        if actual is not None:
            m = SCRIPT_RE.match(linea)
            if m:
                actual["script"] = ext.get(m.group(1))
                continue
            m = INSTANCE_RE.match(linea)
            if m:
                actual["instancia"] = ext.get(m.group(1))
                continue
            if "type=" not in linea and actual["tipo"] == "":
                m = re.match(r'^type="(\w+)"', linea)
                if m:
                    actual["tipo"] = m.group(1)

    if raiz_nombre:
        nodos.setdefault(raiz_nombre, nodos["."])
    return ext, nodos, conexiones


def arbol_escena(ruta, indice, vistos=None):
    """Arbol de nodos de una escena, expandiendo las escenas instanciadas."""
    if ruta in _cache_escenas:
        return _cache_escenas[ruta]
    if vistos is None:
        vistos = set()
    if ruta in vistos:
        return {}
    vistos.add(ruta)
    _ext, nodos, _con = parse_scene(ruta)

    arbol = {}
    for r, nodo in nodos.items():
        script = nodo["script"]
        if script:
            script = os.path.join(RAIZ, script[len("res://"):])
        tipo = nodo["tipo"]
        instancia = nodo["instancia"]
        if instancia and not tipo:
            # el tipo nativo es el de la raiz de la escena instanciada
            ruta_inst = os.path.join(RAIZ, instancia[len("res://"):])
            _e, sub_nodos, _c = parse_scene(ruta_inst)
            sub_raiz = sub_nodos.get(".", {})
            tipo = sub_raiz.get("tipo", "")
            if not script:
                script = sub_raiz.get("script")
                if script:
                    script = os.path.join(RAIZ, script[len("res://"):])
        arbol[r] = {"script": script, "tipo": tipo, "instancia": instancia}

    # expande las instancias: sus nodos internos cuelgan del nodo instancia
    for r, nodo in nodos.items():
        if nodo["instancia"]:
            ruta_inst = os.path.join(RAIZ, nodo["instancia"][len("res://"):])
            sub = arbol_escena(ruta_inst, indice, vistos)
            for sub_r, sub_nodo in sub.items():
                prefijo = r if r != "." else ""
                completo = sub_r if r == "." else r + "/" + sub_r
                if completo == ".":
                    continue
                arbol[completo] = sub_nodo
    _cache_escenas[ruta] = arbol
    return arbol


def senales_de_motor(tipo):
    """Senales de una clase del motor. Si el tipo se desconoce (nodo
    re-declarado dentro de una escena instanciada) se devuelve el-union de
    todas: es un chequeo mas laxo, pero nunca da falsos positivos."""
    if tipo:
        return set(ENGINE_SIGNALS.get(tipo, []))
    return set().union(*[set(v) for v in ENGINE_SIGNALS.values()]) if ENGINE_SIGNALS else set()


# --------------------------------------------------------------------------

def main():
    global RAIZ
    RAIZ = os.path.abspath(RAIZ)
    indice = indice_clases(RAIZ)

    escenas = []
    for dirpath, dirs, files in os.walk(RAIZ):
        dirs[:] = [d for d in dirs if d not in (".godot", ".git")]
        for f in files:
            if f.endswith(".tscn"):
                escenas.append(os.path.join(dirpath, f))
    escenas.sort()

    total = 0
    rotas = []
    for escena in escenas:
        arbol = arbol_escena(escena, indice)
        _e, _n, conexiones = parse_scene(escena)
        for senal, origen, destino, metodo in conexiones:
            total += 1
            nodo_destino = arbol.get(destino)
            if nodo_destino is None:
                rotas.append((escena, senal, origen, destino, metodo,
                              "el nodo destino no existe"))
                continue

            # (2) el metodo destino existe
            script_destino = nodo_destino["script"]
            if script_destino:
                if not os.path.isfile(script_destino):
                    rotas.append((escena, senal, origen, destino, metodo,
                                  "no se encuentra %s" % script_destino))
                    continue
                metodos, _s = heredar_script(script_destino, indice)
                if metodo not in metodos:
                    rotas.append((escena, senal, origen, destino, metodo,
                                  "el metodo no existe en el script"))

            # (3) la senal de origen existe
            nodo_origen = arbol.get(origen)
            if nodo_origen is None:
                rotas.append((escena, senal, origen, destino, metodo,
                              "el nodo origen no existe"))
                continue
            if nodo_origen["script"] and os.path.isfile(nodo_origen["script"]):
                _m, senales_script = heredar_script(nodo_origen["script"], indice)
                if senal in senales_script:
                    continue
            if senal in senales_de_motor(nodo_origen["tipo"]):
                continue
            rotas.append((escena, senal, origen, destino, metodo,
                          "la senal de origen no existe"))

    print("Escenas analizadas: %d | conexiones: %d" % (len(escenas), total))
    if not rotas:
        print("OK: ninguna conexion de senal esta rota.")
        return 0
    for escena, senal, origen, destino, metodo, por_que in rotas:
        print("ROTA %s: %s.%s -> %s.%s (%s)" % (
            os.path.relpath(escena, RAIZ), origen, senal, destino, metodo, por_que))
    print("\n%d conexion(es) rota(s) de %d." % (len(rotas), total))
    return 1


if __name__ == "__main__":
    sys.exit(main())
