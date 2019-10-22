package main

// DB Check query
type Query struct {
	Name     string
	Birthday string
}

// Input json
type BirthDate struct {
	Birthday string `json:"dateOfBirth"`
}

// HTTP response
type JSONMessage struct {
	Message string `json:"message"`
}
