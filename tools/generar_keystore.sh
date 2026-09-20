#!/usr/bin/env bash
# Genera el keystore de firma de CeldaPro.
#
# Ejecútalo en TU equipo (no en un servidor) para que la contraseña no salga
# nunca de tu control. El keystore es lo que identifica la app ante Google Play:
# si se pierde, no podrás volver a actualizarla. Guarda una copia de seguridad
# en un lugar seguro (gestor de contraseñas, disco externo, nube privada).
#
# Uso:  ./tools/generar_keystore.sh
set -euo pipefail

ALIAS="${KEY_ALIAS:-celdapro}"
DESTINO="${KEYSTORE:-$HOME/.keystore/celdapro-upload.jks}"
VALIDOS="${VALIDOS:-10000}"

mkdir -p "$(dirname "$DESTINO")"

if [ -f "$DESTINO" ]; then
  echo "Ya existe un keystore en $DESTINO"
  echo "Si lo reemplazas, no podrás volver a firmar actualizaciones de la app."
  read -r -p "¿Sobrescribir? (escribe SI para continuar): " r
  [ "$r" = "SI" ] || { echo "Cancelado."; exit 1; }
fi

echo "Creando keystore en: $DESTINO"
echo "Alias: $ALIAS"
echo
echo "Se te pedirá una contraseña (mínimo 6 caracteres) y tus datos."
echo "APUNTA LA CONTRASEÑA: sin ella el keystore no sirve."
echo

keytool -genkeypair -v \
  -keystore "$DESTINO" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity "$VALIDOS" \
  -storetype JKS

echo
echo "Keystore creado."
echo
echo "Ahora crea android/key.properties con:"
echo "  storePassword=<tu contraseña>"
echo "  keyPassword=<tu contraseña>"
echo "  keyAlias=$ALIAS"
echo "  storeFile=$DESTINO"
echo
echo "Y para que la CI pueda firmar, sube estos secretos al repositorio"
echo "(Settings → Secrets and variables → Actions):"
echo "  KEYSTORE_BASE64  = base64 -w0 '$DESTINO'"
echo "  KEYSTORE_PASSWORD"
echo "  KEY_ALIAS"
echo "  KEY_PASSWORD"
