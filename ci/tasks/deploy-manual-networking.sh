#!/usr/bin/env bash

set -e

source bosh-cpi-release/ci/tasks/utils.sh

ensure_not_replace_value base_os
ensure_not_replace_value network_type_to_test
ensure_not_replace_value cloudstack_flavor
ensure_not_replace_value cloudstack_connection_timeout
ensure_not_replace_value cloudstack_read_timeout
ensure_not_replace_value cloudstack_write_timeout
ensure_not_replace_value cloudstack_state_timeout
ensure_not_replace_value private_key_data
ensure_not_replace_value bosh_registry_port
ensure_not_replace_value cloudstack_net_id
ensure_not_replace_value cloudstack_security_group
ensure_not_replace_value cloudstack_default_key_name
ensure_not_replace_value cloudstack_auth_url
ensure_not_replace_value cloudstack_username
ensure_not_replace_value cloudstack_api_key
ensure_not_replace_value cloudstack_tenant
ensure_not_replace_value cloudstack_floating_ip
ensure_not_replace_value cloudstack_manual_ip
ensure_not_replace_value cloudstack_net_cidr
ensure_not_replace_value cloudstack_net_gateway

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

export BOSH_INIT_LOG_LEVEL=DEBUG

semver=`cat version-semver/number`
cpi_release_name="bosh-cloudstack-cpi"
working_dir=$PWD

mkdir -p $working_dir/keys
echo "$private_key_data" > $working_dir/keys/bats.pem

manifest_dir="${working_dir}/director-state-file"
manifest_filename=${base_os}-${network_type_to_test}-director-manifest.yml

eval $(ssh-agent)
chmod go-r $working_dir/keys/bats.pem
ssh-add $working_dir/keys/bats.pem

cat > "${manifest_dir}/${manifest_filename}" <<EOF
---
name: bosh

releases:
  - name: bosh
    url: file://${working_dir}/bosh-release/release.tgz
  - name: ${cpi_release_name}
    url: file://${working_dir}/bosh-cpi-dev-artifacts/${cpi_release_name}-${semver}.tgz

networks:
- name: private
  type: manual
  subnets:
   - range:   ${cloudstack_net_cidr}
     gateway: ${cloudstack_net_gateway}
     dns:     [8.8.8.8]
     static:  [${cloudstack_manual_ip}]
     cloud_properties:
       net_id: ${cloudstack_net_id}
       security_groups: [${cloudstack_security_group}]
- name: public
  type: vip

resource_pools:
- name: default
  network: private
  stemcell:
    url: file://${working_dir}/stemcell/stemcell.tgz
  cloud_properties:
    instance_type: $cloudstack_flavor

disk_pools:
- name: default
  disk_size: 25_000

jobs:
- name: bosh
  templates:
  - {name: nats, release: bosh}
  - {name: redis, release: bosh}
  - {name: postgres, release: bosh}
  - {name: blobstore, release: bosh}
  - {name: director, release: bosh}
  - {name: health_monitor, release: bosh}
  - {name: registry, release: bosh}
  - {name: cpi, release: ${cpi_release_name}}

  instances: 1
  resource_pool: default
  persistent_disk_pool: default

  networks:
  - name: private
    static_ips: [${cloudstack_manual_ip}]
    default: [dns, gateway]
  - name: public
    static_ips: [${cloudstack_floating_ip}]

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

    # Tells the Director/agents how to contact registry
    registry:
      address: ${cloudstack_floating_ip}
      host: ${cloudstack_floating_ip}
      db: *db
      http: {user: admin, password: admin, port: ${bosh_registry_port}}
      username: admin
      password: admin
      port: ${bosh_registry_port}
      endpoint: http://admin:admin@${cloudstack_floating_ip}:${bosh_registry_port}

    # Tells the Director/agents how to contact blobstore
    blobstore:
      address: ${cloudstack_floating_ip}
      port: 25250
      provider: dav
      director: {user: director, password: director-password}
      agent: {user: agent, password: agent-password}

    director:
      address: 127.0.0.1
      name: micro
      db: *db
      cpi_job: cpi

    hm:
      http: {user: hm, password: hm-password}
      director_account: {user: admin, password: admin}

    cloudstack: &cloudstack
      auth_url: ${cloudstack_auth_url}
      username: ${cloudstack_username}
      api_key: ${cloudstack_api_key}
      tenant: ${cloudstack_tenant}
      region: #leave this blank
      endpoint_type: publicURL
      default_key_name: ${cloudstack_default_key_name}
      default_security_groups:
      - ${cloudstack_security_group}
      state_timeout: ${cloudstack_state_timeout}
      wait_resource_poll_interval: 5
      connection_options:
        connect_timeout: ${cloudstack_connection_timeout}
        read_timeout: ${cloudstack_read_timeout}
        write_timeout: ${cloudstack_write_timeout}

    # Tells agents how to contact nats
    agent: {mbus: "nats://nats:nats-password@${cloudstack_floating_ip}:4222"}

    ntp: &ntp
    - 0.north-america.pool.ntp.org
    - 1.north-america.pool.ntp.org

cloud_provider:
  template: {name: cpi, release: ${cpi_release_name}}

  # Tells bosh-micro how to SSH into deployed VM
  ssh_tunnel:
    host: ${cloudstack_floating_ip}
    port: 22
    user: vcap
    private_key: $working_dir/keys/bats.pem

  # Tells bosh-micro how to contact remote agent
  mbus: https://mbus-user:mbus-password@${cloudstack_floating_ip}:6868

  properties:
    cloudstack: *cloudstack

    # Tells CPI how agent should listen for requests
    agent: {mbus: "https://mbus-user:mbus-password@0.0.0.0:6868"}

    blobstore:
      provider: local
      path: /var/vcap/micro_bosh/data/cache

    ntp: *ntp
EOF

initver=$(cat bosh-init/version)
bosh_init="${working_dir}/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $bosh_init

echo "deleting existing BOSH Director VM..."
$bosh_init delete ${manifest_dir}/${manifest_filename}

echo "deploying BOSH..."
$bosh_init deploy ${manifest_dir}/${manifest_filename}

