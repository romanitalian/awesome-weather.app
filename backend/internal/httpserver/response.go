package httpserver

import (
	"encoding/json"
	"net/http"
)

type errorRS struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code string, message string, details interface{}) {
	writeJSON(w, status, errorRS{Code: code, Message: message, Details: details})
}
