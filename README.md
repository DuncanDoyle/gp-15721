# Gloo-Platform-15721 Reproducer


## Installation

Add Gloo Platform Helm repo:
```
helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
```

Export your Gloo Gateway License Key to an environment variable:
```
export GLOO_GATEWAY_LICENSE_KEY={your license key}
```

Install Gloo Gateway:
```
cd install
./install-gloo-gateway-with-helm.sh
```

> NOTE
> The Gloo Gateway version that will be installed is set in a variable at the top of the `install/install-gloo-gateway-with-helm.sh` installation script.

## Setup the environment

Run the `install/setup.sh` script to setup the environment:
- Deploy the HTTPBin service
- Deploy the VirtualGateway
- Deploy the RouteTables

```
./setup.sh
```

## Run the test

Call the HTTPBin service with a simple cURL GET command:

```
curl -v http://api.example.com/httpbin/get
```

The [default WAF policy](policies/waf/waf-policy.yaml) that we have applied to our RouteTable that will reject the request when we set the `agent` header to "scammer"
```
curl -v -H "agent: scammer" http://api.example.com/httpbin/get
```
The request should be rejected.

Restart the istio-ingressgateway:
```
kubectl -n gloo-mesh-gateways rollout restart deployment istio-ingressgateway-1-20 && kubectl -n gloo-mesh-gateways rollout status deploy/istio-ingressgateway-1-20
```

Notice that we can still access the route:

```
curl -v http://api.example.com/httpbin/get
```

Now, deploy the bad WAF configuration for our RouteTable:

```
kubectl apply -f policies/waf/waf-policy-problem-1.yaml 
```

The istio-ingressgateway logs will emit this error:

```
2024-03-27T08:42:48.174576Z	warning	envoy config external/envoy/source/extensions/config_subscription/grpc/grpc_subscription_impl.cc:138	gRPC config for type.googleapis.com/envoy.config.route.v3.RouteConfiguration rejected: Rules error. File: <<reference missing or not informed>>. Line: 5. Column: 19. 	thread=14
```

Notice that we can still access the service:

```
curl -v http://api.example.com/httpbin/get
```

Now, restart the `istio-ingressgateway`. This will result in bad-config being server to Envoy, which means our routes are no longer accessible (404):

```
kubectl -n gloo-mesh-gateways rollout restart deployment istio-ingressgateway-1-20 && kubectl -n gloo-mesh-gateways rollout status deploy/istio-ingressgateway-1-20
```

Try accessing the service, this will result in a 404:

```
curl -v http://api.example.com/httpbin/get
```

Apply the correct VirtualService again and notice that we can now access our service again:

```
kubectl apply -f policies/waf/waf-policy.yaml
```

```
curl -v http://api.example.com/httpbin/get
```

The WAF policies `policies/waf/waf-policy-problem-2.yaml` and `policies/waf/waf-policy-problem-3.yaml` show different variations of the same problem. Simply apply these CRs and follow the same steps as we did earlier to demonstrate the problem (e.g. applying the CR and restarting the gateway-proxy).


## Conclusion
What happens is that Gloo Platform control plane does not catch any malformed/misconfigured WAF policies, resulting in the control plane sending bad configuration to IstioD and Envoy. Envoy will not accept that configuration and will keep running the existing one, until you restart the istio-ingressgateway/Envoy. At that point, Envoy can no longer load a valid configuration, resulting in a full outage of all routes.