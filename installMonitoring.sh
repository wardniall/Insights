#!/bin/bash

DEPLOYMENT_TYPE=''

showHelp () {
        cat << EOF
        Usage: ./installMonitoring.sh [-h|--help -t|--type=<GCP|FYRE>]
Helper script to deploy the Prometheus and Grafana monitoring tools onto a k3s stack on GCP or Fyre
-h, --help                                      Display help
-t, --type                                      Deployment type to deploy the monitoring stack onto. Can be GCP or Fyre
EOF
}

options=$(getopt -l "help,type:" -o "h,t:" -a -- "$@")
eval set -- "${options}"
while true; do
        case ${1} in
        -h|--help)
                showHelp
                exit 0
                ;;
        -t|--type)
                shift
                DEPLOYMENT_TYPE="${1}"
                ;;
        --)
                shift
                break
                ;;
        esac
shift
done

if [ "${DEPLOYMENT_TYPE}" != "GCP" ] && [ "${DEPLOYMENT_TYPE}" != "FYRE" ]; then
	echo "Invalid deployment type provided. Valid values are GCP or FYRE"
	exit -1
fi


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

#IP_ADDR=$(kubectl get nodes -o wide | tail -1 | awk '{print $6}')
if [ "${DEPLOYMENT_TYPE}" == "GCP" ]; then
	IP_ADDR=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
else
	IP_ADDR=$(kubectl get nodes -o wide | tail -1 | awk '{print $6}')
fi

echo ${IP_ADDR}
until curl -s -f -o /dev/null "http://${IP_ADDR}:31111"
do
  sleep 5
  echo "Testing for Prometheus availability..."
done

echo "Prometheus should be available on http://${IP_ADDR}:31111"
echo "Grafana should be available on http://${IP_ADDR}:31112"


