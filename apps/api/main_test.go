package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

const (
	testPublishToken = "publish_0123456789abcdef0123456789abcdef"
	testReadToken    = "reader__0123456789abcdef0123456789abcdef"
)

func testServer() *server {
	return &server{
		cfg: config{
			MediaPath:    "irl",
			PublishToken: testPublishToken,
			ReadToken:    testReadToken,
		},
		log: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
}

func TestAuthorizationMatrix(t *testing.T) {
	tests := []struct {
		name     string
		request  authRequest
		expected bool
	}{
		{"RTMP publisher", authRequest{Action: "publish", Path: "irl", Protocol: "rtmp", Token: testPublishToken}, true},
		{"SRT publisher password", authRequest{Action: "publish", Path: "irl", Protocol: "srt", Password: testPublishToken}, true},
		{"SRT reader", authRequest{Action: "read", Path: "irl", Protocol: "srt", Password: testReadToken}, true},
		{"RTMP reader", authRequest{Action: "read", Path: "irl", Protocol: "rtmp", Token: testReadToken}, true},
		{"HLS reader", authRequest{Action: "read", Path: "irl", Protocol: "hls", Token: testReadToken}, true},
		{"wrong publish token", authRequest{Action: "publish", Path: "irl", Protocol: "rtmp", Token: testReadToken}, false},
		{"wrong path", authRequest{Action: "publish", Path: "other", Protocol: "rtmp", Token: testPublishToken}, false},
		{"unsupported protocol", authRequest{Action: "publish", Path: "irl", Protocol: "webrtc", Token: testPublishToken}, false},
		{"administrative action", authRequest{Action: "api", Path: "irl", Protocol: "rtmp", Token: testPublishToken}, false},
	}

	s := testServer()
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if actual := s.isAllowed(tt.request); actual != tt.expected {
				t.Fatalf("expected %v, got %v", tt.expected, actual)
			}
		})
	}
}

func TestAuthorizeHandler(t *testing.T) {
	s := testServer()
	payload, err := json.Marshal(authRequest{
		Action:   "publish",
		Path:     "irl",
		Protocol: "rtmp",
		Token:    testPublishToken,
	})
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodPost, "/v1/media/auth", bytes.NewReader(payload))
	res := httptest.NewRecorder()
	s.authorize(res, req)
	if res.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d: %s", res.Code, res.Body.String())
	}
}

func TestAuthorizeRejectsUnknownFields(t *testing.T) {
	s := testServer()
	req := httptest.NewRequest(http.MethodPost, "/v1/media/auth", bytes.NewBufferString(`{"path":"irl","unexpected":true}`))
	res := httptest.NewRecorder()
	s.authorize(res, req)
	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", res.Code)
	}
}

func TestAuthorizeRejectsTrailingJSON(t *testing.T) {
	s := testServer()
	req := httptest.NewRequest(http.MethodPost, "/v1/media/auth", strings.NewReader(
		`{"action":"publish","path":"irl","protocol":"rtmp","token":"`+testPublishToken+`"}{}`,
	))
	res := httptest.NewRecorder()
	s.authorize(res, req)
	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", res.Code)
	}
}

func TestStatusNormalizesConfiguredPath(t *testing.T) {
	mediaAPI := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v3/paths/list" {
			t.Fatalf("unexpected upstream path: %s", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"items":[{"name":"other","online":true},{"name":"irl","ready":true,"available":true,"online":true}]}`)
	}))
	defer mediaAPI.Close()

	s := testServer()
	s.cfg.MediaAPIURL = mediaAPI.URL
	s.client = mediaAPI.Client()
	req := httptest.NewRequest(http.MethodGet, "/v1/media/status", nil)
	res := httptest.NewRecorder()
	s.status(res, req)
	if res.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", res.Code, res.Body.String())
	}
	var got mediaPathStatus
	if err := json.Unmarshal(res.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got.Name != "irl" || !got.Ready || !got.Available || !got.Online {
		t.Fatalf("unexpected status: %+v", got)
	}
}

func TestStatusFailsClosedOnInvalidUpstream(t *testing.T) {
	mediaAPI := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, `{not-json`)
	}))
	defer mediaAPI.Close()

	s := testServer()
	s.cfg.MediaAPIURL = mediaAPI.URL
	s.client = mediaAPI.Client()
	res := httptest.NewRecorder()
	s.status(res, httptest.NewRequest(http.MethodGet, "/v1/media/status", nil))
	if res.Code != http.StatusBadGateway {
		t.Fatalf("expected 502, got %d", res.Code)
	}
}

func TestLoadConfigRejectsUnsafeSecrets(t *testing.T) {
	t.Setenv("PUBLISH_TOKEN", "short")
	t.Setenv("READ_TOKEN", testReadToken)
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected short token to be rejected")
	}

	t.Setenv("PUBLISH_TOKEN", testPublishToken)
	t.Setenv("READ_TOKEN", testPublishToken)
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected identical tokens to be rejected")
	}
}

func TestLoadConfigRejectsInvalidPathAndMediaURL(t *testing.T) {
	t.Setenv("PUBLISH_TOKEN", testPublishToken)
	t.Setenv("READ_TOKEN", testReadToken)
	t.Setenv("MEDIA_PATH", "../irl")
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected unsafe media path to be rejected")
	}

	t.Setenv("MEDIA_PATH", "directo_1")
	t.Setenv("MEDIA_API_URL", "http://user:pass@mediamtx:9997/path?secret=yes")
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected unsafe media API URL to be rejected")
	}
}

func TestMain(m *testing.M) {
	os.Exit(m.Run())
}
