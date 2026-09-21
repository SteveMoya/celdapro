#!/usr/bin/env python3
"""Genera códigos de licencia Pro para CeldaPro.

El mismo algoritmo está implementado en `lib/core/pro_license.dart`, así que
los códigos que salgan de aquí se aceptan en la app sin conexión.

Uso:
    python3 tools/generar_licencia.py                 # 5 códigos al azar
    python3 tools/generar_licencia.py TALLER01        # uno con etiqueta legible
    python3 tools/generar_licencia.py --verificar CPRO-ABCD-1234-XXXX
"""
import random
import string
import sys

ALFABETO = string.ascii_uppercase + string.digits


def firma(cuerpo: str) -> str:
    """FNV-1a de 32 bits truncado a 4 dígitos hex (igual que en Dart)."""
    h = 0x811C9DC5
    for ch in cuerpo:
        h ^= ord(ch)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return format(h, '08X')[:4]


def generar(payload: str) -> str:
    """Cuerpo de 8 caracteres -> código completo CPRO-XXXX-XXXX-FFFF."""
    p = ''.join(c for c in payload.upper() if c in ALFABETO)[:8]
    p = p.ljust(8, 'X')
    grupos = f'CPRO-{p[:4]}-{p[4:8]}'
    return f'{grupos}-{firma(grupos)}'


def azar() -> str:
    return ''.join(random.choice(ALFABETO) for _ in range(8))


def verificar(codigo: str) -> bool:
    c = codigo.strip().upper().replace(' ', '')
    partes = c.split('-')
    if len(partes) != 4 or partes[0] != 'CPRO':
        return False
    if len(partes[1]) != 4 or len(partes[2]) != 4 or len(partes[3]) != 4:
        return False
    if not partes[1].isalnum() or not partes[2].isalnum():
        return False
    return firma(f'CPRO-{partes[1]}-{partes[2]}') == partes[3]


def main() -> int:
    args = sys.argv[1:]

    if args and args[0] == '--verificar':
        if len(args) < 2:
            print('Falta el código a verificar.')
            return 1
        codigo = args[1]
        valido = verificar(codigo)
        print(f'{codigo}: {"VÁLIDO" if valido else "no válido"}')
        return 0 if valido else 1

    if args:
        for payload in args:
            print(generar(payload))
        return 0

    print('Códigos Pro generados al azar:')
    for _ in range(5):
        print('  ', generar(azar()))
    return 0


if __name__ == '__main__':
    sys.exit(main())
