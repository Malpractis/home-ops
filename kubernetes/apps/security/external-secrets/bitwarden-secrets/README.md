# How to use Bitwarden Secrets Manager

### Manual
- https://github.com/external-secrets/external-secrets/blob/main/docs/provider/bitwarden-secrets-manager.md
- https://cert-manager.io/docs/configuration/selfsigned/#bootstrapping-ca-issuers
- https://cert-manager.io/docs/concepts/ca-injector/

### Code
- https://github.com/external-secrets/bitwarden-sdk-server
- https://github.com/external-secrets/external-secrets/blob/main/docs/snippets/bitwarden-secrets-manager-secret-store.yaml


Create the token secret ensuring no /n at the end of your secret:
kubectl create secret generic bitwarden-access-token-secret --from-literal=token=$(printf '%s' 'SECRET_HERE') -n security

You can check your secret by running:
kubectl get secret bitwarden-access-token-secret -n security -o jsonpath='{.data.token}' |base64 --decode | od -c
If it ends in \n it will not allow you to login to bitwarden.
