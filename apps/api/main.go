package main

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"syscall"
	"time"
)

var version = "dev"

var validMediaPath = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`)

const maxMediaAPIResponseBytes = 1 << 20

type config struct {
	ListenAddr   string
	MediaAPIURL  string
	MediaPath    string
	PublishToken string
	ReadToken    string
}

type authRequest struct {
	User      string `json:"user"`
	Password  string `json:"password"`
	Token     string `json:"token"`
	IP        string `json:"ip"`
	Action    string `json:"action"`
	Path      string `json:"path"`
	Protocol  string `json:"protocol"`
	ID        string `json:"id"`
	Query     string `json:"query"`
	UserAgent string `json:"userAgent"`
}

type mediaPathStatus struct {
	Name      string `json:"name"`
	Ready     bool   `json:"ready"`
	Available bool   `json:"available"`
	Online    bool   `json:"online"`
}

type mediaPathsResponse struct {
	Items []mediaPathStatus `json:"items"`
}

type server struct {
	cfg    config
	log    *slog.Logger
	client *http.Client
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		fmt.Fprintln(os.Stderr, "configuration error:", err)
		os.Exit(1)
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: parseLogLevel(os.Getenv("LOG_LEVEL")),
	}))
	s := &server{
		cfg: cfg,
		log: logger,
		client: &http.Client{
			Timeout: 3 * time.Second,
		},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("GET /readyz", s.ready)
	mux.HandleFunc("GET /version", s.version)
	mux.HandleFunc("POST /v1/media/auth", s.authorize)
	mux.HandleFunc("GET /v1/media/paths", s.paths)
	mux.HandleFunc("GET /v1/media/status", s.status)

	httpServer := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           requestLog(logger, securityHeaders(mux)),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}

	go func() {
		logger.Info("control API starting", "address", cfg.ListenAddr, "version", version)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("control API stopped unexpectedly", "error", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(ctx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}
	logger.Info("control API stopped")
}

func loadConfig() (config, error) {
	cfg := config{
		ListenAddr:   envOr("LISTEN_ADDR", ":8080"),
		MediaAPIURL:  strings.TrimRight(envOr("MEDIA_API_URL", "http://mediamtx:9997"), "/"),
		MediaPath:    envOr("MEDIA_PATH", "irl"),
		PublishToken: os.Getenv("PUBLISH_TOKEN"),
		ReadToken:    os.Getenv("READ_TOKEN"),
	}
	if len(cfg.PublishToken) < 32 {
		return config{}, errors.New("PUBLISH_TOKEN must contain at least 32 characters")
	}
	if len(cfg.ReadToken) < 32 {
		return config{}, errors.New("READ_TOKEN must contain at least 32 characters")
	}
	if secureEqual(cfg.PublishToken, cfg.ReadToken) {
		return config{}, errors.New("PUBLISH_TOKEN and READ_TOKEN must be different")
	}
	if !validMediaPath.MatchString(cfg.MediaPath) {
		return config{}, errors.New("MEDIA_PATH must be 1-64 characters using only letters, numbers, _ or -")
	}
	mediaURL, err := url.Parse(cfg.MediaAPIURL)
	if err != nil || (mediaURL.Scheme != "http" && mediaURL.Scheme != "https") ||
		mediaURL.Host == "" || mediaURL.User != nil || mediaURL.RawQuery != "" ||
		mediaURL.Fragment != "" || (mediaURL.Path != "" && mediaURL.Path != "/") {
		return config{}, errors.New("MEDIA_API_URL must be an HTTP(S) origin without credentials, path, query or fragment")
	}
	return cfg, nil
}

func envOr(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func parseLogLevel(value string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func (s *server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *server) ready(w http.ResponseWriter, r *http.Request) {
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, s.cfg.MediaAPIURL+"/v3/info", nil)
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	resp, err := s.client.Do(req)
	if err != nil {
		s.log.Warn("media API readiness failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	if resp.StatusCode != http.StatusOK {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (s *server) version(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"version": version})
}

func (s *server) authorize(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 16<<10)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	var request authRequest
	if err := decoder.Decode(&request); err != nil {
		s.log.Warn("malformed media auth request", "error", err)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		s.log.Warn("media auth request contains trailing data")
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}

	allowed := s.isAllowed(request)
	s.log.Info("media authorization",
		"allowed", allowed,
		"action", request.Action,
		"path", request.Path,
		"protocol", request.Protocol,
		"ip", request.IP,
		"connection_id", request.ID,
	)
	if !allowed {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) isAllowed(request authRequest) bool {
	if request.Path != s.cfg.MediaPath {
		return false
	}

	credential := request.Token
	if credential == "" {
		credential = request.Password
	}

	switch request.Action {
	case "publish":
		if request.Protocol != "rtmp" && request.Protocol != "srt" {
			return false
		}
		return secureEqual(credential, s.cfg.PublishToken)
	case "read":
		switch request.Protocol {
		case "srt", "rtmp", "hls":
			return secureEqual(credential, s.cfg.ReadToken)
		default:
			return false
		}
	default:
		return false
	}
}

func (s *server) paths(w http.ResponseWriter, r *http.Request) {
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, s.cfg.MediaAPIURL+"/v3/paths/list", nil)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "media_api_unavailable"})
		return
	}
	resp, err := s.client.Do(req)
	if err != nil {
		s.log.Warn("media paths request failed", "error", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "media_api_unavailable"})
		return
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, io.LimitReader(resp.Body, maxMediaAPIResponseBytes))
}

func (s *server) status(w http.ResponseWriter, r *http.Request) {
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, s.cfg.MediaAPIURL+"/v3/paths/list", nil)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "media_api_unavailable"})
		return
	}
	resp, err := s.client.Do(req)
	if err != nil {
		s.log.Warn("media status request failed", "error", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "media_api_unavailable"})
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "media_api_unavailable"})
		return
	}

	limited := io.LimitReader(resp.Body, maxMediaAPIResponseBytes+1)
	body, err := io.ReadAll(limited)
	if err != nil || len(body) > maxMediaAPIResponseBytes {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "invalid_media_api_response"})
		return
	}
	var paths mediaPathsResponse
	if err := json.Unmarshal(body, &paths); err != nil {
		s.log.Warn("invalid media status response", "error", err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "invalid_media_api_response"})
		return
	}

	result := mediaPathStatus{Name: s.cfg.MediaPath}
	for _, path := range paths.Items {
		if path.Name == s.cfg.MediaPath {
			result = path
			break
		}
	}
	writeJSON(w, http.StatusOK, result)
}

func secureEqual(left, right string) bool {
	if len(left) != len(right) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(left), []byte(right)) == 1
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		next.ServeHTTP(w, r)
	})
}

func requestLog(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		if r.URL.Path != "/healthz" {
			logger.Debug("request",
				"method", r.Method,
				"path", r.URL.Path,
				"duration_ms", time.Since(start).Milliseconds(),
			)
		}
	})
}
