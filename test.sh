#!/usr/bin/env bash

dir="$(dirname "$0")"

if [[ ! -e ./assert.sh ]]; then
    wget https://raw.githubusercontent.com/torokmark/assert.sh/master/assert.sh
fi

source "./assert.sh"

function result() {
    if [ "$?" == 0 ]; then
      log_success "OK"
    fi
}

function localTests() {
    log_header "Local tests assert : test.sh"
    today=$(date +"%m-%d")

    command_table=(
        "$(curl -s -X PUT -d '{"dateOfBirth": "1979-11-31"}' http://127.0.0.1:9000/hello/Yezhi)"
        "$(curl -s http://127.0.0.1:9000/hello/Yezhi)"
        "$(curl -s http://127.0.0.1:9000/notfound/)"
        "$(curl -s http://127.0.0.1:9000/health/)"
        "$(curl -s -X PUT -d '{"dateOfBirth": "1965-10-22"}' http://127.0.0.1:9000/hello/Rudy)"
        "$(curl -s -X PUT -d '{"dateOfBirth": "1950-03-14"}' http://127.0.0.1:9000/hello/Duda)"
        "$(curl -s -X PUT -d '{"dateOfBirth": "1999-'${today}'"}' http://127.0.0.1:9000/hello/Dada)"
        "$(curl -s http://127.0.0.1:9000/hello/Dada)"
    )

    expected_table=(
        'Invalid dateOfBirth value (YYYY-MM-DD)'
        'User Yezhi, is not in database'
        '404 page not found'
        '{"Service is healthy": true}'
        ''
        ''
        ''
        '{"message":"Hello, Dada! Happy Birthday!"}'
    )

    for ((i=0;i<${#command_table[@]};++i)); do
        echo "Test #" "$i" "${command_table[i]}"
        assert_eq "${command_table[i]}" "${expected_table[i]}" "Failed!"; result;
    done
}

function remoteTests() {
    log_header "Remote tests assert : test.sh"
    REMOTE_HOST=$(<"$dir/.ext.ipv4")
    today=$(date +"%m-%d")

    echo "Checking service on: $REMOTE_HOST"

    command_table=(
        "$(curl -s -X PUT -d '{"dateOfBirth": "1979-11-31"}' http://${REMOTE_HOST}:80/hello/Yezhi)"
        "$(curl -s http://${REMOTE_HOST}:80/hello/Yezhi)"
        "$(curl -s http://${REMOTE_HOST}:80/notfound/)"
        "$(curl -s http://${REMOTE_HOST}:80/health/)"
        "$(curl -s -X PUT -d '{"dateOfBirth": "1965-10-22"}' http://${REMOTE_HOST}:80/hello/Rudy)"
        "$(curl -s -X PUT -d '{"dateOfBirth": "1950-03-14"}' http://${REMOTE_HOST}:80/hello/Duda)"
        "$(curl -s -X PUT -d '{"dateOfBirth": "1999-'${today}'"}' http://${REMOTE_HOST}:80/hello/Dada)"
        "$(curl -s http://${REMOTE_HOST}:80/hello/Dada)"
    )

    expected_table=(
        'Invalid dateOfBirth value (YYYY-MM-DD)'
        'User Yezhi, is not in database'
        '404 page not found'
        '{"Service is healthy": true}'
        ''
        ''
        ''
        '{"message":"Hello, Dada! Happy Birthday!"}'
    )

    for ((i=0;i<${#command_table[@]};++i)); do
        echo "Test #" "$i" "${command_table[i]}"
        assert_eq "${command_table[i]}" "${expected_table[i]}" "Failed!"; result;
    done
}

while [[ $# -gt 0 ]]; do
    case $1 in
        remote)
        remoteTests "$HOST";
        shift
        ;;
        local)
        localTests;
        shift
        ;;
        *)
        echo "Usage: ./test.sh (local|remote)";
        shift
    esac
done