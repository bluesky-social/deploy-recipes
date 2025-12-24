# Basic Docker deployment

The ATProto PDS is very simple to deploy on any Docker host. All you need to do is create an env file and then connect a reverse proxy. This document covers how to set up the Docker container, so you can use it with an existing reverse proxy setup.

## Prerequisites

1. A host with Docker (or compatible alternative)
2. Basic knowledge of how to access your server, manage files, and use docker
3. An existing reverse proxy that you know how to configure 
4. A domain name and knowledge of setting up DNS records

# Step 1: Create env file

First and foremost, make a working directory for the PDS files, such as `/srv/pds`.

Create a file named `pds.env` and fill it with this template.

```
PDS_HOSTNAME=
PDS_SERVICE_HANDLE_DOMAINS=
PDS_JWT_SECRET=
PDS_ADMIN_PASSWORD=
PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=
PDS_DATA_DIRECTORY=/data
PDS_BLOBSTORE_DISK_LOCATION=/data/blobs
PDS_BLOB_UPLOAD_LIMIT=104857600
PDS_DID_PLC_URL=https://plc.directory
PDS_BSKY_APP_VIEW_URL=https://api.bsky.app
PDS_BSKY_APP_VIEW_DID=did:web:api.bsky.app
PDS_REPORT_SERVICE_URL=https://mod.bsky.app
PDS_REPORT_SERVICE_DID=did:plc:ar7c4by46qjdydhdevvrndac
PDS_CRAWLERS=https://bsky.network
LOG_ENABLED=true
PDS_PORT=3000
NODE_ENV=production
```

Generate a private key with this command and paste it after `PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=`:

```
openssl ecparam --name secp256k1 --genkey --noout --outform DER | tail --bytes=+8 | head --bytes=32 | xxd --plain --cols 32
```

Run this command twice to generate values for `PDS_JWT_SECRET=` and `PDS_ADMIN_PASSWORD=`:

```
openssl rand --hex 16
```

`PDS_HOSTNAME`: Set this to the FQDN that your PDS will be hosted at, for example, `pds.example.com`.

`PDS_SERVICE_HANDLE_DOMAINS`: Comma-separated list of domains used for handles. Each one must start with a period. For example, if this is set to `.example.com`, then new accounts on the PDS will be created with handles like `alice.example.com`, `bob.example.com`, etc. 

- If this environment variable is excluded, then usernames will be prefixed to the value of `PDS_HOSTNAME`, so with these examples the handles would be `alice.pds.example.com` and `bob.pds.example.com`.
- If you're using Cloudflare on the free plan, TLS does not work on hostnames with more than four levels, so configuring this may be necessary.
- Although you can set multiple handle domains here, the Bluesky frontend does NOT support selection of handle domain when creating a new account.
- The service handle domains do not need to be related to the PDS hostname, they can be completely different domains.

To see all of the environment variables that you can configure, refer to this file: https://github.com/bluesky-social/atproto/blob/main/packages/pds/src/config/env.ts

## Step 2: Launch Docker container

Once the env file is ready the Docker container can be launched with this command:

```sh
docker run -d \
	--name pds \
	--restart unless-stopped \
	-v "./data:/data" \
	--env-file pds.env \
	-p 3000:3000 \
	--label com.centurylinklabs.watchtower.enable="true" \
	ghcr.io/bluesky-social/pds:latest
```

When making changes to the env file, you will have to remove the container (`docker stop pds; docker rm pds`) and run the above command again. You could use shell scripts or aliases for your convenience.

To keep your PDS automatically updated, run a [watchtower](https://containrrr.dev/watchtower/) container as well:

```sh
docker run -d \
	--name watchtower \
	--restart unless-stopped \
	-v /var/run/docker.sock:/var/run/docker.sock \
	containrrr/watchtower --label-enable
```

Instead of running docker commands you can use docker compose:

```yaml
services:
  pds:
    container_name: pds
    image: ghcr.io/bluesky-social/pds:latest
    restart: unless-stopped
    volumes:
      - "./data:data"
    env_file:
      - "./pds.env"
    ports:
      - "3000:3000"
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
  watchtower:
    container_name: watchtower
    image: containrrr/watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --label-enable
```

## Step 3: Configure reverse proxy

The FQDN specified in `PDS_HOSTNAME` must be forwarded from HTTPS to the PDS. Wildcards for service handle domains should also be forwarded, however they are only used for automatically serving `/.well-known/atproto-did` urls for handle verification, so it's possible to do this manually for each account instead.

Do not try to overlay the PDS paths on an existing website. The PDS uses several other undocumented paths which could change in the future and things may break if they are not forwarded.

The reverse proxy must support WebSockets.

### Caddy example

The PDS docker image is designed to work with Caddy's [On-demand TLS](https://caddyserver.com/on-demand-tls) feature. This automatically generates new TLS certificates via HTTP challenge when new hostnames are connected to AND the backend authorizes it. Here is an example configuration:

```caddy
{
	on_demand_tls {
		ask http://localhost:3000/tls-check
	}
}

*.example.com {
	tls {
		on_demand
	}
	reverse_proxy http://localhost:3000
}
```

Note: On-demand TLS might cause issues with other sites. Since Caddy v2.10.0, there is a bug where sites overlapping the on-demand wildcard won't get certs unless you add `tls force_automate` to that site.

A wildcard certificate is more reliable, but requires installing a Caddy module for the DNS provider you are using, such as [Cloudflare](https://github.com/caddy-dns/cloudflare), [Porkbun](https://github.com/caddy-dns/porkbun), [etcetera](https://github.com/orgs/caddy-dns/repositories?type=all).

With DNS plugin, the configuration would be as simple as this:

```caddy
*.example.com {
	tls {
		dns cloudflare <your_api_token>
	}
	reverse_proxy http://localhost:3000
}
```


### Nginx example

You can use ACME client like [Certbot](https://certbot.eff.org) to get wildcard certificates with DNS plugin.

```nginx
http {
	map $http_upgrade $connection_upgrade {
		default upgrade;
		''      close;
	}
	server {
		server_name *.example.com
		listen 443 ssl;
		ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
		ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
		location / {
			proxy_http_version 1.1;
			proxy_set_header Upgrade $http_upgrade;
			proxy_set_header Connection $connection_upgrade;
			proxy_set_header Host $host;
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_pass http://localhost:3000;
		}
	}
}
```

Don't forget to add a deploy hook for Certbot to reload Nginx after certificate renewals. For example, create `/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh`:

```sh
#!/bin/sh
/usr/sbin/nginx -s reload
```

And `chmod a+x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh`.


### Cloudflare direct

It's possible to connect Cloudflare directly to the PDS without a redundant reverse proxy. This is by far the easiest setup. Cloudflare provides TLS and supports wildcards, but only at the third level (i.e. you can do `*.example.com` but you can NOT do `*.pds.example.com`).

Just expose your PDS post (i.e. 3000) to the internet and tell Cloudflare to connect your site to that port using page rules.

On your domain's Cloudflare page go to the Rules tab -> Overview and click Create rule -> **Origin rule**. Use a filter expression to match the hostnames you want to use for the PDS without affecting other sites, i.e. `(http.host wildcard "*.example.com")` or `(ends_with(http.host, ".example.com"))`. Then, set Destination Port to Rewrite to your PDS port i.e. 3000.

In addition, create a **Configuration rule** with the same filter expression, and set the SSL Mode to **Flexible**. This makes Cloudflare connect with HTTP without affecting other stuff on the domain.

### Cloudflare Tunnel

You can use the [cloudflared](https://github.com/cloudflare/cloudflared) to connect the PDS to cloudflare WITHOUT port forwarding and opening firewalls. This is especially useful when hosting at home with a dynamic IP address or CGNAT. The daemon can be connected to the PDS with this configuration:

```yaml
ingress:
  - hostname: "*.example.com"
    service: http://127.0.0.1:8000
```



# Step 4: Create first account with pdsadmin.sh

The pdsadmin.sh accesses your PDS on the public URL, so make sure your reverse proxy is working and test the connection like this:

```
curl https://pds.example.com/xrpc/_health
```

It should show the PDS version. NOTE: If you are hosting at home and have to port-forward to your server, your router needs to support hairpin NAT or you will not be able to connect to your own server from your local network.

Download the pdsadmin.sh script to your PDS folder:

```
wget https://raw.githubusercontent.com/bluesky-social/pds/refs/heads/main/pdsadmin.sh
```

Tell pdsadmin.sh where the env file is. (You can put this inside the script to make it easier.)

```
export PDS_ENV_FILE=./pds.env
```

Create your first account:

```
./pdsadmin.sh account create
```

Then you can sign in to Bluesky with this account and start using it.