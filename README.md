[![Build Status](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release.png)](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release)



# bosh-cloudstack-cpi-release

This is work in progress / feedbacks welcome (use issues).


## Design :
* this CPI is a Bosh external CPI i.e a dedicated bosh release wich must be deployed alongside a bosh release OR configured with bosh release in a bosh-init yml manifest
*  CPI business logic is in a dedicated spring boot app, included in bosh-cloudstack-cpi-release, called cpi-core. This java component has a dedicated template / monit service.
* leverages Apache Jclouds support for CloudStack, nice java adapter for Cloudstack API
* supports Cloudstack advanced zone
* secondary / ephemeral implemented as cloudstack volume (no ephemeral disk concept in CloudStack).
* TBC: uses an http server to enable stemcell / template loading by cloudstack (other option was create volume and transform to template, required bosh / bosh-init to be hosted in the target cloud / tenant).
* Out of Scope : security groups provisioning / CS Basic Zones

## Typical bosh.yml configuration to activate the CloudStack external CPI

```yml

# add the cpi bosh release
releases:
- {name: bosh, version: "185"}
- {name:  bosh-cloudstack-cpi, version: latest}

# add the template for cpi-core rest server
jobs:
- name: bosh_apidata
  templates:
  - {name: nats, release: bosh}
  - {name: redis, release: bosh}
  - {name: postgres, release: bosh}
  - {name: blobstore, release: bosh}
  - {name: director, release: bosh}
  - {name: health_monitor, release: bosh}
  - {name: powerdns, release: bosh}
  - {name: cpi, release: bosh-cloudstack-cpi}


# activate external cpi
properties:
  director:
    cpi_job: cpi

# set external cpi credentials
   cloudstack:
      endpoint: <your_end_point_url> # Ask for your administrator
      api_key: <your_api_key> # You can find at your user page
      secret_access_key: <your_secret_access_key> # Same as above
      default_key_name: <default_keypair_name> # Your keypair name (see the next section)
      private_key: <path_to_your_private_key> # The path to the private key file of your key pair
      state_timeout: 600
      state_timeout_volume: 1200
      stemcell_public_visibility: true
      default_zone: <default_zone_name> # Zone name
      proxy_host: <proxy to cloudstack api> #proxy acces active if set
      proxy_port: <proxy port>
      proxy_user: <proxy user>
      proxy_password: <proxy password>
      
```


Typical bosh manifest to deploy on cloudstack

```yml


---
name: xxx
director_uuid: zzzz

disk_pools:
  - name: d-pool
    disk_size: 10240
    cloud_properties: 
      type: gp2

resource_pools:
  - name: vm-pool
    network: net
    stemcell: 
      name: bosh-cloudstack-xen-ubuntu-trusty-go_agent
      version: latest
    cloud_properties:
      compute_offering: "CO1 - Small STD" # <--- Replace with Cloudstack Compute Offering
      ephemeral_disk_offering: "ephemeral" # <--- Replace with Cloudstack Storage Offering
      disk: 8192       

networks:
- name: private
  type: manual 
  subnets:     
  - range: 10.203.7.254/23
    gateway: 10.203.7.254 
    dns: [10.203.6.3]     
    cloud_properties: {name: NET_CS} # <--- Replace with Cloudstack Network name



```