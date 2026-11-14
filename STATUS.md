# Estado

Actualizado: 2026-07-31

## Fase actual

**Fase 1 — Nodo IRL mínimo funcional (implementada y validada localmente;
validación física pendiente).**

La Fase 0 está cerrada documentalmente. La Fase 2 no ha comenzado.

## Terminado

- Arquitectura mononodo y límites de confianza documentados.
- Flujo GoPro Quik RTMP/RTMPS → MediaMTX → SRT/RTMP/HLS.
- MediaMTX 1.19.3 fijado y aislado en Docker.
- Autenticación externa con tokens distintos de publicación y lectura.
- SRT con passphrase obligatoria para lectores.
- API real de salud, disponibilidad, versión y proxy de estado multimedia.
- Caddy 2.11.4 para HTTPS/HLS.
- Configuración por entorno con validación al arrancar.
- Scripts operativos de instalación, prueba, diagnóstico, backup, restore y
  actualización.
- Pruebas unitarias de autenticación y prueba sintética reproducible.
- Ruta multimedia configurable verificada con un valor distinto de `irl`.
- Caddy no root y actualización bloqueada tanto en directo como si falla la
  consulta de estado.

## Pendiente

- Validar desde un VPS Linux limpio.
- Prueba física GoPro HERO10 + versión instalada de GoPro Quik.
- Prueba visual y auditiva en OBS Studio.
- Medición prolongada de sincronía y estabilidad.
- Fase 2: continuidad, fallback y supervisor de FFmpeg.
- Fases 3-15 del roadmap.

## Pruebas realizadas

- `go test -race` y `go vet`: correctos.
- Bash syntax y Compose producción/desarrollo: correctos.
- MediaMTX 1.19.3 y Caddy 2.11.4: configuración validada con binarios reales.
- Builds Docker arm64 y healthchecks de los tres servicios: correctos.
- RTMP → SRT cifrado: H.264 1280×720 30 fps + AAC 48 kHz, captura 3,018333 s.
- Token de publicación incorrecto: rechazado; auth registró `allowed=false`.
- Republicación tras desconexión: correcta.
- HLS público vía Caddy durante señal activa: 401 sin token y 200 con Bearer.
- SRT con passphrase errónea: rechazado; lectura RTMP autenticada: correcta.
- Gosec y govulncheck: sin hallazgos; Trivy del árbol: sin vulnerabilidades ni
  secretos de severidad alta/crítica tras las correcciones.
- Listener RTMPS estricto: handshake TLS correcto con certificado de prueba.
- Update durante señal activa: bloqueado antes de modificar servicios.
- Backup: archivo, listado y SHA-256 correctos.

Detalle y pruebas no ejecutadas: [docs/TEST_REPORT.md](docs/TEST_REPORT.md).

## Errores conocidos

- El complemento Compose no estaba instalado globalmente; se usó Compose 5.3.1
  standalone temporal para la validación.
- Compose advirtió que no había plugin Buildx y usó el builder clásico; los
  builds finalizaron correctamente.
- RTMPS requiere certificados legibles en `data/tls/` y no se activa por
  defecto para evitar un arranque parcialmente roto.

## Riesgos

- Quik puede variar por versión/sistema operativo; confirmar que conserva el
  query `?token=` en la URL antes del primer directo.
- SRT usa UDP; un firewall o NAT mal configurado produce timeouts sin handshake
  TCP visible.
- En Fase 1, si la fuente desaparece, el lector puede reconectar cuando vuelve,
  pero no existe una salida continua. Eso pertenece a Fase 2.
- Una prueba sintética no representa cobertura 4G/5G, temperatura ni batería.

## Próximo paso recomendado

Ejecutar la prueba sintética en Docker, después desplegar en un VPS de ensayo y
completar el checklist físico GoPro → OBS sin emitir a Twitch. Solo entonces
iniciar la Fase 2.
