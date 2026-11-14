#!/usr/bin/env bash
set -euo pipefail

for variable in MEDIA_PATH PUBLIC_HOST PUBLISH_TOKEN READ_TOKEN SRT_READ_PASSPHRASE SRT_LATENCY_US; do
  if [[ -z "${!variable:-}" ]]; then
    echo "ERROR: required variable ${variable} is empty" >&2
    exit 1
  fi
done

publish_url="rtmp://mediamtx:1935/${MEDIA_PATH}?token=${PUBLISH_TOKEN}"
bad_publish_url="rtmp://mediamtx:1935/${MEDIA_PATH}?token=invalid-token-that-must-be-rejected"
srt_url="srt://mediamtx:8890?streamid=read:${MEDIA_PATH}:reader:${READ_TOKEN}&passphrase=${SRT_READ_PASSPHRASE}&latency=${SRT_LATENCY_US}"
hls_url="https://${PUBLIC_HOST}:8443/${MEDIA_PATH}/index.m3u8"
rtmp_read_url="rtmp://mediamtx:1935/${MEDIA_PATH}?token=${READ_TOKEN}"
capture_file="/tmp/capture.ts"
publisher_log="/tmp/publisher.log"
bad_key_log="/tmp/bad-key.log"

cleanup() {
  if [[ -n "${publisher_pid:-}" ]]; then
    kill "${publisher_pid}" 2>/dev/null || true
    wait "${publisher_pid}" 2>/dev/null || true
  fi
  if [[ -n "${bad_key_pid:-}" ]]; then
    kill "${bad_key_pid}" 2>/dev/null || true
    wait "${bad_key_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

start_publisher() {
  ffmpeg -hide_banner -loglevel warning -re \
    -f lavfi -i "testsrc2=size=1280x720:rate=30" \
    -f lavfi -i "sine=frequency=1000:sample_rate=48000" \
    -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p \
    -profile:v main -g 60 -keyint_min 60 -sc_threshold 0 -b:v 2500k \
    -c:a aac -ar 48000 -ac 2 -b:a 128k \
    -t 30 -f flv "${publish_url}" >"${publisher_log}" 2>&1 &
  publisher_pid=$!
}

stop_publisher() {
  kill "${publisher_pid}" 2>/dev/null || true
  wait "${publisher_pid}" 2>/dev/null || true
  unset publisher_pid
}

probe_stream() {
  rm -f "${capture_file}"
  local _
  for _ in $(seq 1 12); do
    if timeout 8 ffmpeg -hide_banner -loglevel error -y -i "${srt_url}" \
      -t 3 -c copy "${capture_file}" >/tmp/reader.log 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: SRT stream was not readable" >&2
  sed -n '1,80p' /tmp/reader.log >&2 || true
  return 1
}

assert_tracks() {
  local video_codec audio_codec width height frame_rate sample_rate
  video_codec="$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name -of default=nw=1:nk=1 "${capture_file}" |
    tail -n 1)"
  audio_codec="$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_name -of default=nw=1:nk=1 "${capture_file}" |
    tail -n 1)"
  width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "${capture_file}" | tail -n 1)"
  height="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "${capture_file}" | tail -n 1)"
  frame_rate="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "${capture_file}" | tail -n 1)"
  sample_rate="$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=nw=1:nk=1 "${capture_file}" | tail -n 1)"
  [[ "${video_codec}" == "h264" && "${audio_codec}" == "aac" ]] || {
    echo "ERROR: expected H.264/AAC, got ${video_codec:-none}/${audio_codec:-none}" >&2
    exit 1
  }
  [[ "${width}" == "1280" && "${height}" == "720" && "${frame_rate}" == "30/1" ]] || {
    echo "ERROR: unexpected video format ${width}x${height} ${frame_rate}" >&2
    exit 1
  }
  [[ "${sample_rate}" == "48000" ]] || {
    echo "ERROR: unexpected audio sample rate ${sample_rate}" >&2
    exit 1
  }
  echo "PASS tracks video=${video_codec} ${width}x${height}@30 audio=${audio_codec} ${sample_rate}Hz"
}

assert_duration_and_sync() {
  local duration video_start audio_start
  duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "${capture_file}" | tail -n 1)"
  video_start="$(ffprobe -v error -select_streams v:0 -show_entries stream=start_time -of default=nw=1:nk=1 "${capture_file}" | tail -n 1)"
  audio_start="$(ffprobe -v error -select_streams a:0 -show_entries stream=start_time -of default=nw=1:nk=1 "${capture_file}" | tail -n 1)"
  awk -v duration="${duration}" 'BEGIN { exit !(duration >= 2.5 && duration <= 4.5) }' || {
    echo "ERROR: capture duration ${duration}s is outside 2.5-4.5s" >&2
    exit 1
  }
  # A reader can join between keyframes. With the configured two-second GOP,
  # the first decodable video PTS can legitimately trail audio by one GOP.
  awk -v video="${video_start}" -v audio="${audio_start}" \
    'BEGIN { delta=video-audio; if (delta < 0) delta=-delta; exit !(delta <= 2.1) }' || {
    echo "ERROR: A/V start delta exceeds one 2s GOP (video=${video_start}, audio=${audio_start})" >&2
    exit 1
  }
  echo "PASS duration=${duration}s A/V join delta <= one 2s GOP"
}

assert_hls_auth() {
  local _ unauth_status auth_status
  unauth_status=""
  auth_status=""
  for _ in $(seq 1 20); do
    rm -f /tmp/hls-unauth.cookies /tmp/hls-auth.cookies
    unauth_status="$(curl --silent --location --output /dev/null --write-out '%{http_code}' \
      --cookie-jar /tmp/hls-unauth.cookies --cookie /tmp/hls-unauth.cookies \
      --insecure --connect-to "${PUBLIC_HOST}:8443:gateway:8443" \
      --max-time 3 "${hls_url}" || true)"
    auth_status="$(curl --silent --location --output /tmp/index.m3u8 --write-out '%{http_code}' \
      --cookie-jar /tmp/hls-auth.cookies --cookie /tmp/hls-auth.cookies \
      --insecure --connect-to "${PUBLIC_HOST}:8443:gateway:8443" \
      --max-time 3 --header "Authorization: Bearer ${READ_TOKEN}" "${hls_url}" || true)"
    if [[ "${unauth_status}" == "401" && "${auth_status}" == "200" ]]; then
      grep -q '^#EXTM3U' /tmp/index.m3u8 || {
        echo "ERROR: authenticated HLS response is not a playlist" >&2
        exit 1
      }
      echo "PASS HLS rejects anonymous access and accepts the read token"
      return 0
    fi
    sleep 0.5
  done
  echo "ERROR: expected HLS 401/200, got ${unauth_status}/${auth_status}" >&2
  return 1
}

assert_wrong_srt_passphrase_rejected() {
  local bad_srt_url
  bad_srt_url="srt://mediamtx:8890?streamid=read:${MEDIA_PATH}:reader:${READ_TOKEN}&passphrase=wrong-passphrase-0123456789&latency=${SRT_LATENCY_US}"
  if timeout 5 ffmpeg -hide_banner -loglevel error -y -i "${bad_srt_url}" \
    -t 1 -c copy /tmp/bad-srt.ts >/tmp/bad-srt.log 2>&1; then
    echo "ERROR: SRT read succeeded with a wrong passphrase" >&2
    return 1
  fi
  echo "PASS wrong SRT passphrase rejected"
}

assert_rtmp_read() {
  rm -f /tmp/rtmp-read.flv
  if ! timeout 8 ffmpeg -hide_banner -loglevel error -y -i "${rtmp_read_url}" \
    -t 1 -c copy -f flv /tmp/rtmp-read.flv >/tmp/rtmp-read.log 2>&1; then
    echo "ERROR: authenticated RTMP read failed" >&2
    sed -n '1,40p' /tmp/rtmp-read.log >&2 || true
    return 1
  fi
  echo "PASS authenticated RTMP read"
}

wait_until_offline() {
  local _
  for _ in $(seq 1 20); do
    if ! curl -fsS "http://control-api:8080/v1/media/paths" |
      grep -q '"available":true'; then
      return 0
    fi
    sleep 0.25
  done
  echo "ERROR: media path did not become unavailable" >&2
  return 1
}

echo "TEST 1/7: valid RTMP publish and encrypted SRT read"
start_publisher
probe_stream
assert_tracks
assert_duration_and_sync

echo "TEST 2/7: HLS authentication"
assert_hls_auth

echo "TEST 3/7: SRT encryption rejects a wrong passphrase"
assert_wrong_srt_passphrase_rejected
stop_publisher
wait_until_offline

echo "TEST 4/7: invalid publish token is rejected"
ffmpeg -hide_banner -loglevel error -re \
  -f lavfi -i "testsrc2=size=320x180:rate=10" \
  -t 8 -c:v libx264 -preset ultrafast -an -f flv "${bad_publish_url}" \
  >"${bad_key_log}" 2>&1 &
bad_key_pid=$!
for _ in $(seq 1 24); do
  if curl -fsS "http://control-api:8080/v1/media/paths" |
    grep -q '"available":true'; then
    kill "${bad_key_pid}" 2>/dev/null || true
    wait "${bad_key_pid}" 2>/dev/null || true
    echo "ERROR: MediaMTX made the path available with an invalid token" >&2
    exit 1
  fi
  if ! kill -0 "${bad_key_pid}" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
wait "${bad_key_pid}" 2>/dev/null || true
unset bad_key_pid
echo "PASS invalid token rejected"

echo "TEST 5/7: publication recovers after source reconnect"
start_publisher
probe_stream
assert_tracks

echo "TEST 6/7: authenticated RTMP read"
assert_rtmp_read
stop_publisher
echo "PASS source republished"

echo "TEST 7/7: captured metadata"
ffprobe -v error -show_entries \
  stream=index,codec_name,codec_type,width,height,r_frame_rate,sample_rate \
  -show_entries format=duration -of json "${capture_file}"

echo "PASS synthetic RTMP -> encrypted SRT flow"
