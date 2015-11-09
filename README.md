[![Build Status](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release.png)](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release)



# bosh-cloudstack-cpi-release

This is work in progress / feedbacks welcome (use issues). Tested on cloudstack 4.3, xen 6.2
The cloudstack cpi is available on [bosh.io](http://bosh.io/releases/github.com/cloudfoundry-community/bosh-cloudstack-cpi-release) 


## Design :
* this CPI is a Bosh external CPI i.e a dedicated bosh release wich must be deployed alongside a bosh release OR configured with bosh release in a bosh-init yml manifest
*  CPI business logic is in a dedicated spring boot app, included in bosh-cloudstack-cpi-release, called cpi-core. This java component has a dedicated template / monit service.
* leverages Apache Jclouds support for CloudStack, nice java adapter for Cloudstack API
* supports Cloudstack advanced zone
* secondary / ephemeral implemented as cloudstack volume (no ephemeral disk concept in CloudStack).
* Uses a webdav http server to enable stemcell / template loading by cloudstack (other option was create volume and transform to template, required bosh / bosh-init to be hosted in the target cloud / tenant). This webdav server is started from the spring boot cpi core jvm


![Alt text](http://g.gravizo.com/g?
  digraph G {
    aize ="4,4";
    bosh_director -> cpi
	cpi -> cpi_core
	cpi_core -> bosh_registry
	cpi_core -> cloudstack
	cpi_core -> template_webdav_server
  }
)

* detailed diagram sequence

![Alt text](http://plantuml.com:80/plantuml/png/ZLJ1Rjim33rFNq5arsGVq203jhGOYdReq6Mx1hB4s6fiIP1a9_txKNAon8hJzcZoaNnyV79XzZ2vlN--MwwUdYVia-KkAA4irm6aSYY2SGorXCBiMH71or_t4_ZygCegVAzR79O8gou2Qs4SCe3pS65yjNPOAX_SQvRROI5vbmrzVFfp-tlrRVcGSHIrQQKFN6o7ySwPDc16_U_FwyoxPlYT6F8ITVZVWoqMu0Cs0kiQ5Wjsr0TcN-EUS0F28G-uFe9OZFR99C8ueayHh5-SGBYtnYCGnjQ47e1E2nEmLn3T6VIKFkzOXM3Xnztg0prtN0NOc5DFciBbQzg-QqW84-XetBwfGDVCHvPtw9CZCjGuZnuJHtBIl_NePf87FgmO-8YADeWo1U4Od6UI78n1s59rcFh2eUyGrn34EjCfhuo6I9MBeBgU4wFqSNmo2O5xSNfjb0PP2Jiblv2dV0BE4d3Epeg6V32Sw4oprRYKf9xFg_FzgOS_Ev7I6pC5PQayLYSbfVBRYpvfMxgbqHjLjgIjnh0pRXlvqvEW5gCLZMdfAtPDJuTqGbjXWuxNQSuykSQYyz6cwPVYjsyQ9m9ovrmaHmnpyekfsmRp0JV00y6gA_spv5LxjLR66McBce9NoVGDnyWCBACvdKkOfY49fmFz4vLtRtqW9C5Z24gNNrwyqHyuL3fLTXR6_W40)

<!-- source of the diag into sequence.txt -->
		


* Out of Scope : security groups provisioning / CS Basic Zones, see issues for current limitations



## Current Status:



### Global status
* micro-bosh creation (with an externally launched cpi-core process)
* compilation vms ok, blobstore ok
* cpi able to manage most director operation on cloudstack advanced deployment
* see issues for limitations

## TODO

* run Director BATS against the cpi
	https://github.com/cloudfoundry/bosh/blob/master/docs/running_tests.md
* check template publication
	from cpi-core webdav, only public template possible ?
	validate publication state (instant OK for registering, need to wait for the ssvm (secondary storage vm) to copy the template
	connectivity issue when cloudstack tries asynchronously to copy template : vlan opened, dedicated chunk encoding compatible spring boot endpoint

	add a garbarge collection mechanism to the webdav server (remove old templates when consumed by cloudstack)	

* use isolated / dedicated networks for bosh vms [avanced-network](http://www.shapeblue.com/using-the-api-for-advanced-network-management)
	/
	static API assigned through API deployVirtualMachine	

* persist bosh registry.
	now hsqldb, persistent file in /var/vcap/store/cpi
	TBC : use bosh postgres db (add postgres jdbc driver + dialect config + bosh *db credentials injection)
* provision ssh keys
** generate keypair with cloudstack API (no support on portail)
** use keypair name + private key in bosh.yml
** see [cloudstack-keypair](http://cloudstack-administration.readthedocs.org/en/latest/virtual_machines.html?highlight=ssh%20keypair)
** see [cloudstack-template](http://chriskleban-internet.blogspot.fr/2012/03/build-cloud-cloudstack-instance.html)


## Typical bosh.yml configuration to activate the CloudStack external CPI

```yml

# add the cpi bosh release
releases:
- {name: bosh, version: "222"}
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
  - {name: cloudstack_cpi, release: bosh-cloudstack-cpi} # <-- add the external CPI


# activate external cpi
properties:
  director:
    cpi_job: cloudstack_cpi

# set external cpi credentials
   cloudstack:
      endpoint: <your_cloudstack api end_point_url> # Ask for your administrator
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
      
	  cpi:
        webdav_host: *bosh_static_ip
        default_disk_offering: "DO1 - Small STD" 
        default_ephemeral_disk_offering: "DO1 - Small STD"
        vm_expunge_delay: 40 # <-- set to 40s. default is 30s after vm delete.  
	
	    registry:
	      endpoint: http://<bosh_ip>:8080
	
	    blobstore:
	        address: *bosh_static_ip
	        port: 25251
	        provider: dav
	        agent: {user: agent, password: agent-password}
	    agent:
	      mbus: "nats://nats:nats-password@<bosh_ip>:4222"
	    ntp: ""
       
      
      
# define disk_pool, refering to cloudstack disk offering      
disk_pools:
- name: disks
  disk_size: 10000
  cloud_properties:
    disk_offering: "DO2 - Medium STD" #<--- Replace with your disk offering name for persistent disk
      
# define vm pool, refering to cloudstack compute offering      
resource_pools:
- name: vms
  stemcell:
    name: bosh-cloudstack-xen-ubuntu-trusty-go_agent-raw
    version: latest
  network: private
  size: 1
  cloud_properties:
    compute_offering: "CO1 - Small STD" #<--- Replace with your compute offering name
    disk: 20000
    ephemeral_disk_offering : "DO2 - Medium STD" #<--- Replace with the disk offering u want for ephemeral disk
      
      
```


## Typical bosh-int configuration to create a micro-bosh with CloudStack external CPI

bosh-init configuration : micro-bosh.yml

* necessary configuration to activate on the TARGET bosh (micro-bosh) ie : CPI used from micro-bosh to create other deployments
* bosh init must use the cpi external release, and have the necessary configuration to create the microbosh vm. 


cpi-core config: application.yml
* exposes a webdav server (used by cloudstack iaas to get the template extracted from the stemcell)
* exposes a registry to the microbosh vm for bootstrapping purpose. cpi-core will generate the correct json setting. Bosh agents will copy it to /var/vcap/bosh/settings.json 
* generates adequate vm userdata when creating the vm, giving registry endpoint

The cpi-core must be launched separately, see the inception directory which provides a sample script and application.yml configuration.


As the bosh-init bootstrapping is quite cumbersome, its recommended to provision a bosh deployment from the microbosh and operate from that full managed bosh (best practice anyway).



```yml


---                                                                                                          
name: micro-bosh                                                                                                   
releases:

- name: bosh
  url: https://bosh.io/d/github.com/cloudfoundry/bosh?v=215
  sha1: f86d4cec1baff641287e069619d7ed4dfa578b13

- name: bosh-cloudstack-cpi-release
  url:  http://localhost:8080/webdav/bosh-cloudstack-cpi-release-5+dev.12.tgz
  sha1: 9f187f69849cf38f72cb389dee96504f57e03f9a

resource_pools:
- name: vms    
  network: private
  stemcell:
    url:  http://localhost:8080/webdav/light-bosh-stemcell-3033-cloudstack-xen-ubuntu-trusty-go_agent.tgz
    sha1: cf6f6925d133d0b579d154694025c027bc64ef88

  cloud_properties:                                                                                              
    compute_offering: "CO2 - Medium STD" # <--- Replace with compute offering name                                                                          
    disk: 20_000                                                                                                 
    ephemeral_disk_offering: custom_size_disk_offering2                                                          

disk_pools:
- name: disks
  disk_size: 10000 
  cloud_properties:
    disk_offering: "DO2n - 10 GiB" # <--- Replace with persistent disk offering name
    #disk_offering: "custom_size_disk_offering2" # <--- Replace with persistent disk offering name

networks:
- name: private
  type: manual 
  subnets:     
  - range: 10.0.0.128/26
    gateway: 10.0.0.129 
    dns: [10.234.50.180,10.234.71.124]
    cloud_properties: {name: "3112 - preprod - back"} # <--- Replace with Network name

jobs:
- name: bosh
  instances: 1

  templates:
  - {name: nats, release: bosh}
  - {name: redis, release: bosh}
  - {name: postgres, release: bosh}
  - {name: blobstore, release: bosh}
  - {name: director, release: bosh} 
  - {name: health_monitor, release: bosh}
  - {name: powerdns, release: bosh}      
  - {name: cloudstack_cpi, release: bosh-cloudstack-cpi-release}

  resource_pool: vms
  persistent_disk_pool: disks

  networks:
  - {name: private, static_ips: [ &micro_bosh_static_ip <micro_bosh_ip>]}
# ip range in cloudstack 150 to 160              

  properties:
    nats:    
      address: 127.0.0.1
      user: nats        
      password: nats-password

    redis:
      listen_addresss: 127.0.0.1
      address: 127.0.0.1        
      password: redis-password  

    postgres: &db
      host: 127.0.0.1
      user: postgres 
      password: postgres-password
      database: bosh             
      adapter: postgres          

    blobstore:
      address: *micro_bosh_static_ip
      port: 25250            
      provider: dav          
      director: {user: director, password: director-password}
      agent: {user: agent, password: agent-password}         

    director:
      address: 127.0.0.1
      name: micro-bosh     
      db: *db           
      cpi_job: cloudstack_cpi      
      #max_threads: 4    
      enable_snapshots: false 

    hm:
      http: {user: hm, password: hm-password}
      director_account: {user: admin, password: admin}
      resurrector_enabled: true                       
                                                      
    dns:                                              
      address: *micro_bosh_static_ip                           
      #the bosh powerDNS will contact the following DNS server for serving DNS entries from other domains                                                                                                                         
      # i.e. elpaaso-dns.internal-qa.paas                                                                                                                                                                                         
      recursor: 10.234.50.180
      db: *db

    cloudstack:  &cloudstack # <--- Replace values below
      endpoint: http://10.x.x.x:8080/client/api
      api_key: <cloudstack api key>
      secret_access_key: <cloudstack acces key>
    
      default_key_name: xx
      private_key: zz
      state_timeout: 600
      state_timeout_volume: 600
      stemcell_public_visibility: true
      default_zone: <cloudstack zone>
      proxy_host: ""                                                                                             
      proxy_port: 8080                                                                                           
      proxy_user: xx                                                                                         
      proxy_password: ""   
      
    cpi:
      default_disk_offering: "DO2n - 10 GiB" 
      default_ephemeral_disk_offering: "DO1 - Small STD"  
    
      webdav_host: *micro_bosh_static_ip
      webdav_port: 8080
      webdav_directory: "/var/vcap/store/cloudstack_cpi/webdav"
      registry:
        endpoint: http://<micro_bosh_ip>:8080
        user: admin
        password: admin
      blobstore:
        address: *micro_bosh_static_ip
        port: 25250
        provider: dav
        agent: {user: agent, password: agent-password}
      agent: 
        mbus: "nats://nats:nats-password@<micro_bosh_ip>:4222"     
      ntp: ""

    agent: {mbus: "nats://nats:nats-password@<micro_bosh_ip>:4222"}

    ntp: &ntp [10.234.50.245 ,10.234.50.246]

cloud_provider:
  template: {name: cloudstack_cpi, release: bosh-cloudstack-cpi-release}

  mbus: "https://mbus:mbus-password@<micro_bosh_ip>:6868"

  properties:
    cloudstack: *cloudstack
    cpi:
      webdav_host: <inception_vm_ip>
      webdav_port: 8080
  
      default_disk_offering: "DOXn"  # <-- default offering must be shared. custom size

      default_ephemeral_disk_offering: "DO1 - Small STD"  

      registry:
        endpoint: http://<inception_vm_ip>:8080
        user: admin
        password: admin
      agent:
        mbus: "https://mbus:mbus-password@0.0.0.0:6868" 
      ntp: ""

    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: *ntp


```





## Contributing

In the spirit of [free software](http://www.fsf.org/licensing/essays/free-sw.html), **everyone** is encouraged to help
improve this project.

Here are some ways *you* can contribute:

* by using alpha, beta, and prerelease versions
* by reporting bugs
* by suggesting new features
* by writing or editing documentation
* by writing specifications
* by writing code (**no patch is too small**: fix typos, add comments, clean up inconsistent whitespace)
* by refactoring code
* by closing [issues](https://github.com/cloudfoundry-community/bosh-cloudstack-cpi-release/issues)
* by reviewing patches


### Submitting an Issue

We use the [GitHub issue tracker](https://github.com/cloudfoundry-community/bosh-cloudstack-cpi-release/issues) to track bugs and
features. Before submitting a bug report or feature request, check to make sure it hasn't already been submitted. You
can indicate support for an existing issue by voting it up. When submitting a bug report, please include a
[Gist](http://gist.github.com/) that includes a stack trace and any details that may be necessary to reproduce the bug,
including your gem version, Ruby version, and operating system. Ideally, a bug report should include a pull request
with failing specs.

### Submitting a Pull Request

1. Fork the project.
2. Create a topic branch.
3. Implement your feature or bug fix.
4. Commit and push your changes.
5. Submit a pull request.
