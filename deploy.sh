#!/bin/bash
#reference documents:
#run from cloudshell home directory
gcloud config set compute/zone us-central1-f

cd stub-jenkins2.0/jenkins

gcloud --quiet container clusters delete jenkins-cd
gcloud --quiet compute networks delete jenkins

gcloud --quiet compute networks create jenkins
gcloud container clusters create jenkins-cd \
  --network jenkins --machine-type n1-standard-2 --num-nodes 2 \
  --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw,cloud-platform"

wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar zxfv helm-v2.9.1-linux-amd64.tar.gz
cp linux-amd64/helm .

kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=vishal.kapashi@clearobject.com --user=marcin.gluc@clearobject.com --user=sunil.ravula@clearobject.com
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

./helm init --service-account=tiller --wait
./helm update
#helm chart source https://github.com/helm/charts/tree/master/stable/jenkins
#helm chart custom GCP values https://github.com/GoogleCloudPlatform/continuous-deployment-on-kubernetes/blob/master/jenkins/values.yaml
./helm install -n cd stable/jenkins --values jenkins/values.yaml --version 0.19.0 --wait

ADMIN_PWD=$(kubectl get secret --namespace default cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode)

echo Your Admin PWD = $ADMIN_PWD

export SERVICE_IP=$(kubectl get svc --namespace default cd-jenkins --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")

echo http://$SERVICE_IP:8080/login


#build.co.clearobject.com
#deploy.co.clerobject.com
#manage.co.clerobject.com
