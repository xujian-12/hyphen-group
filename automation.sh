#!/bin/bash

set -e

echo "-----------------------------------------------------------------------------------"
echo "Initializing Kind cluster"
kind create cluster --config core/cluster.yaml
echo "Waiting for kubernetes node(s) become ready"
kubectl wait --for=condition=ready node --all --timeout=60s
echo "Cluster ready"

echo "-----------------------------------------------------------------------------------"

echo "Install Ingress controller and Prometheus"
kubectl apply -f core/ingress-controller.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
kubectl apply --kustomize github.com/kubernetes/ingress-nginx/deploy/prometheus/
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/name=prometheus --timeout=90s
kubectl port-forward -n ingress-nginx service/prometheus-server 8080:9090 &

echo ""
echo "-----------------------------------------------------------------------------------"

echo "Install web applications"
kubectl apply -f app
echo ""
echo "You can now access web applications via "http://localhost/foo" and "http://localhost/bar""

echo ""
echo "-----------------------------------------------------------------------------------"

echo "Start benchmark and get prometheus report"
sh benchmark.sh single
python3 export_to_csv.py | echo ""
echo "Your report are ready, please check report.csv"
