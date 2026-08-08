**playme@debian:~$** nmcli device status
DEVICE         TYPE      STATE                   CONNECTION
lo             loopback  connected (externally)  lo
virbr0         bridge    connected (externally)  virbr0
wlan0          wifi      disconnected            --
p2p-dev-wlan0  wifi-p2p  disconnected            --
enp3s0         ethernet  unavailable             --

**playme@debian:~$** nmcli connection add type bond \
>con-name bond0 \
>ifname bond0 \
>bond.options "mode=active-backup"
Connection 'bond0' (debfdf09-bbef-4b6f-a21a-8cc49938e0c5) successfully added.

**playme@debian:~$** nmcli connection show
NAME                UUID                                  TYPE      DEVICE
Wired connection 2  2684f562-aaf5-3452-8721-119dc43e2dea  ethernet  enp10s0
Wired connection 1  4cf0bd22-0bca-4225-8b45-6e8771fef901  ethernet  enp1s0
Wired connection 3  b5d7dd99-4e3b-39b5-a725-f0d51b261a73  ethernet  enp8s0
Wired connection 4  91269f26-7585-3d21-8358-0736fe790759  ethernet  enp9s0
bond0               debfdf09-bbef-4b6f-a21a-8cc49938e0c5  bond      bond0
lo                  129cd425-f448-4963-ab8d-e4daba008803  loopback  lo

**playme@debian:~$** nmcli connection modify bond0 \
> ipv4.addresses 192.168.122.111/24 \
> ipv4.gateway 192.168.122.1 \
> ipv4.dns 192.168.122.1 \
> ipv4.method manual

**playme@debian:~$** nmcli connection add type ethernet \
> slave-type bond \
> con-name bond0-port1 \
> ifname enp8s0 \
> master bond0

**playme@debian:~$** nmcli connection add type ethernet \
> slave-type bond \
> con-name bond0-port2 \
> ifname enp9s0 \
> master bond0

**playme@debian:~$** nmcli connection show
NAME                UUID                                  TYPE      DEVICE
Wired connection 1  4cf0bd22-0bca-4225-8b45-6e8771fef901  ethernet  enp1s0
bond0               debfdf09-bbef-4b6f-a21a-8cc49938e0c5  bond      bond0
bond0-port1         78afe379-5f28-429d-af9f-c13810a05b33  ethernet  enp8s0
bond0-port2         475a612a-26f4-4ca6-9eeb-cffa96f7074f  ethernet  enp9s0
lo                  129cd425-f448-4963-ab8d-e4daba008803  loopback  lo
ethernet            7925e866-1e3a-4c28-a3d2-34890cb7de05  ethernet  --
Wired connection 2  2684f562-aaf5-3452-8721-119dc43e2dea  ethernet  --
Wired connection 3  b5d7dd99-4e3b-39b5-a725-f0d51b261a73  ethernet  --
Wired connection 4  91269f26-7585-3d21-8358-0736fe790759  ethernet  --

**playme@debian:~$** cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v6.12.101+deb13-amd64

Bonding Mode: fault-tolerance (active-backup)
Primary Slave: None
Currently Active Slave: enp8s0
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0

Slave Interface: enp8s0
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 0
Permanent HW addr: 52:54:00:7c:75:2c
Slave queue ID: 0

**playme@debian:~$** nmcli device connect enp9s0
>Device 'enp9s0' successfully activated with '475a612a-26f4-4ca6-9eeb-cffa96f7074f'.

**playme@debian:~$** nmcli device disconnect enp8s0
>Device 'enp8s0' successfully disconnected.

**playme@debian:~$** nmcli device connect enp8s0
>Device 'enp8s0' successfully activated with '78afe379-5f28-429d-af9f-c13810a05b33'.
