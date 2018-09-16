
# Overview

This folder contains [terraform scripts](./main.tf) to luanch a developement environment of Microsoft's [Service Fabric](https://github.com/Microsoft/service-fabric) on the Google Cloud platform.

The diagram below illustrates the infrastructure that will get created:
 

![Deployment Diagram](./images/Diagram.png)

## Running the sample

- Clone this repository
- Ensure you're in this (gcp/linux)
- Run a `terraform init`, `terraform plan` and `terraform apply` to create your service fabric environment. 

```
Outputs:

external_ip = 35.241.32.234
```
- Hit `external_ip` that gets output to see your Service Fabric cluster:

![Service Fabric Cluster](./images/sfabric.png)

- Run a `terraform destroy` to teardown your deployment




