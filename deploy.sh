#!/bin/bash
#basic script to create the resources necessary for this deployment
# uses the node label: router-canary=true to determine what hosts should recieve the deployment
# default usage calls no arguments (will deploy to all router-pod host nodes), with desired replica of 1 pod (scale it up manaully to match routerpods) or convert to a daemonset

#options: 
#./deploy.sh --teardown (will destroy assets and remove from the cluster)
#./deploy.sh --testing (will create the objects but will not label all nodes, will assume you have pre-labeled nodes)

if [ "$1" = "--teardown" ]; then
oc project openshift-ingress
oc delete deployment/canary-pod
oc delete cm/canary-nginx-config
oc delete cm/canary-default-config
for i in $(oc get node --show-labels | grep "router-canary=true" | awk {'print $1'}); do echo $i; oc label node/$i router-canary- ; done

elif [ "$1" = "--testing" ]; then
    echo "it is assumed you will have already labeled one node with: router-canary=true, do so if you haven't already to scope pods"
	oc project openshift-ingress
    oc create configmap canary-nginx-config --from-file=nginx.conf
    oc create configmap canary-default-config --from-file=default.conf
    oc create -f canary-pod-deployment.yaml
else
	#label nodes with router pods to host these containers:
	for i in $(oc get pod -o wide -n openshift-ingress | grep router | grep "Running" | awk {'print $7'}); do echo $i; oc label node/$i router-canary=true; done
	oc project openshift-ingress
    oc create configmap canary-nginx-config --from-file=nginx.conf
    oc create configmap canary-default-config --from-file=default.conf
    oc create -f canary-pod-deployment.yaml
fi