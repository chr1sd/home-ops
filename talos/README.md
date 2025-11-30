### Bonded Interface Notes
Bonded interfaces are useful when you need to use one physical network adapter and create multiple VLAN virtual adapters on that adapter.

Good examples are for IOT devices and VPN traffic. With VLAN tagged network devices you can use a tool like Multus to assign a different network to the the virtual adapters and then pods can take advantage of that network.
#### Documenting some of my struggles with Talos and Multus
Example Talos Machine Config:

```
machine:
  network:
    interfaces:
    - interface: bond0
      bond:
        deviceSelectors:
          - driver: e1000e
            hardwareAddr: 10:e7:c6:16:*
        mode: active-backup
      dhcp: false
      mtu: 1500
      vlans:
        - # VPN
          vlanId: 87
          dhcp: false
          addresses:
            - 10.13.87.19/24
          mtu: 1500
```

You MUST specify a driver within deviceSelectors. Otherwise, you'll see this error in the Talos logs:

`error enslaving/unslaving link \"bond0.87\" under \"bond0\": netlink receive: device or resource busy`

Optional, but maybe needed is an address for the vlan device. Most repos do not have an address, but others have said they needed an address within the VLAN subnet defined.

I currently have an address defined for the VLAN network adapter. I'm going to experiment with removing it in the future and see how the pods reaact.

### Different Devices Will Have Different Drivers

Don't blindly use "e1000e". That's what mine happens to be.

Get your driver with talosctl. Replace the node IP with your node's IP and adjust your link name because it might not be eno1. There are several commands you can run to get the link (adapter) name.

`talosctl -n 10.13.17.19 read /proc/net/dev` - look for the adapter that has a lot of bytes and packets transmitted.

`talosctl -n 10.13.17.19 get links` - look for the adapter that matches the MAC address you defined in your machine configs.

```
talosctl -n 10.13.17.19 get links eno1 -o yaml

    slaveKind: bond
    busPath: 0000:00:1f.6
    pciID: 8086:15E3
    driver: e1000e    <<<<---------------------
    driverVersion: 6.12.57-talos
    firmwareVersion: 0.1-4
    productID: "0x15e3"
    vendorID: "0x8086"
    product: Ethernet Connection (5) I219-LM
    vendor: Intel Corporation
```