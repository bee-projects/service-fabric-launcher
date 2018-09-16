#!/bin/bash -ex

function clean() {
    rm -rf *tfstate*
    rm -rf .terraform
}

terraform init
terraform plan
terraform apply -auto-approve

