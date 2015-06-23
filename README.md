[![Build Status](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release.png)](https://travis-ci.org/cloudfoundry-community/bosh-cloudstack-cpi-release)



# bosh-cloudstack-cpi-release

bosh external cloustack cpi implementation (spring boot, included in bosh-cloudstack-cpi-release)
leverages apache jclouds support for CloudStack


properties:

   cloudstack:
      endpoint: <your_end_point_url> # Ask for your administrator
      api_key: <your_api_key> # You can find at your user page
      secret_access_key: <your_secret_access_key> # Same as above
      default_key_name: <default_keypair_name> # Your keypair name (see the next section)
      private_key: <path_to_your_private_key> # The path to the private key file of your key pair
      state_timeout: 600
      state_timeout_volume: 1200
      stemcell_public_visibility: true
      default_zone: <default_zone_name> # Zone name of your instaption server
