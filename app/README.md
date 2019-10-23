# Go helloAPI

This is an example API application written in Go which uses PostgreSQL as a database.  
Application supports GCP Cloud SQL proxy connection out of the box. It uses [CloudSQL Proxy](https://github.com/GoogleCloudPlatform/cloudsql-proxy/) library, and in particular [CloudSQL Proxy Dialer](https://github.com/GoogleCloudPlatform/cloudsql-proxy/tree/master/proxy/dialers/postgres)

## Dependencies
```go
// PostgreSQL
import (
    "database/sql"
    "github.com/GoogleCloudPlatform/cloudsql-proxy/proxy/dialers/postgres"
    "github.com/lib/pq"
)
// HTTP 
import (
    "encoding/json"
    "github.com/gorilla/handlers"
    "github.com/gorilla/mux"
    "net/http"
)
// etc
import (
    "fmt"
    "io"
    "log"
    "os"
    "regexp"
    "strings"
)
```

## Configuration
Application uses environment variables to configure the connection to database and to choose the HTTP port and address.  
**Default parameters are:**
```bash
# Default postgres parameters
DBHOST=postgres
DBPORT=5432
DBUSER=hello
DBPASS=hellopasswd
DBNAME=hello
# Cloud SQL connection string (must be empty for local environment)
CLOUDSQL=gcp-project-name:gcp-region:sql-instance-name
# GCP Service account credentials file (the SA must have role binding: 'roles/cloudsql.client')
GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa-account-file.json
# HTTP service parameters (optional, can be empty)
HTTPHOST=0.0.0.0
HTTPPORT=9000
```

**Cloud SQL Service account creation process:**
```bash
GCP_PROJECT=your-project-name
SQL_SA_NAME=sql-test-client
SQL_SA_FULLNAME=${SQL_SA_NAME}@${GCP_PROJECT}.iam.gserviceaccount.com
ROLE='roles/cloudsql.client'
FILE=sa-sql-client.json

gcloud iam service-accounts create "$SQL_SA_NAME" --display-name "$SQL_SA_NAME"

gcloud projects add-iam-policy-binding "$GCP_PROJECT" --member serviceAccount:"$SQL_SA_FULLNAME" --role "$ROLE"

gcloud iam service-accounts keys create "$FILE" --iam-account "$SQL_SA_FULLNAME"
```

## HTTP Routes
**Request: PUT /hello/{username}**  
JSON Input Data Format: { "dateOfBirth": "YYYY-MM-DD" }  
Response: 204 No Content  
{username} - must be letters only.  
dateOfBirth - YYYY-MM-DD - must be a valid before today.  

**Request: GET /hello/{username}**  
Response: 200 OK  
Returns message with the user's number of days to birthday. Only if the user exists in the database, otherwise the service will return:  
`User {username}, is not in database`

**Request: GET /health/**
Response: 200 OK  
Returns the current service health information. If service is up and can connect to the database it will return:  
```json
{"Service is healthy": true}
```
Otherwise it will return:
```json
{"Service is healthy": false}
```