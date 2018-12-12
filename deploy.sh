#!/bin/bash
gcloud config set compute/zone us-central1-a

cd jenkins

#Do not auto-delete cluster
#gcloud --quiet container clusters delete jenkins

gcloud container clusters create jenkins \
  --machine-type n1-standard-2 --num-nodes 2 \
  --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw,cloud-platform"

wget https://storage.googleapis.com/kubernetes-helm/helm-v2.12.0-linux-amd64.tar.gz
tar zxfv helm-v2.12.0-linux-amd64.tar.gz
cp linux-amd64/helm .

#Since RBAC was removed command below allows permission to default service account. Correct when RBAC is enabled.
kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts
# RBAC Disabled ^^^

kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=vishal.kapashi@clearobject.com --user=marcin.gluc@clearobject.com --user=sunil.ravula@clearobject.com
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

#Used to generate self-signed cert. Now we use cert-manager
#openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt -subj "/CN=build.co.clearobject.com"
#kubectl create secret tls jenkins-ingress-ssl --key /tmp/tls.key --cert /tmp/tls.crt
#kubectl describe secret jenkins-ingress-ssl

./helm init --service-account=tiller --wait
./helm update
#helm chart source https://github.com/helm/charts/tree/master/stable/jenkins

./helm install \
  --name cert-manager \
  --version v0.4.1 \
  --namespace kube-system \
  --set ingressShim.defaultIssuerName=letsencrypt \
  --set ingressShim.defaultIssuerKind=ClusterIssuer \
  stable/cert-manager
  
./helm install --name nginx-ingress stable/nginx-ingress 
./helm install --name jenkins stable/jenkins --values values.yaml --version 0.25.0 --wait

ADMIN_PWD=$(kubectl get secret --namespace default jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode)
export SERVICE_IP=$(kubectl get svc --namespace default nginx-ingress-controller --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")

kubectl create -f lets-encrypt-issuer.yaml

#Set DNS
#removes current dns records
gcloud --project clearobject-corp dns record-sets transaction start -z=clearobject-corp
OLD_DNS=$(gcloud --project clearobject-corp dns record-sets list --zone=clearobject-corp | grep build.co.clearobject.com | awk '{print $4}')
gcloud --project clearobject-corp dns record-sets transaction remove -z=clearobject-corp \
   --name="build.co.clearobject.com" \
  --type=A \
   --ttl=300 $OLD_DNS
gcloud --project clearobject-corp dns record-sets transaction execute -z=clearobject-corp

#adds new record
gcloud --project clearobject-corp dns record-sets transaction start -z=clearobject-corp
gcloud --project clearobject-corp dns record-sets transaction add -z=clearobject-corp \
   --name="build.co.clearobject.com" \
   --type=A \
   --ttl=300 $SERVICE_IP
gcloud --project clearobject-corp dns record-sets transaction execute -z=clearobject-corp

curl -H 'Host: build.co.clearobject.com' https://$SERVICE_IP/ -k
echo Your Admin PWD = $ADMIN_PWD
echo https://build.co.clearobject.com
echo $SERVICE_IP
