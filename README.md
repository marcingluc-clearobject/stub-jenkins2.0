https://www.youtube.com/watch?v=JJTJfl-V_UM&t=14s

curl -H 'Host: build.co.clearobject.com' https://35.194.30.223/ -k

printf $(kubectl get secret --namespace default jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
V26DGqRLnT



If you hit the nginx ingress with https://104.198.179.176 you will always hit the default backend. You either need to hit it with https://xx.xx.xxxx.com or with something like this:

$ curl -H 'Host: xx.xx.xxxx.com' https://104.198.179.176
With respect to the ingress IP address being incorrect, I would check that your backend service has endpoints and that each is listening on port 8080.

$ kubectl describe svc jenkins
or/and

$ kubectl describe ep
I would also check the events in the Ingress:
$ kubectl describe ingress jenkins
Finally, I would check the logs in the ingress controller:
$ kubectl logs nginx-ingress-controller

#install cert manager
./helm install --name cert-manager --namespace kube-system stable/cert-manager

#try to disable rbac to fix validation issues 
./helm install --name cert-manager --namespace kube-system stable/cert-manager --set rbac.create=false

#create Lets Encrypt issuer 
sudo vim lets-encrypt-issuer-staging.yaml
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
        name: letsencrypt-staging
spec:
        acme:
                server: https://acme-staging-v02.api.letsencrypt.org/directory
                email: marcin.gluc@clearobject.com
                privateKeySecretRef:
                        name: letsencrypt-staging
                http01: {}

kubectl apply -f lets-encrypt-issuer-staging.yaml
kubectl get issuer
kubectl describe issuer letsencrypt-staging
kubectl get issuer -o yaml
#check logs
kubectl -n kube-system get pods | grep cert
kubectl logs -n kube-system cert-manager-795b4694f8-2m6wn 

#create lets encrypt certificate
sudo vim certificate-staging.yaml
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: build-co-clearobject-staging
  namespace: default
spec:
  secretName: build-co-clearobject-staging-tls
  issuerRef:
    name: letsencrypt-staging
  commonName: build.co.clearobject.com
  acme:
    config:
    - http01:
        ingress: jenkins
      domains:
      - build.co.clearobject.com
kubectl apply -f certificate-staging.yaml
kubectl get certificate
kubectl describe certificate build-co-clearobject-staging
kubectl get ingress
kubectl get ingress jenkins -o yaml #check if new spec rule is enabled
kubectl get pods # check if new pod is deployed
kubectl describe certificate build-co-clearobject-staging # watch for cert issue
#validation failed ingress not updated, pod not deployed 

#update ingress with new key
kubectl get secret
#build-co-clearobject-staging-tls
kubectl edit ing jenkins
  tls:
  - hosts:
    - build.co.clearobject.com
    secretName: build-co-clearobject-staging-tls

kubectl describe ing jenkins #validate key is updated 

# validate cert in browser build.co.clearobject.com 

#promote issuer to production 
cp lets-encrypt-issuer{-staging,}.yaml #copy staging yaml to lets-encrypt-issuer.yaml
vim lets-encrypt-issuer.yaml
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
        name: letsencrypt
spec:
        acme:
                server: https://acme-v02.api.letsencrypt.org/directory
                email: marcin.gluc@clearobject.com
                privateKeySecretRef:
                        name: letsencrypt
                http01: {}

kubectl apply -f lets-encrypt-issuer.yaml
kubectl get issuer
kubectl describe issuer letsencrypt

#promote cert to production 
cp certificate{-staging,}.yaml
vim certificate.yaml
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: build-co-clearobject
spec:
  secretName: build-co-clearobject-tls
  issuerRef:
    name: letsencrypt
  commonName: build.co.clearobject.com
  acme:
    config:
    - http01:
        ingress: jenkins
      domains:
              - build.co.clearobject.com
kubectl apply -f certificate.yaml
kubectl get certificate
kubectl describe certificate build-co-clearobject 
#check for challenge
kubectl get ingress jenkins -o yaml #fails
#check for pod
kubectl get pod #fails

#update ingress to prod cert 
kubectl get secret
#build-co-clearobject-tls   
kubectl edit ing jenkins
  tls:
  - hosts:
    - build.co.clearobject.com
    secretName: build-co-clearobject-tls

kubectl describe ing jenkins #validate key is updated 
# validate cert in browser build.co.clearobject.com 

https://www.google.com/search?q=cert+manager+kubernetes.io/tls-acme:+%22true%22&ei=SmTPW9PuLOrCjwSD84PQDw&start=0&sa=N&biw=1147&bih=1359


https://medium.com/oracledevs/secure-your-kubernetes-services-using-cert-manager-nginx-ingress-and-lets-encrypt-888c8b996260

./helm install \
  --name cert-manager \
  --namespace kube-system \
  --set ingressShim.defaultIssuerName=letsencrypt-staging \
  --set ingressShim.defaultIssuerKind=ClusterIssuer \
  stable/cert-manager 

---
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: marcin.gluc@clearobject.com
    privateKeySecretRef:
       name: letsencrypt-sec-staging
    http01: {}
kubectl get ClusterIssuer
kubectl describe ClusterIssuer letsencrypt-staging

Google Apps Login: http://www.tothenew.com/blog/jenkins-google-authentication/
Oauth keys generated in co-automtion-stub project > IAM > credentials 
Logging out issue: https://issues.jenkins-ci.org/browse/JENKINS-33286
Use google groups: https://issues.jenkins-ci.org/browse/JENKINS-28010

upgrade to newest helm chart
https://github.com/helm/helm/blob/master/docs/helm/helm_upgrade.md

./helm list --all
jenkins         1               Tue Dec 11 16:25:45 2018        DEPLOYED        jenkins-0.19.0          2.121.3         default

#updates to latest version 
./helm upgrade jenkins stable/jenkins 

#see history
marcin_gluc@cloudshell:~/stub-jenkins2.0/jenkins (co-automation-stub)$ ./helm history jenkins
REVISION        UPDATED                         STATUS          CHART           DESCRIPTION
1               Tue Dec 11 16:25:45 2018        SUPERSEDED      jenkins-0.19.0  Install complete
2               Tue Dec 11 17:38:10 2018        DEPLOYED        jenkins-0.25.0  Upgrade complete

#roll back to revision #1
./helm rollback jenkins 1

#confirm roll back
marcin_gluc@cloudshell:~/stub-jenkins2.0/jenkins (co-automation-stub)$ ./helm list -a
NAME            REVISION        UPDATED                         STATUS          CHART                   APP VERSION     NAMESPACE
cert-manager    1               Tue Dec 11 16:25:35 2018        DEPLOYED        cert-manager-v0.4.1     v0.4.1          kube-system
jenkins         3               Tue Dec 11 17:48:27 2018        DEPLOYED        jenkins-0.19.0          2.121.3         default
nginx-ingress   1               Tue Dec 11 16:25:41 2018        DEPLOYED        nginx-ingress-1.0.1     0.21.0          default


#get all available versions 
./helm search --versions stable/jenkins

#update to specific version 
./helm upgrade jenkins stable/jenkins --version 0.24.0 

#update to specific version and update values.yaml 
./helm upgrade jenkins stable/jenkins --values values.yaml --version 0.25.0 

#manually update plug-ins in gui, restart in gui, then rebuild container to the latest version and reuse old values. Check if plugin updates are overwritten 
./helm upgrade jenkins stable/jenkins --version 0.25.0 --reuse-values