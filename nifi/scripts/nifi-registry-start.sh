#!/bin/sh -e
scripts_dir='/opt/nifi-registry/scripts'

[ -f "${scripts_dir}/common.sh" ] && . "${scripts_dir}/common.sh"

# Establish baseline properties
prop_replace 'nifi.registry.web.http.port'      "${NIFI_REGISTRY_WEB_HTTP_PORT:-18080}"
prop_replace 'nifi.registry.web.http.host'      "${NIFI_REGISTRY_WEB_HTTP_HOST:-$HOSTNAME}"

. ${scripts_dir}/update_database.sh

# Check if we are secured or unsecured
case ${AUTH} in
    tls)
        echo 'Enabling Two-Way SSL user authentication'
        . "${scripts_dir}/secure.sh"
        ;;
    ldap)
        echo 'Enabling LDAP user authentication'
        # Reference ldap-provider in properties
        prop_replace 'nifi.registry.security.identity.provider' 'ldap-identity-provider'
        prop_replace 'nifi.registry.security.needClientAuth' 'false'

        . "${scripts_dir}/secure.sh"
        . "${scripts_dir}/update_login_providers.sh"
        ;;
    oidc)
        echo 'Enabling OIDC user authentication'
        prop_replace 'nifi.registry.security.user.oidc.discovery.url'  "${OIDC_DISCOVERY_URL}"
        prop_replace 'nifi.registry.security.user.oidc.client.id'      "${OIDC_CLIENT_ID}"
        prop_replace 'nifi.registry.security.user.oidc.client.secret'  "${OIDC_CLIENT_SECRET}"
        prop_replace 'nifi.registry.security.needClientAuth'           'false'

        . "${scripts_dir}/secure.sh"
        ;;
esac

. "${scripts_dir}/update_flow_provider.sh"
. "${scripts_dir}/update_bundle_provider.sh"

# Continuously provide logs so that 'docker logs' can produce them
tail -F "${NIFI_REGISTRY_HOME}/logs/nifi-registry-app.log" &
"${NIFI_REGISTRY_HOME}/bin/nifi-registry.sh" run &
nifi_registry_pid="$!"

trap "echo Received trapped signal, beginning shutdown...;" KILL TERM HUP INT EXIT;

echo NiFi-Registry running with PID ${nifi_registry_pid}.
wait ${nifi_registry_pid}
