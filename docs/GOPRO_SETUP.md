# GoPro HERO10 Black + GoPro Quik

Verificado contra la guía y el manual oficiales enlazados en
[SOURCES.md](SOURCES.md). La interfaz exacta cambia entre versiones de Quik:
confirma nombres y disponibilidad en tu móvil; no se asume SRT directo.

## Preparación

1. Actualiza la HERO10 con firmware oficial y carga batería/Media Mod si aplica.
2. Inserta una microSD compatible aunque no vayas a guardar una copia.
3. Empareja cámara y móvil en GoPro Quik.
4. Asegura conectividad del móvil. Dependiendo del sistema, la cámara usa Wi‑Fi
   con el teléfono y este necesita datos móviles/hotspot disponible.
5. En el panel de control de cámara de Quik, abre **Live / Set Up Live** y elige
   **RTMP**.

GoPro confirma opciones 480p, 720p y 1080p para modelos compatibles, incluida
HERO10. No documenta en esa guía un control manual exacto de bitrate; Quik puede
reducirlo con señal débil.

## URL

Quik solicita una sola URL que combine servidor y stream name/key. Para
laboratorio:

```text
rtmp://TU_HOST:1935/irl?token=TU_PUBLISH_TOKEN
```

Para producción, tras instalar un certificado válido:

```text
rtmps://TU_DOMINIO:1936/irl?token=TU_PUBLISH_TOKEN
```

Aquí `irl` es el nombre del stream y `PUBLISH_TOKEN` actúa como stream key. No
añadas espacios ni una barra final. No compartas la URL.

## Primer perfil recomendado

- Empieza en **720p** para una prueba móvil; sube a 1080p solo tras medir
  cobertura, temperatura y consumo.
- Activa guardar copia de alta resolución en SD si necesitas un master local y
  dispones de espacio/batería.
- No se fija un bitrate inexistente en la interfaz. Observa el bitrate real en
  métricas cuando esté disponible.

Consumo orientativo, no garantía: cada 1 Mbit/s sostenido equivale a unos
0,45 GB/h; añade aproximadamente 10-20 % por audio y overhead. Ejemplo:
6 Mbit/s de media ≈ 2,7 GB/h antes del overhead. Mídelo con tu operador.

## Prueba sin Twitch

1. Arranca el nodo y ejecuta `./scripts/health-check.sh`.
2. Configura Quik con la URL anterior.
3. Inicia el live en Quik. No abras una emisión en Twitch.
4. En el VPS ejecuta:

   ```bash
   curl -fsS http://127.0.0.1:8080/v1/media/paths
   ```

5. Añade el SRT a una **Fuente multimedia** de OBS según
   [OBS_SETUP.md](OBS_SETUP.md).
6. Verifica movimiento, audio, sincronía y estabilidad durante 15 minutos.

## Cortes y recuperación en Fase 1

Si Quik pierde cobertura, MediaMTX deja de disponer de la ruta y OBS puede
quedar en negro o reconectar. Al volver, inicia/reanuda la emisión en Quik; OBS
debe volver a abrir la fuente. La pantalla de reconexión automática y una
salida continua aún no existen: son Fase 2.

## Batería, temperatura y red

- Evita sol directo y carcasas cerradas durante pruebas prolongadas.
- Alimentación USB puede aumentar temperatura; prueba el conjunto completo.
- Desactiva funciones inalámbricas del móvil que provoquen cambios de red.
- Usa un plan de datos sin reducción severa y deja margen de subida: objetivo
  prudente ≥2 veces el bitrate medio medido.
- Sujeta conectores y batería externa; no confíes en una única prueba estática.

## Errores comunes

- **URL no válida**: confirma `rtmp://` o `rtmps://`, puerto, `/irl` y query.
- **Unauthorized**: token truncado/rotado; no uses `READ_TOKEN` para Quik.
- **Conecta en Wi‑Fi pero no en 4G/5G**: revisa firewall, CGNAT no afecta una
  conexión saliente, y DNS IPv4/IPv6.
- **RTMPS falla**: nombre del certificado, cadena intermedia, fecha del móvil y
  puerto 1936.
- **Se corta al bloquear el móvil**: revisa permisos de datos/batería de Quik y
  mantén la app en primer plano durante la prueba.
- **Sobrecalentamiento**: baja resolución, mejora ventilación y prueba otra
  estrategia de alimentación.

## Checklist físico pendiente

- [ ] Registrar versión de Quik, iOS/Android y firmware.
- [ ] Confirmar que Quik conserva `?token=`.
- [ ] Probar RTMP y RTMPS por separado.
- [ ] Cambiar entre Wi‑Fi y 4G/5G.
- [ ] Medir datos, temperatura y batería durante 60 min.
- [ ] Verificar recuperación desde OBS sin tocar el servidor.

