### Prerequisite: Bitwarden token

Ensure the Bitwarden token is pre-loaded. Verify with:

```bash
kubectl get secret bitwarden-access-token-secret -n security -o jsonpath='{.data.token}' | base64 --decode | od -c
```
