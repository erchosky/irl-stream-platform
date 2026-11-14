# ADR-0001: MediaMTX como plano multimedia

- Estado: aceptada
- Fecha: 2026-07-29

## Contexto

Se requiere RTMP/RTMPS desde Quik y SRT hacia OBS sin escribir un servidor de
medios.

## Decisión

Usar MediaMTX 1.19.3. Convierte protocolos sin transcodificar, soporta
autenticación externa, métricas, API, RTMP(S), SRT y HLS en un binario.

## Alternativas

- **SRS**: muy capaz para RTMP/HLS/WebRTC y clústeres, pero mayor superficie y
  complejidad para este mononodo.
- **OvenMediaEngine**: fuerte en WebRTC de baja latencia; no es la prioridad.
- **Nginx-RTMP**: simple, pero SRT, API y autenticación requieren más piezas.

## Consecuencias

La compatibilidad de códecs sigue limitada por cada protocolo. Se fija la
versión y se prueba antes de actualizar. La continuidad avanzada no se delega
sin validación a una única opción de MediaMTX.

