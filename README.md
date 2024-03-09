
# Monitoring k3s VMs 

## Deploying Prometheus

**Note:** Instana running on k3s on a VM is a highly constrained environment. Depending on your usage and the features deployed, it you may not have sufficient resources to deploy prometheus too. It is advised to check that you have enough resources for proceeding. 

1. Clone the `prometheus-operator` repo:

```
git clone https://github.com/prometheus-operator/kube-prometheus.git
```

2.  Create the namespace and CRDs, and then wait for them to be available before creating the remaining resources. The 2nd command will wait until the "servicemonitors" CRD is created. The message "No resources found" means success in this context.

```
kubectl create -f monitoring/kube-prometheus/manifests/setup

until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
```

3. Create the resources and wait for all of the pods to become available.

```
kubectl create -f monitoring/kube-prometheus/manifests/


kubectl get pods -n monitoring
```

4. Add a prom rule to be able to get the metrics for Kafka.  

``` 
kubectl create -f instana-performance/utilities/prometheus-exporter/strimziPodSet-rule-k8s.yaml

# Verify that the rule is created 
kubectl get PrometheusRule  -n monitoring
```


## Collecting Prom data

In order to connect to prometheus, you'll need to first create a tunnel to it. 
```
kubectl --namespace monitoring port-forward svc/prometheus-k8s 9090
```


extract the data using the prometheus exporter: 
```
touch /tmp/token; python3 ~/prometheus_exporter.py  --namespace "instana-core instana-unit instana-cassandra instana-clickhouse instana-kafka instana-postgres instana-elasticsearch instana-beeinstana instana-zookeeper" --url http://localhost:9090 --start=20240124202000 --end=20240124205000 --keyReport --throttle  --tknfile /tmp/token
```

## Using Grafana (from an Ubuntu VM) - DRAFT, For Review

NOTE: The following steps MAY increase the overall footprint (CPU & Memory) utilization on the K3s VM. Plan additional feature-flags and load-testing activities to suit.

1. Update the VM:
```
sudo apt update
```

2. Install Xfce along with the xfce4-goodies package:
```
sudo apt install xfce4 xfce4-goodies
```

3. Install the TightVNC Server:
```
sudo apt install tightvncserver
```

4. Next, run the vncserver command to set a VNC access password, create the initial configuration files, and start a VNC server instance:
```
vncserver
```

5. At this point, the VNC server is installed and running. Now let’s configure it to launch Xfce and give us access to the server through a graphical interface. The commands that the VNC server runs at startup are located in a configuration file called xstartup in the .vnc folder under your home directory. The startup script was created when you ran the vncserver command in the previous step, but you’ll create your own to launch the Xfce desktop. Because you are going to be changing how the VNC server is configured, first stop the VNC server instance that is running on port 5901 with the following command:
```
vncserver -kill :1
```

6. Before you modify the xstartup file, back up the original:
```
mv ~/.vnc/xstartup ~/.vnc/xstartup.bak
```

7. Now create a new xstartup file and open it in a text editor, such as vi (or nano):
```
vi ~/.vnc/xstartup 
```

8. Update the xstartup file to resemble the following:
```
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
```

9. Save the file and mark executable so the VNC server can properly use it:
```
chmod +x ~/.vnc/xstartup
```

10. Restart the VNC server (provide an optimal geometry for your system if desired as shown):
```
vncserver -geometry 1920x1200
```

11. IF you get a grey screen when logging into your VNC session, reboot the VM, and rerun apt update:
```
sudo apt update
``` 
and restart the VNC server:
```
vncserver -geometry 1920x1200
```

![image](https://media.github.ibm.com/user/50777/files/b88fa8af-f691-479d-96f0-3864f46d3a91)

12. Install Firefox to access Grafana Dashboards (for local use on the VM ):
```
sudo apt install firefox
```

13. Need to set some Default applications once you log into the VNC Session:

Applications > Settings > Settings Manager > Default Applications
```
Internet > Web Browser > Firefox
```
```
Utilities > Terminal Emulator > Xfce Terminal (Same as Desktop mgr)
```

14. IF Firefox will not properly launch from it's icon, for now, run it via a terminal window as follows:

14a. Open termininal window 1, and run the following command to port forward the Grafana port:
```
kubectl port-forward service/grafana 3000 --namespace=monitoring
```

14b. In a second terminal window, run the following commands:
```
XAUTHORITY=$HOME/.Xauthority
export XAUTHORITY

firefox
```

15. Access Grafana and Dashboards in Firefox via:
```
localhost:3000
```

## Grafana Dashboard Blog

To read more on Grafana Dashboards, review the blog post here:

https://w3.ibm.com/w3publisher/aiopshcm/blog/5eb4a350-7f4d-11ee-bd09-f597e743757d
