package main

import (
    "database/sql"
    "fmt"
    _ "github.com/GoogleCloudPlatform/cloudsql-proxy/proxy/dialers/postgres"
    _ "github.com/lib/pq"
    "log"
    "os"
)

// DB vars
var db *sql.DB
// Initialzing the database connection parameters on app startup
var configMap = dbConfig()

// DB struct
type Users struct {
    Name     string `sql:"size:64"`
    Birthday string
}

// Generates db connection string
func dbConfig() map[string]string {
    configMap := make(map[string]string)

    configMap["connectionType"] = "postgres"
    host, ok := os.LookupEnv("DBHOST")
    if !ok {
        log.Println("DBHOST environment variable isn't set, using default")
        host = "127.0.0.1"
    }
    port, ok := os.LookupEnv("DBPORT")
    if !ok {
        log.Println("DBPORT environment variable isn't set, using default")
        port = "5432"
    }
    user, ok := os.LookupEnv("DBUSER")
    if !ok {
        log.Println("DBUSER environment variable isn't set, using default")
        user = "hello"
    }
    password, ok := os.LookupEnv("DBPASS")
    if !ok {
        log.Println("DBPASS environment variable isn't set, using default")
        password = ""
    }
    dbname, ok := os.LookupEnv("DBNAME")
    if !ok {
        log.Println("DBNAME environment variable isn't set, using default")
        dbname = "hello"
    }
    // Swith to cloudsql connection if CLOUDSQL is set
    cloudsql, ok := os.LookupEnv("CLOUDSQL")
    if ok {
        log.Println("Using CLOUDSQL connection type")
        host = cloudsql
        configMap["connectionType"] = "cloudsqlpostgres"
    }
    
    configMap["connectionParams"] = fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable", host, port, user, password, dbname)
    return configMap
}

// Database connection function
func connectDb() (*sql.DB, error) {
    db, err := sql.Open(configMap["connectionType"], configMap["connectionParams"])
    if err != nil {
        log.Println("DB connection failed", err)
    } else {
        return db, err
    }
    return db, err
}

// Initialzing the database table and trigger
func initDb() {
    db, err := connectDb()
    if err != nil {
        log.Println("DB connection failed")
    } else {
        log.Println("Successfully connected to DB")
    }

    defer db.Close()

    _, err = db.Exec("SELECT 1")
    if err != nil {
        log.Println("Database ping failed", err)
    } else {
        log.Println("Database ping OK")
    }

    sql := `CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    name     VARCHAR(64) UNIQUE NOT NULL,
                    birthday VARCHAR(10) NOT NULL,
                    created_on TIMESTAMP NOT NULL DEFAULT NOW(),
                    updated_on TIMESTAMP NOT NULL DEFAULT NOW()
            );`

    trigger := `CREATE OR REPLACE FUNCTION ts_update()
                    RETURNS TRIGGER AS 
                    $$
                    BEGIN
                      NEW.updated_on = NOW();
                      RETURN NEW;
                    END;
                    $$ 
                    LANGUAGE plpgsql;

                DROP TRIGGER IF EXISTS ts_update ON users;

                CREATE TRIGGER ts_update
                    BEFORE UPDATE ON users
                    FOR EACH ROW
                    EXECUTE PROCEDURE ts_update();`

    _, dberr := db.Exec(sql)
    if dberr != nil {
        log.Println("Database table creating failed", dberr)
    } else {
        log.Println("Database table is created")
    }
    _, trerr := db.Exec(trigger)
    if trerr != nil {
        log.Println("Trigger creation failed", trerr)
    } else {
        log.Println("Trigger is created")
    }
}
