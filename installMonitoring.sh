#!/bin/bash


WORKING_FOLDER=$(pwd)

mkdir ~/monitoring_promgraf

cd ~/monitoring_promgraf

git clone https://github.com/prometheus-operator/kube-prometheus.git

cd kube-prometheus

kubectl apply --server-side -f manifests/setup

kubectl wait \
        --for condition=Established \
        --all CustomResourceDefinition \
        --namespace=monitoring

kubectl apply -f manifests/

sleep 20

kubectl get svc -n monitoring

echo "Writing service file"
until kubectl get svc prometheus-operated -n monitoring
do
  echo "Waiting for promethues-operated to start"
  sleep 5
done

kubectl get svc prometheus-operated -o yaml -n monitoring > ${WORKING_FOLDER}/prometheus_ClusterIP_svc.yml
kubectl get svc grafana -o yaml -n monitoring > ${WORKING_FOLDER}/grafana_ClusterIP_svc.yml

cd ${WORKING_FOLDER}

python3 changeService.py

kubectl delete svc prometheus-operated -n monitoring

kubectl delete svc grafana -n monitoring

kubectl create -f prometheus_NodePort_svc.yml -n monitoring

kubectl create -f grafana_NodePort_svc.yml -n monitoring

kubectl create -f prometheusNetworkPolicy.yml -n monitoring

kubectl create -f grafanaNetworkPolicy.yml -n monitoring

IP_ADDR=$(kubectl get nodes -o wide | tail -1 | awk '{print $6}')

until curl -s -f -o /dev/null "http://${IP_ADDR}:31111"
do
  sleep 5
  echo "Testing for Prometheus availability..."
done

echo "Prometheus should be available on http://${IP_ADDR}:31111"
echo "Grafana should be available on http://${IP_ADDR}:31112"


