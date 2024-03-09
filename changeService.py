#!/usr/bin/python

import yaml

with open("prometheus_ClusterIP_svc.yml") as f:
    y = yaml.safe_load(f)
    del y['spec']['clusterIP']
    del y['spec']['clusterIPs']
    y['spec']['type'] = 'NodePort'
    #print(y['spec']['ports'])
    y['spec']['ports'][0]['nodePort']=31111
    #print(y['spec']['ports'])
    # print(yaml.dump(y, default_flow_style=False))

with open("prometheus_NodePort_svc.yml", "w") as ostream:
    yaml.dump(y, ostream, default_flow_style=False)


with open("grafana_ClusterIP_svc.yml") as f:
    y = yaml.safe_load(f)
    del y['spec']['clusterIP']
    del y['spec']['clusterIPs']
    y['spec']['type'] = 'NodePort'
    #print(y['spec']['ports'])
    y['spec']['ports'][0]['nodePort']=31112
    #print(y['spec']['ports'])
    # print(yaml.dump(y, default_flow_style=False))

with open("grafana_NodePort_svc.yml", "w") as ostream:
    yaml.dump(y, ostream, default_flow_style=False)
