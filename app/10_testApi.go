package main

import (
    "database/sql"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "regexp"
    "strings"
)

import (
    "github.com/gorilla/handlers"
    "github.com/gorilla/mux"
)

// Check input regexp
var LetterOnly = regexp.MustCompile(`^[a-zA-Z]+$`).MatchString

func main() {
    server := initConfig()
    initDb()

    var router *mux.Router
    router = mux.NewRouter().StrictSlash(true)
    apiRouter := router.PathPrefix("/").Subrouter()

    apiRouter.PathPrefix(httpPath).HandlerFunc(GetEntry).Methods("GET")
    apiRouter.PathPrefix(httpPath).HandlerFunc(UpdateEntry).Methods("PUT")
    apiRouter.Path(HealthCheckPath).HandlerFunc(HealthCheck).Methods("GET")

    loggedRouter := handlers.LoggingHandler(os.Stdout, router)

    if err := http.ListenAndServe(server, loggedRouter); err != nil {
        log.Fatalf("Could not start server: %s\n", err.Error())
    }
}

func insertUser(user string, birthday string) error {
    db, err := connectDb()
    if err != nil {
        return err
    }
    defer db.Close()

    userInsert := "INSERT INTO users (name, birthday) VALUES ($1, $2) ON CONFLICT (name) DO UPDATE SET birthday = EXCLUDED.birthday, updated_on = NOW()"
    _, err = db.Exec(userInsert, user, birthday)
    return err
}

func selectUser(user string) (Query, error) {
    var query Query

    db, err := connectDb()
    if err != nil {
        return query, err
    }
    defer db.Close()

    selectRows := "SELECT name,birthday FROM users WHERE name = $1"

    rows, err := db.Query(selectRows, user);
    if err == sql.ErrNoRows {
        return query, err
    }
    defer rows.Close()
   
    for rows.Next() {
        var q Query
        if err := rows.Scan(&q.Name, &q.Birthday); err != nil {
            return query, err
        }
        query = Query{Name: q.Name, Birthday: q.Birthday}
    }

    return query, err

}

func HealthCheck(w http.ResponseWriter, r *http.Request) {
    db, dberr := connectDb()
    if dberr != nil {
        http.Error(w, dbError, 503)
        return
    }
    defer db.Close()

    w.WriteHeader(http.StatusOK)
    w.Header().Set(contentType, appJson)

    _, err := db.Exec("SELECT 1")
    if err != nil {
        http.Error(w, dbError, 503)
        log.Println("DB Ping Failure", err)
        io.WriteString(w, `{"Service is healthy": false}`)
    } else {
        log.Println("DB Ping Success")
        io.WriteString(w, `{"Service is healthy": true}`)
    }
}

func GetEntry(w http.ResponseWriter, r *http.Request) {
    today := getToday()
    user := &Users{}

    name := strings.Replace(r.URL.Path, httpPath, "", 1)

    if name != "" {
        if !LetterOnly(name) {
            w.Header().Set(contentType, textPlain)
            io.WriteString(w, fmt.Sprintf("Incorrect user name %s\n", user))
            http.Error(w, httpErrorWrongInput, 422)
            return
        }

        db, err := connectDb()
        if err != nil {
            http.Error(w, dbError, 503)
            return
        }
        defer db.Close()

        query, err := selectUser(name)
        if err != nil {
            http.Error(w, dbError, 503)
            return
        }
        if query.Name == "" {
            w.Header().Set(contentType, textPlain)
            http.Error(w, fmt.Sprintf("User %s, is not in database\n", name), 422)
            return
        }

        lenQ := len(query.Birthday)
        lenT := len(today)

        if query.Birthday[5:lenQ] == today[5:lenT] {
            text := fmt.Sprintf("Hello, %s! Happy Birthday!", name)
            message := &JSONMessage{Message: text}

            response, err := json.Marshal(message)
            if err != nil {
                http.Error(w, err.Error(), http.StatusInternalServerError)
                return
            }

            w.Header().Set(contentType, appJson)
            w.Write(response)

        } else {
            ndays := daysToBirthday(query.Birthday)

            text := fmt.Sprintf("Hello, %s! Your birthday is in %d day(s)", name, ndays)
            message := &JSONMessage{Message: text}

            response, err := json.Marshal(message)
            if err != nil {
                http.Error(w, err.Error(), http.StatusInternalServerError)
                return
            }

            w.Header().Set(contentType, appJson)
            w.Write(response)

        }
    } else {
        w.Header().Set(contentType, textPlain)
        w.WriteHeader(http.StatusOK)
    }
}

func UpdateEntry(w http.ResponseWriter, r *http.Request) {
    var data BirthDate

    today := getToday()

    name := strings.Replace(r.URL.Path, httpPath, "", 1)

    if name != "" {
        if !LetterOnly(name) {
            w.Header().Set(contentType, textPlain)
            http.Error(w, httpErrorWrongInput, 422)
            return
        }
        db, err := connectDb()
        if err != nil {
            http.Error(w, dbError, 503)
            return
        }
        defer db.Close()

        decoder := json.NewDecoder(r.Body)

        err = decoder.Decode(&data)
        if err != nil {
            panic(err)
        }

        t, err := date(data.Birthday)
        if err != nil {
            log.Println(t, err)
            w.Header().Set(contentType, textPlain)
            http.Error(w, httpErrorWrongInputDate, 422)
            return
        }

        if today == data.Birthday {
            w.Header().Set(contentType, textPlain)
            http.Error(w, httpErrorWrongDate, 422)
            return
        }

        if err := insertUser(name, data.Birthday); err != nil {
            log.Println("Creating user failed", name, data.Birthday)
        } else {
            log.Println("User successfully created/updated", name, data.Birthday)
        }

        w.Header().Set(contentType, textPlain)
        w.WriteHeader(http.StatusNoContent)
    }
}
