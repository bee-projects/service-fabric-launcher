# Deploying to Service Fabric via Docker Compose

## Install Azure Service Fabric CLI
Install the `sfctl` client tool as describe [here](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cli#install-pip-python-and-the-service-fabric-cli)

```
pip install sfctl
sfctl -h
```

## Select your cluster

Use the following command to target the CLI at your cluster:

```
sfctl cluster select --endpoint http://testcluster.com:19080
```

## Deploy a compose file

Deploy a compose file using the following command:

```
sfctl compose create --deployment-name TestApp --file-path docker-compose.yml
```