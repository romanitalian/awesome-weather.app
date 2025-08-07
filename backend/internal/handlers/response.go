package handlers

import (
	"encoding/json"
	"net/http"
)

type errorRS struct {
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Details map[string]string `json:"details,omitempty"`
}

func writeError(w http.ResponseWriter, status int, code string, message string, details map[string]string) {
	b, _ := json.Marshal(errorRS{Code: code, Message: message, Details: details})
	writeJSONBytes(w, status, b)
}

func writeJSONBytes(w http.ResponseWriter, status int, b []byte) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(b)
}
