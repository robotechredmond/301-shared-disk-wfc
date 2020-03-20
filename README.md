# Windows Server 2019 Failover Cluster using Azure Shared Disk
This template will provision a base two-node Windows Server 2019 Failover Cluster using Azure Shared Disk.

This template creates the following resources in the selected Azure Region:

+   Standard Storage Account for a Cloud Witness
+	Proximity Placement Group and Availability Set for cluster node VMs
+   Two cluster node VMs running Windows Server 2019
+   One Azure Shared Disk
+   Internal Load Balancer to provide a listener IP Address
+   Azure Load Balancer for outbound SNAT support

## Prerequisites

To successfully deploy this template, the following must already be provisioned in your subscription:

+   Azure Virtual Network with subnet defined for cluster node VMs and ILB
+   Windows Server Active Directory and AD-integrated DNS reachable from Azure Virtual Network
+   Subnet IP address space defined in AD Sites and Services
+   Custom DNS Server Settings configured on Azure Virtual Network to point to DNS servers

To deploy the required Azure VNET and Active Directory infrastructure, if not already in place, you may use <a href="https://github.com/Azure/azure-quickstart-templates/tree/master/active-directory-new-domain-ha-2-dc">this template</a> to deploy the prerequisite infrastructure. 

## Deploying Sample Templates

Click the button below to deploy from the portal:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frobotechredmond%2F301-shared-disk-wfc%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Frobotechredmond%2F301-shared-disk-wfc%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

## Notes

+	This base Windows Server Failover Cluster template does not deploy clustered roles or workloads.  Instead, it is intended to serve as a base template to which specific clustered workloads may be added.

+ 	The images used to create this deployment are
	+ 	Windows Server 2019 Datacenter - Latest Image

Tags: ``cluster, ha, shared disk, windows server 2019, ws2019``
