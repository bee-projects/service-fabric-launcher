#!/bin/bash -ex

rm -rf *tfstate*
terraform init
terraform plan
terraform apply -auto-approve

