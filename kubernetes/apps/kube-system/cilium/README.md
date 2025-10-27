# Cilium

## UniFi BGP

router bgp 64513
  bgp router-id 10.0.20.1
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 64514

  neighbor 10.0.20.10 peer-group k8s
  neighbor 10.0.20.11 peer-group k8s
  neighbor 10.0.20.12 peer-group k8s

  address-family ipv4 unicast
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
