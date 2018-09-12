#!/bin/bash -ex

sudo apt-get install apt-transport-https

sudo curl -s https://raw.githubusercontent.com/Azure/service-fabric-scripts-and-templates/master/scripts/SetupServiceFabric/SetupServiceFabric.sh | sudo bash

sudo /opt/microsoft/sdk/servicefabric/common/clustersetup/devclustersetup.sh

printf "\nDone.\n"