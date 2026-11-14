# Auditoría técnica integral — 2026-07-31

## Alcance

Revisión de la Fase 1 completa: API Go, autenticación, MediaMTX, Caddy, Docker
Compose, secretos/configuración, scripts operativos, backup/restore,
documentación y flujo multimedia sintético. No se atribuye a esta auditoría
ninguna prueba física que no se haya ejecutado.

## Hallazgos corregidos

| Severidad | Hallazgo | Corrección y evidencia |
|---|---|---|
| Alta | `update.sh` continuaba si la API de estado no respondía | Endpoint normalizado `/v1/media/status` y aborto fail-closed; probado con API detenida, sin crear backup ni mutar servicios |
| Alta | Cambiar `MEDIA_PATH` desalineaba API, path MediaMTX y passphrase SRT | Path dinámico con default seguro, validación estricta y flujo completo aprobado con `directo_a` |
| Alta | Caddy persistente se ejecutaba como root pese a la documentación | Imagen UID/GID 10003, puertos internos no privilegiados 8080/8443 y cero capacidades efectivas; migración de volúmenes aislada y efímera |
| Alta | Alpine 3.23.3 y el binario oficial Caddy 2.11.4 contenían dependencias con HIGH/CRITICAL corregibles | Runtime Alpine 3.23.5 y Caddy estándar recompilado con Go 1.26.5, x/text 0.39.0 y gRPC 1.82.1; Trivy final 0 HIGH/CRITICAL |
| Media | Auth aceptaba un segundo documento JSON tras uno válido | Comprobación de EOF y prueba de regresión |
| Media | `MEDIA_API_URL` aceptaba orígenes ambiguos con credenciales/path/query | Parseo estricto de origen HTTP(S) |
| Media | Backup dependía de `shasum`, no habitual en VPS Linux | Selección portable `sha256sum`/`shasum` y checksum relativo |
| Media | La integración no verificaba HLS público, RTMP read ni passphrase SRT errónea | Batería ampliada a siete escenarios y Caddy incluido |
| Baja | El generador SRT producía Base64 con caracteres delicados en query | Nuevas passphrases hex; compatibilidad preservada con valores existentes |
| Baja | ShellCheck detectó rutas de `source`, `cd` sin control y asignación ambigua | Scripts corregidos y análisis limpio |

## Validación ejecutada

- Unitarias Go y `go vet`, incluidas regresiones de JSON, path, URL y estado.
- Flujo real sintético RTMP → SRT cifrado con H.264/AAC y ruta personalizada.
- HLS HTTPS por Caddy: 401 anónimo y 200 con Bearer; RTMP read autenticado.
- Passphrase SRT y token de publicación incorrectos rechazados.
- Republicación tras desconexión y metadatos/duración comprobados.
- Caddy sano como UID/GID 10003 y `CapEff=0`.
- Update bloqueado durante live y cuando la API está caída, antes de backup.
- ShellCheck, Hadolint, gosec y govulncheck limpios.
- Trivy limpio para ambos módulos, secretos/configuración y las cuatro imágenes
  construidas; también se escaneó la base del inicializador efímero.

Los comandos y versiones concretas quedan resumidos en
[TEST_REPORT.md](TEST_REPORT.md).

## Riesgo residual y trabajo pendiente

- GoPro HERO10/Quik, OBS, Twitch y un VPS Linux limpio siguen sin prueba física.
- Falta publicación de vídeo RTMPS completa con certificado público; solo hay
  evidencia histórica de handshake TLS local.
- No se ha ejecutado soak de 2 h, reinicio de host, pérdida/jitter, cambio de IP
  móvil ni medición audiovisual con patrón externo.
- No existe continuidad/fallback: un corte seguirá siendo visible hasta que el
  lector reconecte. Es alcance de Fase 2, no un bug oculto de Fase 1.
- Las imágenes están fijadas por versión, no por digest firmado. SBOM, firma,
  escaneo continuo y endurecimiento host pertenecen a la Fase 13.

## Dictamen

La implementación queda sensiblemente más robusta para laboratorio y ensayo:
los fallos reproducibles de configuración, actualización, privilegios y
cobertura de pruebas están corregidos. No debe declararse lista para un directo
de producción hasta completar la matriz física, de red y resistencia anterior.
