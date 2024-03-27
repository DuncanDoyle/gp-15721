#!/bin/sh

pushd ..

printf "\nDeploy HTTPBin service ...\n"
kubectl apply -f apis/httpbin.yaml

printf "\nDeploy VirtualGateway ...\n"
kubectl apply -f virtualgateways/vg.yaml

printf "\nDeploy RouteTables ...\n"
kubectl apply -f routetables/api-example-com-rt.yaml

kubectl apply -f policies/waf/waf-policy.yaml

popd