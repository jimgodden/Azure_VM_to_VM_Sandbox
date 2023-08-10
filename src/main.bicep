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
param vmSize string = 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('True enables Accelerated Networking and False disabled it.  Not all VM sizes support Accel Net')
param accelNet bool = true

@description('SKU of the Virtual Network Gateway')
param VNG_SKU string = 'VpnGw1'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('If true, Virtual Networks will be connected via Virtual Network Gateway S2S connection.  If false, Virtual Network Peering will be used instead.')
param isUsingVPN bool = true

@description('If true, a Windows VM will be deployed in both source and destination')
param isUsingWindows bool = true

@description('If true, a Linux VM will be deployed in both source and destination')
param isUsingLinux bool = true

// Virtual Networks
module sourceVNET './Modules/VirtualNetwork.bicep' = {
  name: 'srcVNET'
  params: {
    defaultNSG_Name: 'srcNSG'
    firstTwoOctetsOfVNETPrefix: '10.0'
    location: srcLocation
    routeTable_Name: 'srcRT'
    vnet_Name: 'srcVNET'
  }
}

module destinationVNET './Modules/VirtualNetwork.bicep' = {
  name: 'dstVNET'
  params: {
    defaultNSG_Name: 'dstNSG'
    firstTwoOctetsOfVNETPrefix: '10.1'
    location: dstLocation
    routeTable_Name: 'dstRT'
    vnet_Name: 'dstVNET'
  }
}

// Virtual Network Gateways
module sourceVNG 'Modules/VirtualNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'srcVNG'
  params: {
    location: srcLocation
    VNG_ASN: 65530
    VNG_Name: 'srcVNG'
    VNG_Subnet_ResourceID: sourceVNET.outputs.gatewaySubnetID
    VNG_SKU: VNG_SKU
  }
}

module destinationVNG 'Modules/VirtualNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'dstVNG'
  params: {
    location: dstLocation
    VNG_ASN: 65531
    VNG_Name: 'dstVNG'
    VNG_Subnet_ResourceID: destinationVNET.outputs.gatewaySubnetID
    VNG_SKU: VNG_SKU
  }
}
// Connections to the other Virtual Network Gateway
module sourceVNG_Conn 'Modules/VPNConnection.bicep' = if (isUsingVPN) {
  name: 'srcVNG_conn'
  params: {
    bgpPeeringAddress: destinationVNG.outputs.VNGBGPAddress
    destination_ASN: destinationVNG.outputs.VNGASN
    gatewayIPAddress: destinationVNG.outputs.VNGPIP
    location: srcLocation
    resourceNamePrefix: 'src_to_dst'
    VNGResourceID: sourceVNG.outputs.VNGResourceID
    vpn_SharedKey: vpn_SharedKey
  }
}

module destinationVNG_Conn 'Modules/VPNConnection.bicep' = if (isUsingVPN) {
  name: 'dstVNG_conn'
  params: {
    bgpPeeringAddress: sourceVNG.outputs.VNGBGPAddress
    destination_ASN: sourceVNG.outputs.VNGASN
    gatewayIPAddress: sourceVNG.outputs.VNGPIP
    location: dstLocation
    resourceNamePrefix: 'dst_to_src'
    VNGResourceID: destinationVNG.outputs.VNGResourceID
    vpn_SharedKey: vpn_SharedKey
  }
}

// Virtual Network Peerings
module sourceVNETPeering './Modules/VirtualNetworkPeering.bicep' = if (!isUsingVPN) {
  name: 'srctodstPeering'
  params: {
    dstVNET_Name: destinationVNET.outputs.vnetName
    originVNET_Name: sourceVNET.outputs.vnetName
  }
  dependsOn: [
    sourceBastion
  ]
}

module destinationVNETPeering './Modules/VirtualNetworkPeering.bicep' = if (!isUsingVPN) {
  name: 'dsttosrcPeering'
  params: {
    dstVNET_Name: sourceVNET.outputs.vnetName
    originVNET_Name: destinationVNET.outputs.vnetName
  }
  dependsOn: [
    sourceBastion
  ]
}

// Windows Virtual Machines
module sourceVM_Windows './Modules/NetTestVM.bicep' = if (isUsingWindows) {
  name: 'srcVMWindows'
  params: {
    accelNet: accelNet
    location: srcLocation
    nic_Name: 'srcNICWindows'
    subnetID: sourceVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'srcVMWindows'
    vmSize: vmSize
  }
}

module destinationVM_Windows './Modules/NetTestVM.bicep' = if (isUsingWindows) {
  name: 'dstVMWindows'
  params: {
    accelNet: accelNet
    location: dstLocation
    nic_Name: 'dstNICWindows'
    subnetID: destinationVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'dstVMWindows'
    vmSize: vmSize
  }
}

// Linux Virtual Machines
module sourceVM_Linx 'Modules/LinuxNetTestVM.bicep' = if (isUsingLinux) {
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

module destinationVMLinx 'Modules/LinuxNetTestVM.bicep' = if (isUsingLinux) {
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

// Azure Bastion for connecting to the Virtual Machines
module sourceBastion './Modules/Bastion.bicep' = {
  name: 'srcBastion'
  params: {
    bastionSubnetID: sourceVNET.outputs.bastionSubnetID
    location: srcLocation
  }
}

