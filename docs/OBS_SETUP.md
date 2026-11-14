# OBS Studio

## SRT preferente

1. Crea una escena `IRL`.
2. Añade **Fuente multimedia**.
3. Desmarca **Archivo local**.
4. En entrada usa una única línea:

   ```text
   srt://HOST:8890?streamid=read:irl:reader:READ_TOKEN&passphrase=SRT_READ_PASSPHRASE&latency=2000000
   ```

5. En formato de entrada escribe `mpegts`.
6. Si tu versión muestra opciones de reconexión, actívalas.

OBS documenta SRT caller como modo normal de lectura. `latency=2000000`
(2 segundos) es un inicio conservador para Internet móvil; prueba 1-4 s y no lo
reduzcas hasta tener evidencia. MediaMTX escucha como servidor.

## Alternativas

RTMP:

```text
rtmp://HOST:1935/irl?token=READ_TOKEN
```

HLS (más latencia y autenticación Bearer):

```text
https://PUBLIC_HOST/irl/index.m3u8
```

La fuente multimedia de OBS puede proporcionar **Bearer Token** en versiones
compatibles; introduce `READ_TOKEN`. HLS es preview/contingencia, no salida
preferente.

## Escenas

- `IRL`: fuente SRT y overlays mínimos.
- `BRB`: contenido local independiente del nodo.
- `EMERGENCIA`: imagen/audio local, sin depender de Internet.

En Fase 1 el cambio es manual. Fase 5 lo controlará mediante un agente local;
no abras OBS WebSocket 4455 en el router/firewall.

## Audio y vídeo

- Mantén salida OBS a 48 kHz; la prueba sintética usa AAC 48 kHz.
- Ajusta resolución de lienzo/salida a tu perfil Twitch, no fuerces
  transcodificación en el nodo.
- Si hay desfase constante, mídelo antes de aplicar “desfase de sincronización”
  y documenta el valor por perfil.

## Diagnóstico

- Pantalla negra: comprueba estado de path, token, passphrase, UDP 8890 y
  `mpegts`; desactiva/activa la fuente.
- Sin audio: mira medidores y propiedades avanzadas; confirma que la entrada
  contiene track AAC.
- Cortes: aumenta SRT latency; prueba por cable entre VPS/OBS si es posible.
- No reconecta: añade `timeout=5000000` solo si tu versión lo necesita, como
  sugiere la guía oficial, y prueba el comportamiento.

## Checklist antes del directo

- [ ] `./scripts/health-check.sh` y prueba sintética correctos.
- [ ] GoPro visible y audible durante 15 min.
- [ ] Escenas IRL/BRB/EMERGENCIA comprobadas.
- [ ] Twitch en modo de prueba/inspector antes de publicar.
- [ ] Grabación local de OBS con espacio suficiente.
- [ ] Tokens no visibles en capturas.
- [ ] CPU, red y audio revisados.
