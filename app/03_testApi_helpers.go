package main

import (
    "fmt"
    "time"
)

const (
    layoutISO = "2006-01-02"
)

// Converting given date to format 'layoutISO'
func date(s string) (time.Time, error) {
    date, err := time.Parse(layoutISO, s)
    return date, err
}

func getToday() string {
    t := time.Now()
    return fmt.Sprintf("%d-%02d-%02d", t.Year(), t.Month(), t.Day())
}

func daysToBirthday(d string) int {
    birthday, _ := date(d)
    today := time.Now()

    diffA, _ := date(fmt.Sprintf("%d-%02d-%02d", today.Year(), birthday.Month(), birthday.Day()))

    diff := diffA

    if diffA.Before(today) {
        diff, _ = date(fmt.Sprintf("%d-%02d-%02d", today.Year()+1, birthday.Month(), birthday.Day()))
    }

    result := int(today.Sub(diff).Hours() / 24)

    // Negative result means your birthday is next year
    if result < 0 {
        result = -result
    }

    // Should be some hours like 12 but returns day value as integer
    if result == 0 {
        result = 1
    }

    // Actually it's today
    if result == 365 {
        result = 0
    }

    return result
}
