### Bonded Interface Notes
Bonded interfaces are useful when you need to use one physical network adapter and create multiple VLAN virtual adapters on that adapter.

Good examples are for IOT devices and VPN traffic. With VLAN tagged network devices you can use a tool like Multus to assign a different network to the the virtual adapters and then pods can take advantage of that network.

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

### Check the Pod for Multus Network Connectivity

Connect to the pod that is using the additional network you defined in Multus. There are a few commands you can run to validate that it's routing traffic through the additional network.

1. Connect to the pod
`kubectl -n default exec -it qbittorrent-9b487874-lbthn -- sh`

2. List the IP addresses for the pod. You want to see the IP address you defined in the deployment files.
`ip addr list`
```
5: net1@if9: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP qlen 1000
    link/ether ee:66:43:b3:48:ff brd ff:ff:ff:ff:ff:ff
    inet 10.13.87.51/24 brd 10.13.87.255 scope global net1
       valid_lft forever preferred_lft forever
```
3. List the routes the pod is using. You want to see the routes you defined for the network in Multus.
`ip route list`
```
0.0.0.0/5 via 10.13.87.1 dev net1
default via 10.244.2.234 dev eth0
8.0.0.0/7 via 10.13.87.1 dev net1
10.13.87.0/24 dev net1 scope link  src 10.13.87.51
10.244.2.234 dev eth0 scope link
11.0.0.0/8 via 10.13.87.1 dev net1
12.0.0.0/6 via 10.13.87.1 dev net1
16.0.0.0/4 via 10.13.87.1 dev net1
32.0.0.0/3 via 10.13.87.1 dev net1
64.0.0.0/2 via 10.13.87.1 dev net1
128.0.0.0/3 via 10.13.87.1 dev net1
160.0.0.0/5 via 10.13.87.1 dev net1
168.0.0.0/6 via 10.13.87.1 dev net1
172.0.0.0/12 via 10.13.87.1 dev net1
172.32.0.0/11 via 10.13.87.1 dev net1
172.64.0.0/10 via 10.13.87.1 dev net1
172.128.0.0/9 via 10.13.87.1 dev net1
173.0.0.0/8 via 10.13.87.1 dev net1
174.0.0.0/7 via 10.13.87.1 dev net1
176.0.0.0/4 via 10.13.87.1 dev net1
192.0.0.0/9 via 10.13.87.1 dev net1
192.128.0.0/11 via 10.13.87.1 dev net1
192.160.0.0/13 via 10.13.87.1 dev net1
192.169.0.0/16 via 10.13.87.1 dev net1
192.170.0.0/15 via 10.13.87.1 dev net1
192.172.0.0/14 via 10.13.87.1 dev net1
192.176.0.0/12 via 10.13.87.1 dev net1
192.192.0.0/10 via 10.13.87.1 dev net1
193.0.0.0/8 via 10.13.87.1 dev net1
194.0.0.0/7 via 10.13.87.1 dev net1
196.0.0.0/6 via 10.13.87.1 dev net1
200.0.0.0/5 via 10.13.87.1 dev net1
208.0.0.0/4 via 10.13.87.1 dev net1
224.0.0.0/3 via 10.13.87.1 dev net1
```
4. Ping the default gateway of the subnet your bonded VLAN network address. You need a response here.
`ping 10.13.87.1`
```
PING 10.13.87.1 (10.13.87.1): 56 data bytes
64 bytes from 10.13.87.1: seq=0 ttl=42 time=0.643 ms
64 bytes from 10.13.87.1: seq=1 ttl=42 time=0.626 ms
64 bytes from 10.13.87.1: seq=2 ttl=42 time=0.605 ms
64 bytes from 10.13.87.1: seq=3 ttl=42 time=0.442 ms
64 bytes from 10.13.87.1: seq=4 ttl=42 time=0.574 ms
```
5. See what the external IP address of the pod is. YOU DON'T WANT YOUR ISP ADDRESS HERE. It should be the VPN address. My VPN client is configured in Unifi and I can see the IP address of the client in the Unifi Network console to validate what the pod has.
`curl ifconfig.me`
```
~ $ curl ifconfig.me
184.75.221.59~
```

If your results are as described here then your pod is connected to the Multus network and routing traffic through that network.