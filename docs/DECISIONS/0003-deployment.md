# ADR-0003: Mononodo modular con Docker Compose

- Estado: aceptada
- Fecha: 2026-07-29

## Decisión

Desplegar Caddy, MediaMTX y API Go en un VPS Linux mediante Compose. Mantener
red interna para control y una red gateway para medios/HTTPS.

## Razón

Es reproducible y portátil sin introducir Kubernetes, Redis, PostgreSQL ni una
cola antes de tener carga que lo justifique.

## Consecuencias

El VPS es un único punto de fallo. Backups protegen configuración, no alta
disponibilidad. Las URLs internas permiten separar nodos más adelante.

