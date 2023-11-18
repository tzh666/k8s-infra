#!/bin/bash

POD_NAME=$(kubectl get pods --namespace "openvpn" -l "app=openvpn,release=openvpn" -o jsonpath='{ .items[0].metadata.name }')

SERVICE_NAME=$(kubectl get svc --namespace "openvpn" -l "app=openvpn,release=openvpn" -o jsonpath='{ .items[0].metadata.name }')

#SERVICE_IP=$(kubectl get svc --namespace "openvpn" "$SERVICE_NAME" -o go-template='{{ range $k, $v := (index .status.loadBalancer.ingress 0)}}{{ $v }}{{end}}')

SERVICE_IP=192.168.1.189

KEY_NAME=$1

kubectl --namespace "openvpn" exec -it "$POD_NAME" /etc/openvpn/setup/newClientCert.sh "$KEY_NAME" "$SERVICE_IP"

kubectl --namespace "openvpn" exec -it "$POD_NAME" cat "/etc/openvpn/certs/pki/$KEY_NAME.ovpn" > "$KEY_NAME.ovpn"

