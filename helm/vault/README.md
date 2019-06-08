# Vault Helm Chart

## Prerequisites Details
* etcd deployed in the same namespace

## Todo
* Implement removal of roles and policies

## Chart Details
This chart will do the following:

* Implemented a two node vault cluster
* Set up certificates (using helm prehook functionality)
* Initialize vault (using helm init functionality)


### Prehook container

The prehook container vaultcert generates the certificate request, cert and key for Vault

### Init container

The init container sets up the basic roles, policies and  enables kubernetes authentication.
For the following services roles and policies will be generated

 * external dns
 * vaultconfig (the init container)
 * wildcard certificate




## Installing the Chart

To install the chart with the release name `vault`:

```bash
$ helm upgrade --install vault vault --namespace $NAMESPACE
```

The chart will use the 

## Configuration

The following tables lists the configurable parameters of the vault chart and their default values.

| Parameter                  | Description                        | Default                                                    |
| -------------------------- | ---------------------------------- | ---------------------------------------------------------- |
| `replicaCount`             | Number of vault pods               | `2`                                                        |
| `prehook.repository`       | Docker repo for Prehook image      | `connectcd`                                                |
| `prehook.prefix`           | Prehook image name                 | `vaultcert`                                                |
| `prehook.tag`              | Prehook image tag                  | `0.0.2`                                                    |
| `init.repostory`           | Docker repo for Init image         | `connectcd`                                                |
| `init.prefix`              | Init image name                    | `vaultinit`                                                |
| `init.tag`                 | Init  image  tag                   | `azure-0.0.9`                                              |
| `ingress.enabled`          | set up an ingress controller       | `false`                                                    |
| `readiness.readyIfSealed`  | healtcheck if vault is standby     | `false`                                                    |
| `readiness.readyIfStandby` | healtcheck if vault is standby     | `true`                                                     |
| `readiness.readyIfUnititia`| healtcheck if vault is not inited  | `true`                                                     |
| `resources.requests.cpu`   | container requested cpu            | `500m`                                                     |
| `resources.requests.memory`| container requested memory         | `1560Mi`                                                   |
| `resources.limits.cpu`     | container limits cpu               | `100m`                                                     |
| `resources.limits.memory`  | container limits memory            | `128Mi`                                                    |
| `service.type`             | Type of the service                | `ClusterIP`                                                |
| `service.port`             | Service port                       | `8200`                                                     |



> **Tip**: You can use the default [values.yaml](values.yaml)

# Usage 

```bash
kubectl port-forward -n $NAMEPSACE deployment/vault   8200:8200
vault 
```

# Deep dive

## Vault Health

## Scaling

