
#https://github.com/DefectDojo/django-DefectDojo/blob/master/KUBERNETES.md

# https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
# Create a TLS secret called minikube-tls as mentioned above, e.g.
K8S_NAMESPACE="shsp-falco"
TLS_CERT_DOMAIN="${K8S_NAMESPACE}.shsp-falco.local"
CA_DIR="./CA_DIR"


pass=$(at /dev/random | LC_ALL=C tr -dc a-zA-Z0-9 | head -c 32; echo)
bash setupcerts
bash setupcerts-pt2
exit


kubectl --namespace "${K8S_NAMESPACE}" create secret tls defectdojo-tls \
  --key <(openssl rsa \
    -in "${CA_DIR}/private/${TLS_CERT_DOMAIN}.key.pem" \
    -passin "pass:${TLS_CERT_PASSWORD}") \
  --cert <(cat \
    "${CA_DIR}/certs/${TLS_CERT_DOMAIN}.cert.pem" \
    "${CA_DIR}/chain.pem")
# Install Helm chart. Choose a host name that matches the certificate above
helm install \
  ./helm/defectdojo \
  --name=defectdojo \
  --namespace="${K8S_NAMESPACE}" \
  --set host="defectdojo.${TLS_CERT_DOMAIN}" \
  --set django.ingress.secretName="minikube-tls"

# For high availability deploy multiple instances of Django, Celery and RabbitMQ
helm install \
  ./helm/defectdojo \
  --name=defectdojo \
  --namespace="${K8S_NAMESPACE}" \
  --set host="defectdojo.${TLS_CERT_DOMAIN}" \
  --set django.ingress.secretName="minikube-tls" \
  --set django.replicas=3 \
  --set celery.replicas=3 \
  --set rabbitmq.replicas=3

# Run highly available PostgreSQL cluster instead of MySQL - recommended setup
# for production environment.
helm install \
  ./helm/defectdojo \
  --name=defectdojo \
  --namespace="${K8S_NAMESPACE}" \
  --set host="defectdojo.${TLS_CERT_DOMAIN}" \
  --set django.replicas=3 \
  --set celery.replicas=3 \
  --set rabbitmq.replicas=3 \
  --set django.ingress.secretName="minikube-tls" \
  --set mysql.enabled=false \
  --set database=postgresql \
  --set postgresql.enabled=true \
  --set postgresql.replication.enabled=true \
  --set postgresql.replication.slaveReplicas=3

# Note: If you run `helm install defectdojo before, you will get an error
# message like `Error: release defectdojo failed: secrets "defectdojo" already
# exists`. This is because the secret is kept across installations.
# To prevent recreating the secret, add --set createSecret=false` to your
# command.

# Run test. If there are any errors, re-run the command without `--cleanup` and
# inspect the test container.
helm test defectdojo --cleanup
