#!/bin/bash
#basic script to create the resources necessary for this deployment

if [ "$1" = "--teardown" ]; then
oc project openshift-ingress
oc delete deployment/canary-pod
oc delete cm/canary-nginx-config
oc delete cm/canary-default-config
for i in $(oc get node --show-labels | grep "router-canary=true" | awk {'print $1'}); do echo $i; oc label node/$i router-canary- ; done

else
	#label nodes with router pods to host these containers:
	for i in $(oc get pod -o wide -n openshift-ingress | grep router | grep "Running" | awk {'print $7'}); do echo $i; oc label node/$i router-canary=true; done
	oc project openshift-ingress
    oc create configmap canary-nginx-config --from-file=nginx.conf
    oc create configmap canary-default-config --from-file=default.conf
    oc create -f canary-pod-deployment.yaml
fi