#!/bin/sh
echo "Starting DNS update script..."

# Configs
config_map_name=${HETZNER_DNS_CONFIGMAP_STATE:-hetzner-dns-state}
api_server_addr="${HETZNER_DNS_KUBERNETES_API_SERVER:-kubernetes.default.svc}"
dns_zone=${HETZNER_DNS_ZONE:-example.com}
dns_names=${HETZNER_DNS_NAMES:-home}
dns_record_type=${HETZNER_DNS_RECORD_TYPE:-a}
dns_ttl=${HETZNER_DNS_TTL:-300}
hcloud_token=${HETZNER_DNS_HCLOUD_TOKEN}

if [ -z "$hcloud_token" ]; then
  echo "HETZNER_DNS_HCLOUD_TOKEN is not set. Exiting."
  exit 1
fi

# Kubernetes auth
ns_path=/var/run/secrets/kubernetes.io/serviceaccount/namespace
ns=$(cat $ns_path)
ca_crt_path=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
sa_token_path=/var/run/secrets/kubernetes.io/serviceaccount/token
sa_token=$(cat $sa_token_path)

config_map_api_url="https://${api_server_addr}/api/v1/namespaces/${ns}/configmaps/${config_map_name}"

# Kubernetes Auth
if [ -z "$sa_token" ]; then
  echo "Service account token empty. Check Service Account mounting"
  exit 1
fi

echo "Testing access to kubernetes API..."

res=$(curl \
  --cacert "$ca_crt_path" \
  -o - \
  --fail-with-body \
  -H "Authorization: Bearer ${sa_token}" \
  "${config_map_api_url}" 2>&1)
if [ $? -ne 0 ]; then
  echo "Failed to access Kubernetes API: $res"
  exit 1
fi

# Check the IP
old_ip=$STATE_LAST_IP
new_ip=$(curl \
  --silent \
  -o - \
  --fail-with-body \
  https://ipecho.net/plain 2>&1)

if [ $? -ne 0 ]; then
  echo "Failed to retrieve current public IP: $new_ip"
  exit 1
fi

if [ "$old_ip" = "$new_ip" ]; then
  echo "IP address has not changed from $old_ip. No update needed. Exiting"
  exit 0
fi

echo "Updating DNS record to new IP: $new_ip (from $old_ip)"

for dns_name in $(echo $dns_names | tr ',' ' '); do
  body=$(cat <<EOF
{
  "records": [{
    "value": "$new_ip",
    "comment": "Updated via script"
  }]
}
EOF
)
  res=$(curl \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${hcloud_token}" \
    --data "${body}" \
    -o - \
    --fail-with-body \
    "https://api.hetzner.cloud/v1/zones/${dns_zone}/rrsets/${dns_name}/${dns_record_type}/actions/set_records" 2>&1)
  #HCLOUD_TOKEN=$hcloud_token hcloud zone set-records "$dns_zone" "$dns_name" "$dns_record_type" --record "$new_ip"

  if [ $? -ne 0 ]; then
    echo "Failed to update DNS record. Response: $res"
    exit 1
  fi

  echo "DNS record for ${dns_name}.${dns_zone} updated to $new_ip."
done

echo "DNS record updated successfully."

# Update the DNS state ConfigMap
config_map_patch=$(cat <<EOF
{
  "data": {
    "LAST_IP": "$new_ip"
  }
}
EOF
)
echo "Updating state ConfigMap with new IP..."
res=$(curl \
  --cacert "$ca_crt_path" \
  --silent \
  -X PATCH \
  -H "Content-Type: application/merge-patch+json" \
  -H "Authorization: Bearer ${sa_token}" \
  --data "$config_map_patch" \
  "${config_map_api_url}" 2>&1)

if [ $? -ne 0 ]; then
  echo "Failed to update state ConfigMap: $res"
  exit 1
fi

echo "State ConfigMap updated successfully."
