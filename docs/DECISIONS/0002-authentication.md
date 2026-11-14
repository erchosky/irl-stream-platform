# ADR-0002: Autenticación HTTP externa con tokens opacos

- Estado: aceptada
- Fecha: 2026-07-29

## Decisión

Un servicio Go pequeño valida `publish` y `read` para una ruta exacta y
protocolos permitidos. Publicación y lectura tienen secretos distintos. Los
tokens no se guardan en el YAML ni en la ruta.

## Razón

Quik permite pegar una URL RTMP completa. MediaMTX reenvía el query `token` a
su autenticador; SRT transporta el token como password en `streamid`. Esto evita
publicar la clave como nombre de stream, que aparecería en logs.

## Consecuencias

El autenticador es dependencia de disponibilidad y tiene healthcheck. La
rotación recrea servicios. JWT/roles no aportan valor aún.

