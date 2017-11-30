#!/bin/bash -eu

preflight_check() {
  set +x
  test -n "${BOSH_DIRECTOR}"
  test -n "${BOSH_PUBLIC_IP}"
  test -n "${BOSH_CLIENT}"
  test -n "${BOSH_CLIENT_SECRET}"
  test -n "${BOSH_CA_CERT}"
  test -n "${CF_DEPLOYMENT}"
  test -n "${API_PASSWORD}"
  set -x
}

function main(){
  local root="${1}"
  preflight_check

  export BOSH_ENVIRONMENT="https://${BOSH_DIRECTOR}:25555"

  bosh interpolate "${root}/cf-deployment/cf-deployment.yml" \
    --vars-store "${root}/variables_output.yml" \
    -o "${root}/cf-deployment/operations/rename-deployment.yml" \
    -v deployment_name="${CF_DEPLOYMENT}" \
    -v system_domain="apps.${CF_DEPLOYMENT}.microbosh" \
    -v cf_admin_password="${API_PASSWORD}"
    -o "${root}/cf-deployment/operations/use-postgres.yml" \
    -o "${root}/cf-deployment/operations/scale-to-one-az.yml" \
    -o "${root}/cf-deployment/operations/use-latest-stemcell.yml" \
    -o "${root}/postgres-release/ci/templates/use-latest-postgres-release.yml" \
    > "${root}/pgci_cf.yml"

  bosh --non-interactive --deployment="${CF_DEPLOYMENT}" deploy "${root}/pgci_cf.yml"
}

main "${PWD}"
