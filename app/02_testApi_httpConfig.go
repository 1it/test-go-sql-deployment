package main

import (
    "log"
    "os"
)

// Http vars
var httpPath = "/hello/"
//var HealthCheckPathHttp = "/health/"
var HealthCheckPath = "/health/"
var contentType = "Content-Type"
var appJson = "application/json"
var textPlain = "text/plain"

// HTTP Log messages
var dbError = "Could not connect to the database"
var httpErrorWrongInput = "Wrong input. Please, avoid numeric characters"
var httpErrorWrongInputDate = "Invalid dateOfBirth value (YYYY-MM-DD)"
var httpErrorWrongDate = "Invalid dateOfBirth value (Not today)"

func initConfig() string {
    httpHost, ok := os.LookupEnv("HTTPHOST")
    if !ok {
        httpHost = "0.0.0.0"
        log.Println("HTTPHOST environment variable is not set, using default value 0.0.0.0")
    }
    httpPort, ok := os.LookupEnv("HTTPPORT")
    if !ok {
        httpPort = "9000"
        log.Println("HTTPPORT environment variable is not set, using default value 9000")   
    }

    httpServer := httpHost + ":" + httpPort

    return httpServer
}