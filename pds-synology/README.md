# Installing Bluesky PDS on Synology NAS: A Complete Guide


The standard `installer.sh` script really doesn't like Synology DSM.

So here is how I got it working.

## Why the Standard installer.sh Doesn't Work

The official PDS installer expects a "normal" Linux environment. Synology DSM is not that.

Here are a few things I ran into:

1. **Synology paths are different**: Everything lives under `/volume1/` or `/volume2/`.
2. **Docker behaves differently**: DSM wraps Docker in its own UI and handles permissions its own way.
3. **Ports 80 and 443 are already used**: DSM uses them for its web interface.
4. **No systemd**: The installer expects it and gets confused.
5. **Permissions can be tricky**: It is easy to hit "permission denied" errors until the paths and ownership are set up properly.

This guide avoids those problems by doing a manual setup that plays nicely with DSM.

## Prerequisites

Before jumping in, make sure you have:

- A Synology NAS running DSM 7 or later
- Administrator access to your NAS
- Administrator access to your router
- A way to get a hostname (either a domain you own, or use Synology's free DDNS service)
- Basic SSH skills (being able to copy and paste commands is enough)

**Note**: If your ISP gives you a dynamic IP (most do), Synology's built-in DDNS feature is perfect for this. You do not need to buy a domain name.

## Part 1: DSM Configuration

### Step 1: Enable SSH Access

1. Log into DSM.
2. Open **Control Panel → Terminal & SNMP**.
3. Enable **SSH service**.
4. Note the port (default is 22).
5. Click **Apply**.

You will use this to run the commands in the rest of the guide.

### Step 2: Install Docker

1. Open **Package Center** in DSM.
2. Search for **Docker**.
3. Install it.
4. Open Docker once to confirm it is working.

### Step 3: Create Required Directories

SSH into your NAS:

```bash
ssh your-username@your-nas-ip
```

Then create the folder structure:

```bash
sudo mkdir -p /volume1/docker/bluesky-pds
sudo mkdir -p /volume1/docker/bluesky-pds/pds-data
sudo mkdir -p /volume1/docker/bluesky-pds/caddy/data
sudo mkdir -p /volume1/docker/bluesky-pds/caddy/etc/caddy
```

Give yourself permission to work in there (replace `your-username` with your real DSM username):

```bash
sudo chown -R your-username:users /volume1/docker/bluesky-pds
```

### Step 4: Generate Caddy Instance UUID

Caddy needs a UUID. Generate it like this:

```bash
cd /volume1/docker/bluesky-pds
uuidgen > caddy/data/caddy/instance.uuid
```

If `uuidgen` is missing, use Python:

```bash
python3 -c "import uuid; print(uuid.uuid4())" > caddy/data/caddy/instance.uuid
```

## Part 2: Router Configuration

DSM uses ports 80 and 443 for its own web interface, so the idea is:

- Expose ports 80 and 443 on the internet.
- Forward them to ports 8080 and 8443 on your NAS.

### Step 1: Find Your NAS IP

In DSM, go to **Control Panel → Network → Network Interface** and note your NAS IP address, for example `192.168.1.100`.

### Step 2: Port Forwarding on Your Router

In your router web interface, create two port forwarding rules that point to your NAS IP.

**Rule 1:**

- Service name: PDS HTTP
- External port: 80
- Internal IP: your NAS IP (for example `192.168.1.100`)
- Internal port: 8080
- Protocol: TCP

**Rule 2:**

- Service name: PDS HTTPS
- External port: 443
- Internal IP: your NAS IP
- Internal port: 8443
- Protocol: TCP

**Fritz!Box users:**

- Go to **Internet → Port Sharing → Port Forwarding**.
- Add two entries, one for HTTP (80 to 8080) and one for HTTPS (443 to 8443).
- Make sure IPv4 is enabled.

### Step 3: DNS Setup

Most home internet connections have a dynamic IP address that changes periodically. If that is your situation (and it probably is), Synology's built-in Dynamic DNS (DDNS) feature is perfect for this.

#### Option A: Dynamic DNS (Recommended for Most Users)

If your ISP gives you a dynamic IP, use Synology's DDNS service:

1. In DSM, go to **Control Panel → External Access → DDNS**.
2. Click **Add**.
3. Select **Synology** as the service provider (or choose another provider if you prefer).
4. Enter a hostname like `YOUR_ACCOUNT.synology.me` (or whatever you want).
5. Click **Test Connection** to verify it works.
6. Click **OK** to save.

Synology will automatically update the DNS record whenever your public IP changes. The hostname you create here (e.g., `YOUR_ACCOUNT.synology.me`) will be your PDS hostname.

**Note**: If you use Synology's DDNS, you get a hostname like `yourname.synology.me`. This works perfectly for your PDS. You can also use other DDNS providers (DuckDNS, No-IP, etc.) if you prefer.

#### Option B: Static IP with Manual DNS

If you have a static IP address (or a domain you manage yourself):

1. Find your public IP using a site like `https://whatismyipaddress.com/`.
2. Create an A record in your DNS provider:
   - Type: A
   - Name: `your_synology_account` (or your chosen subdomain)
   - Value: your public IP address
   - TTL: 300 (or any reasonable value)

If you want multiple user handles later, add a wildcard:

- Type: A
- Name: `*`
- Value: your public IP address
- TTL: 300

## Part 3: PDS Configuration Files

### Step 1: docker-compose.yml

Create the file `/volume1/docker/bluesky-pds/docker-compose.yml` and put this in it:

```yaml
services:
  caddy:
    container_name: caddy
    image: caddy:2
    depends_on:
      - pds
    restart: unless-stopped
    volumes:
      - type: bind
        source: /volume1/docker/bluesky-pds/caddy/data
        target: /data
      - type: bind
        source: /volume1/docker/bluesky-pds/caddy/etc/caddy
        target: /etc/caddy
    ports:
      - "8080:80"
      - "8443:443"

  pds:
    container_name: pds
    image: ghcr.io/bluesky-social/pds:latest
    restart: unless-stopped
    volumes:
      - type: bind
        source: /volume1/docker/bluesky-pds
        target: /pds
      - type: bind
        source: /volume1/docker/bluesky-pds/pds-data
        target: /pds-data
    env_file:
      - /volume1/docker/bluesky-pds/pds.env

  pdsdash:
    container_name: pdsdash
    image: nginx:alpine
    restart: unless-stopped
    volumes:
      - type: bind
        source: /volume1/docker/bluesky-pds/pds-dash/dist
        target: /usr/share/nginx/html

  watchtower:
    container_name: watchtower
    image: ghcr.io/nicholas-fedor/watchtower:latest
    volumes:
      - type: bind
        source: /var/run/docker.sock
        target: /var/run/docker.sock
    restart: unless-stopped
    environment:
      WATCHTOWER_CLEANUP: true
      WATCHTOWER_SCHEDULE: "@midnight"
```

### Step 2: pds.env

Create `/volume1/docker/bluesky-pds/pds.env` with your configuration:

```bash
PDS_HOSTNAME=YOUR_ACCOUNT.synology.me
PDS_ADMIN_EMAIL=your-email@example.com
PDS_ADMIN_PASSWORD=YourSecurePassword123!
PDS_JWT_SECRET=your-64-character-hex-secret-here
PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=your-64-character-hex-key-here
PDS_EMAIL_SMTP_URL=smtp://user:password@smtp.example.com:587
PDS_EMAIL_FROM_ADDRESS=no-reply@yourdomain.com
PDS_DATA_DIRECTORY=/pds-data
PDS_BLOBSTORE_DISK_LOCATION=/pds-data/blobs
PDS_BLOBSTORE_DISK_TMP=/pds-data/tmp
PDS_SQLITE_LOCATION=/pds-data/pds.sqlite
PDS_BLOB_UPLOAD_LIMIT=104857600
PDS_ENABLE_ACCOUNT_REGISTRATION=true
PDS_DID_PLC_URL=https://plc.directory
PDS_BSKY_APP_VIEW_URL=https://api.bsky.app
PDS_BSKY_APP_VIEW_DID=did:web:api.bsky.app
PDS_REPORT_SERVICE_URL=https://mod.bsky.app
PDS_REPORT_SERVICE_DID=did:plc:ar7c4by46qjdydhdevvrndac
PDS_CRAWLERS=https://bsky.network
LOG_LEVEL=info
LOG_ENABLED=true
```

Replace these values:

- `PDS_HOSTNAME`: your domain name (if using Synology DDNS, this will be something like `YOUR_ACCOUNT.synology.me`)
- `PDS_ADMIN_EMAIL`: your email address
- `PDS_ADMIN_PASSWORD`: a strong password
- `PDS_JWT_SECRET`: a 64 character hex string generated with `openssl rand -hex 32`
- `PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX`: another 64 character hex string
- `PDS_EMAIL_SMTP_URL` and `PDS_EMAIL_FROM_ADDRESS`: your SMTP details if you want email support

### Step 3: Caddyfile

Create `/volume1/docker/bluesky-pds/caddy/etc/caddy/Caddyfile`:

```caddy
{
	email your-email@example.com
	on_demand_tls {
		ask http://pds:3000/tls-check
	}
}

YOUR_ACCOUNT.synology.me, *.YOUR_ACCOUNT.synology.me {
	tls {
		on_demand
	}

	encode gzip zstd
	reverse_proxy http://pds:3000
}

enter.YOUR_ACCOUNT.synology.me {
	tls your-email@example.com
	encode gzip zstd
	reverse_proxy http://pdsdash:80
}
```

Replace `YOUR_ACCOUNT.synology.me` with your domain (or your Synology DDNS hostname if you went that route) and `your-email@example.com` with your email address.

## Part 4: Deployment

### Step 1: Start the Services

From your SSH session on the NAS:

```bash
cd /volume1/docker/bluesky-pds
sudo docker compose pull
sudo docker compose up -d
```

### Step 2: Check Services

```bash
sudo docker compose ps
```

You should see all containers with status `Up`.

### Step 3: Watch Logs

Check the PDS logs:

```bash
sudo docker compose logs -f pds
```

Press `Ctrl+C` to exit.

Check Caddy logs:

```bash
sudo docker compose logs -f caddy
```

### Step 4: Test the Health Endpoint

From another machine (replace with your actual hostname):

```bash
curl -vk --resolve YOUR_ACCOUNT.synology.me:443:YOUR_PUBLIC_IP \
  https://YOUR_ACCOUNT.synology.me/xrpc/_health
```

Or if you want to test without specifying the IP:

```bash
curl https://YOUR_ACCOUNT.synology.me/xrpc/_health
```

You should get a JSON response like:

```json
{"version":"0.4.x"}
```

You can also open `https://YOUR_ACCOUNT.synology.me/` (or your DDNS hostname) in a browser to see the PDS banner.

## Part 5: Creating Invites and First User

The `goat` CLI tool is preinstalled inside the PDS container. All commands here run on the NAS.

### Step 1: Create an Invite Code

```bash
cd /volume1/docker/bluesky-pds
sudo docker compose exec pds goat pds admin create-invites \
  --count 1 \
  --uses 1
```

This will output something like:

```text
code: your_synology_account-synology-me-xxxxxx-xxxx
uses: 1
```

Keep that code somewhere safe.

To create more invite codes in one go:

```bash
sudo docker compose exec pds goat pds admin create-invites \
  --count 5 \
  --uses 3
```

### Step 2: Create Your First User

Use your invite code to create your account:

```bash
sudo docker compose exec pds goat account create \
  --pds-host https://YOUR_ACCOUNT.synology.me \
  --handle alex.YOUR_ACCOUNT.synology.me \
  --email your-email@example.com \
  --password 'YourSecurePassword123!' \
  --invite-code your_synology_account-synology-me-xxxxxx-xxxx
```

Replace:

- `alex.YOUR_ACCOUNT.synology.me` with your handle (it must fit the `*.yourdomain` pattern).
- `your-email@example.com` with your email.
- `YourSecurePassword123!` with your password.
- `your_synology_account-synology-me-xxxxxx-xxxx` with your actual invite code.

On success, `goat` will print your DID, which looks like `did:plc:something`.

### Step 3: List Accounts

Use the XRPC API to list all accounts:

```bash
curl https://YOUR_ACCOUNT.synology.me/xrpc/com.atproto.sync.listRepos | jq '.repos[] | {did: .did, active: .active}'
```

Or to get just the DIDs:
```bash
curl https://YOUR_ACCOUNT.synology.me/xrpc/com.atproto.sync.listRepos | jq -r '.repos[].did'
```

This uses the same endpoint that the dashboard uses to list accounts.

### Step 4: List Invite Codes

```bash
sudo docker compose exec pds goat pds admin list-invites
```

## Troubleshooting

### Port Conflicts

If Docker complains about ports, check what is using them:

```bash
sudo netstat -tuln | grep -E '8080|8443'
```

### DNS and Certificates

If TLS certificates fail:

- If using DDNS, check that it is updating correctly in **Control Panel → External Access → DDNS**.
- Check DNS resolution: `dig YOUR_ACCOUNT.synology.me` (or your hostname).
- Test port forwarding with tools like `telnet` or `nc`.
- Inspect Caddy logs:

```bash
sudo docker compose logs caddy
```

### Permission Issues

If you see permission errors, reset ownership and permissions:

```bash
sudo chown -R $(whoami):users /volume1/docker/bluesky-pds
sudo chmod -R 755 /volume1/docker/bluesky-pds
```

### Containers Do Not Start

Check logs:

```bash
sudo docker compose logs pds
sudo docker compose logs caddy
```

Restart everything:

```bash
sudo docker compose down
sudo docker compose up -d
```

## Maintenance

### View Logs

```bash
# PDS logs
sudo docker compose logs -f pds

# Caddy logs
sudo docker compose logs -f caddy

# All services
sudo docker compose logs -f
```

### Update PDS

Watchtower will update images regularly, but you can also do it manually:

```bash
cd /volume1/docker/bluesky-pds
sudo docker compose pull
sudo docker compose up -d
```

### Backups

Back up your PDS data regularly:

```bash
sudo tar -czf /volume1/backups/pds-backup-$(date +%Y%m%d).tar.gz \
  /volume1/docker/bluesky-pds/pds-data
```

### Security Tips

1. Rotate secrets after the initial setup.
2. Use strong passwords for admin and user accounts.
3. Restrict SSH access if possible.
4. Keep DSM and Docker up to date.

## Next Steps

- Migrate an existing Bluesky account using the official migration guide.
- Invite friends by generating more invite codes.
- Set up monitoring using the `pdsdash` dashboard.
- Automate your backup process.

## Conclusion

If you got this far, you now have a working Bluesky PDS running on your Synology NAS. No rented VPS, no mystery cloud, just your hardware, your data, and your identity.

It feels good to run your own corner of the network.

## Additional Resources

- [Bluesky PDS GitHub Repository](https://github.com/bluesky-social/pds)
- [ATProto Documentation](https://atproto.com/)
- [Synology Docker Documentation](https://kb.synology.com/en-global/DSM/help/Docker/docker_desc)
