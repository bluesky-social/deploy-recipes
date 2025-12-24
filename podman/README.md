# Running your Bluesky PDS using Podman Quadlets

The primary goal of this deployment is to use Podman Quadlets, ensuring that
`systemctl` and similar tooling can properly read the state of the service.

## How to deploy

Place `pds.container`, `pds.pod`, and `pds.volume` wherever your server looks
for quadlets. This is probably `/etc/containers/systemd`.

Use `pds.env` and tweak as necessary, being sure to set `PDS_JWT_SECRET`,
`PDS_ADMIN_PASSWORD` to separate values generated from `openssl rand --hex 16`, and
`PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX` to `openssl ecparam --name secp256k1 --genkey --noout --outform DER | tail --bytes=+8 | head --bytes=32 | xxd --plain --cols 32`.

I keep `pds.env` in `/opt/pds/pds.env` to help keep my root directory clean.

Update your reverse proxy (in this example, Caddy) to use the tls-check endpoint
and reverse proxy traffic.

Also included is a slightly patched version of `pdsadmin` that ensures it won't
ever try to update a deployment that doesn't exist.

## Assumptions

I've used a slightly different path `/opt/pds/pds.env` to store the environment
variables, rather than `/pds/pds.env`.

My version of `pdsadmin` also assumes that `pds.env` is readable by your user
even if you're not root.

The volume is mapped into the pod and is reachable from the container that way.
