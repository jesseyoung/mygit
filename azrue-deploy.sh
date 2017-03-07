{
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "storageAccountType": {
            "type": "string",
            "defaultValue": "Standard_LRS",
            "allowedValues": [
                "Standard_LRS",
                "Standard_ZRS",
                "Standard_GRS",
                "Standard_RAGRS",
                "Premium_LRS"
            ]
        },
        "virtualMachineName": {
            "type": "string",
            "defaultValue": "actionCentOSVm",
            "minLength": 1
        },
        "virtualMachineAdminUserName": {
            "type": "string",
            "defaultValue": "actionCentOSUser",
            "minLength": 1
        },
        "virtualMachineAdminPassword": {
            "defaultValue": "#actionsky$1",
            "type": "securestring"
        },
        "virtualMachineCentOSVersion": {
            "type": "string",
            "defaultValue": "6.8",
            "allowedValues": [
                "6.8",
                "7.1"
            ]
        },

        "publicIPAddresses_actionTestVM_ip_name": {
            "defaultValue": "actiontestvmip",
            "type": "String"
        },

        "mysqlMasterServer": {
            "type": "string",
            "defaultValue": "actionmaster"
        },
        "mysqlSlaveServer": {
            "type": "string",
            "defaultValue": "actionslave"
        },
        "mysqlUser": {
            "type": "string",
            "defaultValue": "action",
        },
        "mysqlUserPassword": {
            "type": "securestring",
            "defaultValue": "actionsky",
        },
        "mysqlPorts": {
            "type": "string",
            "defaultValue": "3306",
        },
        "mysqlDBName": {
            "type": "string",
            "defaultValue": "actionsky",
        }
    },
    "resources": [
        {
            "name": "[parameters('mysqlMasterServer')]",
            "type": "Microsoft.MySql/servers",
            "location": "chinaeast",
            "apiVersion": "2015-09-01",
            "sku": { "name": "MS1" },
            "properties": {
                "dailyBackupTimeInHour": 10,
                "version": "5.6"
            },
            "dependsOn": [],
            "tags": {
                "displayName": "action_master"
            }
        },
        {
            "name": "[concat(parameters('mysqlMasterServer'), '/', parameters('mysqlUser'))]",
            "type": "Microsoft.MySql/servers/users",
            "apiVersion": "2015-09-01",
            "properties": {
                "password": "[parameters('mysqlUserPassword')]"
            },
            "dependsOn": ["[concat('Microsoft.MySql/servers/', parameters('mysqlMasterServer'))]"],
            "tags": {
                "displayName": "action_user"
            }
        },
        {
            "name": "[parameters('mysqlSlaveServer')]",
            "type": "Microsoft.MySql/servers",
            "location": "chinaeast",
            "apiVersion": "2015-09-01",
            "sku": { "name": "MS1" },
            "properties": {
                "dailyBackupTimeInHour": 10,
                "version": "5.6",
                "replicationMode": "AzureSlave",
                "creationSource": {
                    "server": "[parameters('mysqlMasterServer')]",
                    "region": "chinaeast"
                }
            },
            "dependsOn": ["[concat('Microsoft.MySql/servers/', parameters('mysqlMasterServer'))]"],
            "tags": {
                "displayName": "action_slave"
            }
        },
        {
            "name": "[concat(parameters('mysqlMasterServer'), '/', parameters('mysqlDBName'))]",                         //部署 database
            "type": "Microsoft.MySql/servers/databases",
            "apiVersion": "2015-09-01",
            "properties": {
                "Charset": "utf8",
                "Collation": "utf8_general_ci"
            },
            "dependsOn": ["[concat('Microsoft.MySql/servers/', parameters('mysqlMasterServer'))]"],
            "tags": {
                "displayName": "action_db"
            }
        },
        {
            "name": "[concat(parameters('mysqlMasterServer'), '/', parameters('mysqlDBName'), '/', parameters('mysqlUser'))]",                   // 部署用户权限，用户权限是在database下面的，并且名字必须和其中需要配置权限的用户名相同，所以必须先部署database和user
            "type": "Microsoft.MySql/servers/databases/privileges",
            "apiVersion": "2015-09-01",
            "properties": {
                "level": "ReadWrite",
            },
            "dependsOn": [
                          "[concat('Microsoft.MySql/servers/', parameters('mysqlMasterServer'), '/users/', parameters('mysqlUser'))]",
                          "[concat('Microsoft.MySql/servers/', parameters('mysqlMasterServer'), '/databases/', parameters('mysqlDBName'))]"
                         ],
            "tags": {
                "displayName": "action_privileges"
            }
        },
        {
            "name": "virtualNetwork2",
            "type": "Microsoft.Network/virtualNetworks",
            "location": "chinaeast",
            "apiVersion": "2015-06-15",
            "dependsOn": ["[concat('Microsoft.MySql/servers/', parameters('mysqlSlaveServer'))]"],
            "tags": {
                "displayName": "virtualNetwork2"
            },
            "properties": {
                "addressSpace": {
                    "addressPrefixes": [
                        "[variables('virtualNetworkPrefix')]"
                    ]
                },
                "subnets": [
                    {
                        "name": "[variables('virtualNetworkSubnet1Name')]",
                        "properties": {
                            "addressPrefix": "[variables('virtualNetworkSubnet1Prefix')]"
                        }
                    },
                    {
                        "name": "[variables('virtualNetworkSubnet2Name')]",
                        "properties": {
                            "addressPrefix": "[variables('virtualNetworkSubnet2Prefix')]"
                        }
                    }
                ]
            }
        },
        {
            "name": "[variables('virtualMachineNicName')]",
            "type": "Microsoft.Network/networkInterfaces",
            "location": "chinaeast",
            "apiVersion": "2015-06-15",
            "dependsOn": [
                "[concat('Microsoft.Network/virtualNetworks/', 'virtualNetwork2')]"
            ],
            "tags": {
                "displayName": "virtualMachineNic2"
            },
            "properties": {
                "ipConfigurations": [
                    {
                        "name": "ipconfig1",
                        "properties": {
                            "privateIPAddress": "10.0.0.4",
                            "privateIPAllocationMethod": "Dynamic",
                            "publicIPAddress": {
                                "id": "[resourceId('Microsoft.Network/publicIPAddresses/', parameters('publicIPAddresses_actionTestVM_ip_name'))]"
                            },
                            "subnet": {
                                "id": "[variables('virtualMachineSubnetRef')]"
                            }
                        }
                    }
                ]
            }
        },
        {
            "type": "Microsoft.Network/publicIPAddresses",
            "name": "[parameters('publicIPAddresses_actionTestVM_ip_name')]",
            "apiVersion": "2015-06-15",
            "location": "chinaeast",
            "dependsOn": ["[concat('Microsoft.MySql/servers/', parameters('mysqlSlaveServer'))]"],
            "properties": {
                "publicIPAllocationMethod": "Dynamic",
                "idleTimeoutInMinutes": 4,
                "dnsSettings": {
                "domainNameLabel": "[parameters('publicIPAddresses_actionTestVM_ip_name')]"
                }

            },
            "resources": [],
        },
        {
            "name": "[variables('storageAccountName')]",
            "type": "Microsoft.Storage/storageAccounts",
            "location": "chinaeast",
            "apiVersion": "2015-06-15",
            "dependsOn": ["[concat('Microsoft.Network/networkInterfaces/', variables('virtualMachineNicName'))]"],
            "tags": {
                "displayName": "storageAccount"
            },
            "properties": {
                "accountType": "[parameters('storageAccountType')]"
            }
        },
        {
            "name": "[parameters('virtualMachineName')]",
            "type": "Microsoft.Compute/virtualMachines",
            "location": "chinaeast",
            "apiVersion": "2015-06-15",
            "dependsOn": [
                "[concat('Microsoft.Storage/storageAccounts/', variables('storageAccountName'))]",
                "[concat('Microsoft.Network/networkInterfaces/', variables('virtualMachineNicName'))]"
            ],
            "tags": {
                "displayName": "virtualMachine"
            },
            "properties": {
                "hardwareProfile": {
                    "vmSize": "[variables('virtualMachineVmSize')]"
                },
                "osProfile": {
                    "computerName": "[parameters('virtualMachineName')]",
                    "adminUsername": "[parameters('virtualMachineAdminUsername')]",
                    "adminPassword": "[parameters('virtualMachineAdminPassword')]"
                },
                "storageProfile": {
                    "imageReference": {
                        "publisher": "[variables('virtualMachineImagePublisher')]",
                        "offer": "[variables('virtualMachineImageOffer')]",
                        "sku": "[parameters('virtualMachineCentOSVersion')]",
                        "version": "latest"
                    },
                    "osDisk": {
                        "name": "virtualMachineOSDisk",
                        "vhd": {
                            "uri": "[concat('http://', variables('storageAccountName'), '.blob.core.chinacloudapi.cn/', variables('virtualMachineStorageAccountContainerName'), '/', variables('virtualMachineOSDiskName'), '.vhd')]"
                        },
                        "caching": "ReadWrite",
                        "createOption": "FromImage"
                    }
                },
                "networkProfile": {
                    "networkInterfaces": [
                        {
                            "id": "[resourceId('Microsoft.Network/networkInterfaces', variables('virtualMachineNicName'))]"
                        }
                    ]
                }
            }
        },
        {
            "type": "Microsoft.Compute/virtualMachines/extensions",
            "name": "actionCentOSVm/azureVmUtils2",
            "apiVersion": "2015-06-15",
            "location": "chinaeast",
            "dependsOn": ["[concat('Microsoft.Compute/virtualMachines/', parameters('virtualMachineName'))]"],
            "properties": {
                "publisher": "Microsoft.Azure.Extensions",
                "type": "CustomScript",
                "typeHandlerVersion": "2.0",
                "settings": {
                    "fileUris": [
                        "https://raw.githubusercontent.com/jesseyoung/mygit/master/dbproxy_install.sh"
                    ],
                    "commandToExecute": "[concat('bash dbproxy_install.sh ',variables('mysqlMasterURL'), ' ', parameters('mysqlPorts'), ' ', variables('mysqlUserFullName'), ' ', parameters('mysqlUserPassword'), ' ', variables('mysqlSlaveURL'), ' ', parameters('mysqlPorts'), ' ', variables('mysqlUserFullName'), ' ', parameters('mysqlUserPassword'))]"
                }
            }
        },
    ],
    "variables": {
        "storageAccountName": "centosstorageaccount",
        "virtualNetworkPrefix": "10.0.0.0/16",
        "virtualNetworkSubnet1Name": "Subnet-1",
        "virtualNetworkSubnet1Prefix": "10.0.0.0/24",
        "virtualNetworkSubnet2Name": "Subnet-2",
        "virtualNetworkSubnet2Prefix": "10.0.1.0/24",
        "virtualMachineImagePublisher": "OpenLogic",
        "virtualMachineImageOffer": "CentOS",
        "virtualMachineOSDiskName": "virtualMachineOSDisk",
        "virtualMachineVmSize": "Standard_D1",
        "virtualMachineVnetID": "[resourceId('Microsoft.Network/virtualNetworks', 'virtualNetwork2')]",
        "virtualMachineSubnetRef": "[concat(variables('virtualMachineVnetID'), '/subnets/', variables('virtualNetworkSubnet1Name'))]",
        "virtualMachineStorageAccountContainerName": "vhds",
        "virtualMachineNicName": "[concat(parameters('virtualMachineName'), 'NetworkInterface')]",
        "mysqlMasterURL": "[concat(parameters('mysqlMasterServer'), '.mysqldb.chinacloudapi.cn')]",
        "mysqlSlaveURL": "[concat(parameters('mysqlSlaveServer'), '.mysqldb.chinacloudapi.cn')]",
        "mysqlUserFullName": "[concat(parameters('mysqlMasterServer'), '%', parameters('mysqlUser'))]",
        "mysqlUserPasswd": "[parameters('mysqlUserPassword')]",
        "mysqlPort": "[parameters('mysqlPorts')]",
    }
}
