# Router-Canary:

This project is designed to address a specific use-case in a specific environment. It may be adapted for use elsewhere but is provided AS-IS
with no support/warranties or implied maintenance of any kind. 

# What does this deployment do?

- In the specific environment this was built for, we observed that OpenShift 4 cluster running Calico CNI had a discrepant boot time between router pods and calico pods
- Calico pods were taking several minutes to finish provisioning the network stack on the infra hosts, and the router pods were immediately binding to port 443 on the host node
- As a result, the NLB upstream loadbalancer saw the infra nodes as available immediately even though they were not.
- This deployment seeks to address that problem by creating canary pods that check for the router pod's availability to serve traffic before publishing a local nginx URI
- Configuring the NLB to call the URI of the canary pod before sending traffic to port 443/80 for ingress on the host will grant more control over the process and prevent traffic loss on boot.


# code logic overview:

This script will curl against the localhost of the node in order to resolve a URL against the router-default pod deployed on the same node (this container must be deployed as hostNetworked)
when the curl resolves the default/existing canary route for the cluster, it will return a 200 response, which means the folowing:

1. router-default pod is online and can route traffic.
2. calico-node is READY and has deployed internal routing tables sufficiently to redirect traffic to backends from router-default pods (or shard pods)
3. infra node is now available to host traffic from upstream NLB/loadbalancer

When the 200 response arrives, call (healthprobe) - which will init the nginx server and expose the URI that the NLB/LB can call
the nginx server in this container will serve a 200 back to the NLB/LB informing that this host can accept traffic to the router pods
it is expected that this pod will be deployed at a separate test port on the host that is used only for liveness probes.
after nginx starts, call secondary health function (liveness) to confirm that the pod is serving traffic at it's local port
liveness will also call the localhost function to ensure router-pods remain up.
if a failure occurs at either route remove file "healthy" from /tmp/ which is how kubelet will be validating the node is available

# Variables that need to be changed/defined in the script:

- URL: openshift-ingress-canary.apps.<yourcluster>.<yourdomain> # predefined route that your cluster will serve (`oc get route -n openshift-ingress`) we will use to confirm ingress is working
	 (is defined in the canary-pod-deployment.yaml)
- LOCALPORT=8888 # predefined port that will be exposed on the host for a call to the URI address `<IP-of-infra-node>:8888/healthz/ready`
     (note that this is defined/inherited from the canary-pod-deployment.yaml, but is currently hard-coded into the nginx)
- nginx.conf: Defines the exposed LOCALPORT for the pod and the URI path to be called by the application
     (this is managed in the configmap yaml)

# How to implement a test for this repository:

1. Clone or fork this repository so you can manage your own versions
2. Review the code base and change the `URL` and `LOCALPORT` (As applicable)
3. Ensure that you have adequate port access to the designated localport and permission to create a hostNetworked pod on your infra nodes (or test nodes)
4. Modify the canary-pod-deployment.yaml to include a NodeSelector value that matches your infra hosts to ensure you scope these pods to nodes where router-default pods are running.
4. run the deploy.sh to create the necessary assets and scale up the deployment to the desired host node level
