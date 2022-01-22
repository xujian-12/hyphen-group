#!/bin/bash
# Copyright 2020 HAProxy Technologies LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

temp_yaml=$(mktemp)

display_working() {
    spin='⠇⠏⠋⠉⠙⠹⠸⠼⠴⠤⠦'
    i=0
    pid=$1
    secs=0
    if [ -n "$3" ]; then
        if [ $3 -gt 0 ]; then
            secs=$(($3 * 60 * 1000))
	fi
    fi
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %12 ))
        if [ $secs -gt 0 ]; then
            printf "\r[%s] %s ... ${spin:$i:1}" $(date -d@$((secs / 1000)) -u +%M:%S) "$2"
	else
	    printf "\r%s ... ${spin:$i:1}" "$2"
	fi
        sleep .1
	secs=$((secs-100))
    done
    printf "\r%s ... \xE2\x9C\x85%s\n" "$2" "$(tput el)"
}

setup() {

    REPLACE_PARALLELISM="$1"
    INJECTOR_YAML="apiVersion: apps/v1
kind: Deployment
metadata:
  name: ubuntu-deployment
  labels:
    app: ubuntu
spec:
  replicas: $REPLACE_PARALLELISM
  selector:
    matchLabels:
      app: ubuntu
  template:
    metadata:
      labels:
        app: ubuntu
    spec:
      containers:
      - name: ubuntu
        image: ubuntu:latest
        # Just sleep forever
        command: [ "sleep"]
        args: [ "infinity" ]
"
    mkdir -p /home/ubuntu/.parallel
    touch /home/ubuntu/.parallel/will-cite
    A_INIT_CMD="apt-get update && apt-get -y -f install sysstat"
    B_INIT_CMD="apt-get update;apt-get -y -f upgrade; apt-get -y -f install curl; curl -Lo /usr/local/bin/hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64; chmod +x /usr/local/bin/hey;"
    echo -e "$INJECTOR_YAML" >$temp_yaml
    kubectl create ns ubuntu-injector >/dev/null 2>&1 &
    kubectl -n ubuntu-injector apply -f $temp_yaml >/dev/null 2>&1
    sleep 7
    kubectl get pods -n ubuntu-injector -o name|parallel --max-proc 0 kubectl -n ubuntu-injector exec {} -- bash -c \""$B_INIT_CMD"\" >/dev/null 2>&1
    kubectl get pods -o name |grep nginx-inc | parallel --max-proc 0 kubectl exec {} -- sh -c \""$A_INIT_CMD"\" >/dev/null 2>&1
    kubectl get pods -o name |grep envoy | parallel --max-proc 0 kubectl exec {} -c envoy -- sh -c \""$A_INIT_CMD"\" >/dev/null 2>&1
    sleep 5
    display_working $! "Setup"
}

start() {
CSVOUTPUT=""
EXT="txt"
REPLACE_PARALLELISM="$3"
REPLACE_CONN="$4"
    if [ "$REPLACE_PARALLELISM" -eq 1 ]; then
        t="single"
    else
        t="saturate"
    fi
    kubectl get pods -n ubuntu-injector -o name|parallel --max-proc 0 kubectl -n ubuntu-injector exec {} -- bash -c \""hey $CSVOUTPUT -z 360s -c $REPLACE_CONN https://$1.default/"\" |grep -v response-time |sort -nt ',' -k 8  >tmp/$t/$1.$EXT &
    display_working $! "Benchmarking $2" 6 &
    do_scale
    do_modify "$1" >/dev/null 2>&1
    sleep 30
}

do_scale() {
    for x in {1..3}; do
        sleep 30
        kubectl -n app scale --replicas=7  deployment/echo >/dev/null 2>&1
        sleep 30
        kubectl -n app scale --replicas=5  deployment/echo >/dev/null 2>&1
    done
    sleep 30
}

do_modify() {
    proxy="$1"
    sleep 30
    patch_$proxy cors
    sleep 30
    patch_$proxy cors remove
    sleep 30
    patch_$proxy rewrite
    sleep 30
    patch_$proxy rewrite remove
    sleep 30
}

patch_nginx() {
    if [ "$1" == "cors" ]; then
        if [ "$2" == "remove" ]; then
            kubectl -n app annotate ingress nginx nginx.ingress.kubernetes.io/enable-cors-
        else
            kubectl -n app annotate ingress nginx nginx.ingress.kubernetes.io/enable-cors="true"
        fi
    elif [ "$1" == "rewrite" ]; then
        if [ "$2" == "remove" ]; then
            kubectl -n app annotate ingress nginx nginx.ingress.kubernetes.io/rewrite-target-
	else
            kubectl -n app annotate ingress nginx nginx.ingress.kubernetes.io/rewrite-target=/test
        fi
    fi
}

cleanup() {
    kubectl delete namespace ubuntu-injector >/dev/null 2>&1 &
    display_working $! "Cleaning up"
}

single() {
    printf "Starting single benchmarks\n"
    start nginx "NGINX" 1 250 $1
}

case $1 in
    "cleanup")
      cleanup
      exit
    ;;
    "collect")
      collect
      exit
    ;;
    "parse")
      parse single
      parse saturate 
      exit
    ;;
    "single")
      cleanup
      setup 1
      single
      cleanup
    ;;
esac

trap "rm -f $temp_yaml" 0 2 3 15
