@description('Azure Datacenter location for the source resources')
param srcLocation string = resourceGroup().location

@description('Azure Datacenter location for the destination resources')
param dstLocation string

@description('Username for the admin account of the Virtual Machines')
param vm_adminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param vm_adminPassword string

@description('Password for the Virtual Machine Admin User')
param vmSize string = 'Standard_D2s_v3'

@description('True enables Accelerated Networking and False disabled it.  Not all VM sizes support Accel Net')
param accelNet bool = true

module sourceVNET './Modules/VirtualNetwork.bicep' = {
  name: 'srcVNET'
  params: {
    defaultNSG_Name: 'srcNSG'
    firstTwoOctetsOfVNETPrefix: '10.200'
    location: srcLocation
    routeTable_Name: 'srcRT'
    vnet_Name: 'srcVNET'
  }
}

module sourceVNETPeering './Modules/VirtualNetworkPeering.bicep' = {
  name: 'srctodstPeering'
  params: {
    dstVNET_Name: destinationVNET.outputs.vnetName
    originVNET_Name: sourceVNET.outputs.vnetName
  }
  dependsOn: [
    sourceBastion
  ]
}

module sourceVM './Modules/NetTestVM.bicep' = {
  name: 'srcVM'
  params: {
    accelNet: accelNet
    location: srcLocation
    nic_Name: 'srcNIC'
    subnetID: sourceVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'srcVM'
    vmSize: vmSize
  }
}

module sourceBastion './Modules/Bastion.bicep' = {
  name: 'srcBastion'
  params: {
    bastionSubnetID: sourceVNET.outputs.bastionSubnetID
    location: srcLocation
  }
}

module sourceVMLinx 'Modules/LinuxNetTestVM.bicep' = {
  name: 'srcVMLinux'
  params: {
    accelNet: accelNet
    location: srcLocation
    nic_Name: 'srcNICLinux'
    subnetID: sourceVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'srcVMLinux'
    vmSize: vmSize
  }
}

module destinationVNET './Modules/VirtualNetwork.bicep' = {
  name: 'dstVNET'
  params: {
    defaultNSG_Name: 'dstNSG'
    firstTwoOctetsOfVNETPrefix: '10.201'
    location: dstLocation
    routeTable_Name: 'dstRT'
    vnet_Name: 'dstVNET'
  }
}

module destinationVNETPeering './Modules/VirtualNetworkPeering.bicep' = {
  name: 'dsttosrcPeering'
  params: {
    dstVNET_Name: sourceVNET.outputs.vnetName
    originVNET_Name: destinationVNET.outputs.vnetName
  }
  dependsOn: [
    sourceBastion
  ]
}

module destinationVM './Modules/NetTestVM.bicep' = {
  name: 'dstVM'
  params: {
    accelNet: accelNet
    location: dstLocation
    nic_Name: 'dstNIC'
    subnetID: destinationVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'dstVM'
    vmSize: vmSize
  }
}

module destinationVMLinx 'Modules/LinuxNetTestVM.bicep' = {
  name: 'dstVMLinux'
  params: {
    accelNet: accelNet
    location: dstLocation
    nic_Name: 'dstNICLinux'
    subnetID: destinationVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'dstVMLinux'
    vmSize: vmSize
  }
}

