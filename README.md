[![Build Status](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release.png)](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release)



# bosh-cloudstack-cpi-release

This is work in progress / feedbacks welcome (use issues).


## Design :
* this CPI is a Bosh external CPI i.e a dedicated bosh release wich must be deployed alongside a bosh release OR configured with bosh release in a bosh-init yml manifest
*  CPI business logic is in a dedicated spring boot app, included in bosh-cloudstack-cpi-release, called cpi-core. This java component has a dedicated template / monit service.
* leverages Apache Jclouds support for CloudStack, nice java adapter for Cloudstack API
* supports Cloudstack advanced zone
* secondary / ephemeral implemented as cloudstack volume (no ephemeral disk concept in CloudStack).
* Uses a webdav http server to enable stemcell / template loading by cloudstack (other option was create volume and transform to template, required bosh / bosh-init to be hosted in the target cloud / tenant). This webdav server is started from the spring boot cpi core jvm

* Out of Scope : security groups provisioning / CS Basic Zones

## Current Status:



### Global status
* micro-bosh creation (with an externally launched cpi-core process)
* compilation vms ok, blobstore ok
* bosh-master creation from micro-bosh
* concourse creation from bosh-master
	
### Issues
* local storage issues (persistent disks happen to not be on the same host as vm when reconfiguring a deployment)
* ip conflicts when recreating vm, due to cloudstack expunge delay (orig vm is destroyed but ip not yet releases)
* disk / mount issues (probably related to vm expunge delay)
* stemcell agent.json user data url is hardcoded. must find a way to find the correct cloudstack userdata url on the fly
* stemcell : cant get keys from cloudstack metadata (requires stemcell code change to match cloudstack)
* no support for vip / floating ip yet	


## TODO

* run Director BATS against the cpi
	https://github.com/cloudfoundry/bosh/blob/master/docs/running_tests.md

* expunge vm
	required with static ip vms (ip not freed until vm is expunged)
	default value expunge.delay = 300 (5 mins)
	option 1
		reduce to 30s as cloudstack admin => need to restart management server 
		wait 30s in CPI after vm delete
	option2
		expunge with cloudstack API. option not avail in jclouds 1.9, use escaping mechanism to add the expunge flag?
* check template publication
	from cpi-core webdav, only public template possible ?
	validate publication state (instant OK for registering, need to wait for the ssvm (secondary storage vm) to copy the template
	connectivity issue when cloudstack tries asynchronously to copy template : vlan opened, dedicated chunk encoding compatible spring boot endpoint
	(workaround: mock template mode in cpi. copies an existing template and use it as a stemcell image)
	
	add a garbarge collection mechanism to the webdav server (remove old templates when consumed by cloudstack)	

* use isolated / dedicated networks for bosh vms
	http://www.shapeblue.com/using-the-api-for-advanced-network-management/
	static API assigned through API deployVirtualMachine	

* persist bosh registry.
	now hsqldb
	set persistent file in /var/vcap/store/cpi
	TBC : use bosh postgres db (add postgres jdbc driver + dialect config + bosh *db credentials injection)


* globals
	harden Exception mangement
	map spring boot /error to an intelligible CPI rest payload / stdout
	update json reference files for unit tests

	

* provision ssh keys
	generate keypair with cloudstack API (no support on portail)
	use keypair name + private key in bosh.yml
	see http://cloudstack-administration.readthedocs.org/en/latest/virtual_machines.html?highlight=ssh%20keypair
	see http://chriskleban-internet.blogspot.fr/2012/03/build-cloud-cloudstack-instance.html




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