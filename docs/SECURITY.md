# Seguridad

## Activos

- Tokens de publicación y lectura.
- Passphrase SRT, certificados y futuras credenciales Twitch/OBS.
- Integridad y disponibilidad del directo.
- Grabaciones, logs, IP y futura ubicación.
- Capacidad administrativa del VPS.

## Fronteras y amenazas

| Amenaza | Control actual | Riesgo residual |
|---|---|---|
| Publicación no autorizada | Token aleatorio ≥32 bytes, ruta fija, comparación constante | Fuerza bruta distribuida/filtración |
| Lectura no autorizada | Token separado + passphrase SRT | Una URL copiada concede acceso hasta rotación |
| Intercepción RTMP | Activar RTMPS en producción; RTMP restringible por firewall | Quik debe aceptar el certificado |
| Intercepción SRT | Passphrase obligatoria (AES de SRT) | Metadatos y endpoints siguen visibles |
| Abuso de API/metrics | Solo red Docker; host API en loopback | Un contenedor comprometido comparte red |
| Secretos en logs | API omite token/query/password; logs JSON | Clientes pueden registrar su propia URL |
| Imagen maliciosa | Versiones fijadas, locks Go, Trivy, procesos persistentes no root, RO FS | Faltan firmas/digests y escaneo continuo |
| DoS | Máximo de lectores, límites de recursos, firewall | RTMP/SRT públicos pueden recibir tráfico |
| Fuga HLS | HTTPS + autenticación MediaMTX | URLs/tokens pueden quedar en herramientas cliente |

## Reglas

- `.env`, claves privadas, backups y grabaciones no entran en Git.
- Nunca pasar secretos como argumentos visibles cuando exista alternativa.
- No imprimir `.env` en diagnósticos.
- Rotar `PUBLISH_TOKEN`, `READ_TOKEN` y `SRT_READ_PASSPHRASE` por separado.
- `PUBLISH_TOKEN` y `READ_TOKEN` deben ser distintos y de al menos 32
  caracteres; producción recomienda 64 hex.
- El puerto RTMP 1935 debe cerrarse tras validar RTMPS, salvo necesidad
  documentada.
- OBS WebSocket nunca se expondrá; Fase 5 usará agente/túnel saliente.

## Rotación

1. Detener la fuente, no todo el host.
2. Generar el secreto nuevo fuera de Git.
3. Actualizar `.env`.
4. Recrear `control-api` y `mediamtx`.
5. Actualizar Quik u OBS según el secreto rotado.
6. Probar; el secreto anterior deja de funcionar al recrear.

Actualmente no hay rotación solapada. Se añadirá una ventana de transición
controlada cuando exista persistencia.

## Respuesta a incidentes

1. Desconectar/aislar el puerto afectado en firewall.
2. Conservar logs y ejecutar `./scripts/diagnostics.sh`.
3. Rotar secretos comprometidos y certificados si procede.
4. Recrear contenedores desde imágenes verificadas.
5. Restaurar solo backups verificados.
6. Documentar cronología, alcance y acción preventiva.

No se afirma seguridad completa. La auditoría local ejecuta gosec, govulncheck,
Trivy, ShellCheck y Hadolint, pero faltan SBOM firmado, escaneo continuo,
fail2ban y pruebas hostiles de aislamiento de Fase 13.
