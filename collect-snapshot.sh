DIR="snapshot-$(date +"%Y-%m-%d-%H%M%S")"
date
echo "Create snapshot - $DIR" 
mkdir $DIR

sudo lsblk > $DIR/lsblk.txt
kubectl get pods -n instana-unit > $DIR/instana-unit-pods.txt
kubectl get pods -n instana-core > $DIR/instana-core-pods.txt
free -h > $DIR/free.txt
sudo du -sh /var/lib/kubelet/ > $DIR/du-kubelet.txt
sudo du -sh /run/k3s > $DIR/du-k3s.txt
sudo du -sh /var/lib/rancher/k3s > $DIR/du-rancher-k3s.txt
sudo df -h > $DIR/df.txt
kubectl top  pods -n instana-core > $DIR/top-instana-core.txt
kubectl top  pods -n instana-unit > $DIR/top-instana-unit.txt
kubectl top pods -n instana-clickhouse > $DIR/top-instana-clickhouse.txt
kubectl top pods -n instana-cassandra > $DIR/top-instana-cassandra.txt
kubectl top pods -n instana-elasticsearch > $DIR/top-instana-elasticsearch.txt
kubectl top pods -n instana-kafka > $DIR/top-instana-kafka.txt
kubectl top pods -n instana-postgres > $DIR/top-instana-postgres.txt
~/node-resources.sh > $DIR/node-resources.txt

at now +5 minute -f ./collect-snapshot.sh
