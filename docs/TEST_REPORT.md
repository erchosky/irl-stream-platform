# Informe de pruebas — Fases 0 y 1

- Fecha: 2026-07-31
- Versión del proyecto: 0.1.1
- Host: macOS arm64
- Runtime: Colima, Docker client 29.6.1 / server 29.5.2
- Compose usado: 5.3.1 standalone temporal
- MediaMTX: 1.19.3
- Caddy: 2.11.4
- Go: 1.26.5
- FFmpeg de integración: 8.0.1 (Alpine 3.23)

El repositorio aún no tiene commit; por tanto no se inventa un SHA.

## Resultados ejecutados

| Prueba | Resultado | Evidencia resumida |
|---|---|---|
| `go test -race ./...` | PASS | matriz auth y validación de configuración |
| `go vet ./...` | PASS | sin diagnósticos |
| Bash `-n` | PASS | todos los scripts |
| Compose prod/dev `config --quiet` | PASS | Compose 5.3.1 |
| MediaMTX carga YAML | PASS | API `/v3/info`, versión 1.19.3 |
| Caddy `validate` + `adapt --validate` | PASS | configuración válida |
| Builds Docker arm64 | PASS | API, MediaMTX y Caddy persistentes no root |
| Healthchecks | PASS | tres contenedores `healthy` |
| RTMP válido → SRT cifrado | PASS | H.264 1280×720 30 fps + AAC 48 kHz; path `directo_a` |
| Duración/unión de captura | PASS | MPEG-TS ~3,03 s; entrada A/V dentro de un GOP de 2 s |
| Token RTMP incorrecto | PASS | auth `allowed=false`, ruta no disponible |
| Republicación | PASS | segunda captura H.264/AAC tras desconexión |
| HLS público sin token | PASS | HTTPS Caddy, HTTP 401 durante fuente activa |
| HLS público con Bearer | PASS | HTTPS Caddy, playlist HTTP 200 |
| SRT con passphrase errónea | PASS | lectura rechazada |
| RTMP read autenticado | PASS | captura aceptada con `READ_TOKEN` |
| Caddy no root | PASS | UID/GID 10003 y `CapEff=0` |
| Update sin API / durante live | PASS | ambos abortan antes de backup o mutación |
| Gosec + govulncheck | PASS | sin hallazgos/vulnerabilidades alcanzables |
| ShellCheck + Hadolint | PASS | scripts y cuatro Dockerfiles limpios |
| Trivy filesystem | PASS | dos módulos Go y cuatro Dockerfiles: 0 HIGH/CRITICAL, secretos o misconfiguraciones |
| Trivy imágenes | PASS | API, MediaMTX, Caddy, tester y base del init: 0 HIGH/CRITICAL |
| Caddy endurecido | PASS | v2.11.4 con Go 1.26.5, x/text 0.39.0 y gRPC 1.82.1; versión embebida correcta |
| RTMPS estricto | PASS parcial | listener TLS y certificado verificados con `openssl s_client`; no se publicó vídeo RTMPS |
| Backup + SHA-256 | PASS | archivo creado, checksum y listado verificados |

La primera carga histórica con `paths: irl:` detectó un `panic` al aplicar la
passphrase por variable de entorno. La auditoría 0.1.1 sustituyó la clave fija
por `all_others: {}`, movió la passphrase a `pathDefaults` y verificó una ruta
personalizada de extremo a extremo. La
primera ruta proxy HLS bajo `/hls` perdió la redirección de cookie de MediaMTX;
se cambió a la ruta nativa `/irl` y se verificó 401/200.

## No ejecutado

- GoPro HERO10/Quik física.
- OBS Studio real en macOS/Windows.
- Publicación de vídeo mediante RTMPS.
- Twitch.
- VPS Linux limpio y firewall externo.
- Prueba continua de 2 h o más.
- Reinicio de VPS.
- Pérdida, jitter, limitación y cambio de IP móvil.
- Sincronía medida con patrón audiovisual; se confirmó presencia y duración de
  ambos tracks, no un desfase perceptual.
- Restore destructivo; se verificaron checksum/listado y defensas del script,
  no se sobrescribió el workspace.

## Conclusión

La Fase 1 está validada localmente para el flujo sintético RTMP → SRT y para
HLS autenticado. No está validada todavía para el criterio físico
GoPro → VPS → OBS. La Fase 2 no debe comenzar hasta completar esa prueba.
