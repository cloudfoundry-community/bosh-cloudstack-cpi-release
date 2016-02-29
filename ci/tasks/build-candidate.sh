#!/usr/bin/env bash

set -e
set -x

source /etc/profile.d/chruby-with-ruby-2.1.2.sh

semver=`cat version-semver/number`

mkdir -p ../bosh-release/


cd bosh-cpi-release


# unit tests should be launched on submodule src/bosh-cloudstack-cpi-core, as maven tests
#echo "running unit tests"
#pushd src/bosh_cloudstack_cpi
#  bundle install
#  bundle exec rspec spec/unit/*
#popd

echo "installing the latest bosh_cli"
gem install bosh_cli -v 1.3184.1.0 --no-ri --no-rdoc

echo "using bosh CLI version..."
bosh version

cpi_release_name="bosh-cloudstack-cpi"

echo "building CPI release..."
bosh create release --name $cpi_release_name --version $semver --with-tarball



mv dev_releases/$cpi_release_name/$cpi_release_name-$semver.tgz ../bosh-release/
