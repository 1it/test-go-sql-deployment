package main

import (
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestHealthCheck(t *testing.T) {
    req, err := http.NewRequest("GET", "/health", nil)
    if err != nil {
        t.Fatal(err)
    }
    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(HealthCheck)
    handler.ServeHTTP(rr, req)
    if status := rr.Code; status != http.StatusOK {
        t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
    }
}

func TestGetWrongEntry(t *testing.T) {
    req, err := http.NewRequest("GET", "/hello/Test1", nil)
    if err != nil {
        t.Fatal(err)
    }
    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(GetEntry)
    handler.ServeHTTP(rr, req)
    if status := rr.Code; status != 422 {
        t.Errorf("handler returned wrong status code: got %v want %d", status, 422)
    }
}

func TestGetEmptyEntry(t *testing.T) {
    req, err := http.NewRequest("GET", "/hello/", nil)
    if err != nil {
        t.Fatal(err)
    }
    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(GetEntry)
    handler.ServeHTTP(rr, req)
    if status := rr.Code; status != 200 {
        t.Errorf("handler returned wrong status code: got %v want %d", status, 200)
    }
}