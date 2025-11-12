# Dockerized AT Protocol Relay

First and foremost, I would like to give credit to [Fig](https://bsky.app/profile/did:plc:hdhoaan3xa3jiuq4fg4mefid), [Futur](https://bsky.app/profile/did:plc:uu5axsmbm2or2dngy4gwchec) and [Bryan](https://bsky.app/profile/bnewbold.net) for their writeups/advice/configurations which helped me come up with this.


# Hardware

See [Bryan's writeup for the kind of hardware you'll need for this](https://whtwnd.com/bnewbold.net/3lo7a2a4qxg2l) but you can definitely [run a Relay on a Raspberry Pi](https://whtwnd.com/futur.blue/3lkubavdilf2m).

A relay that's non-archival can usually run pretty efficiently on commodity hardware. For CPU and RAM, it can run fine on about 2-4 CPU cores and 4 GB of RAM. For bandwidth you'll need at least a 200 Mbps unmetered connection.

Disk space will greatly depend on the backfill window you set and also depends on the network traffic for that window. A 48h backfill window can take up around 200-400GB of disk space.

# Setup

Once you have your machine ready to go the setup is relatively straightforward.

To start, clone the example setup from Tangled and change directory into the ``relay-docker`` project.

```bash
git clone git@tangled.sh:dane.is.extraordinarily.cool/relay-docker
cd relay-docker
```

You'll then need to clone the ``indigo`` repository inside of the ``relay-docker``project.

```bash
git clone git@github.com:bluesky-social/indigo.git
```

## Environment Variables

There is an ``.env.example`` file that you'll need to rename and values to the variables within that file.

```bash
cp .env.example .env
```

Then in your favourite text editor, open the ``.env`` file, we'll walk through what each variable does. For a full list of the available configurable environment variables, [head over to the indigo repository](https://github.com/bluesky-social/indigo/blob/main/cmd/relay/main.go#L48).

``RELAY_LENIENT_SYNC_VALIDATION`` - If true, allow legacy upstreams which don't implement atproto sync v1.1. Would recommend to set this to ``true``

``RELAY_REPLAY_WINDOW`` - The duration of output "backfill window", eg 24h. Basically how much data the Relay stores and for how long.

``RELAY_PERSIST_DIR`` - Where on the host machine the data is persisted. You can decide where you want this to be but I've left it as ``/data/relay/persist``. 

``RELAY_ADMIN_PASSWORD`` - this is the admin password you'll use to log in to the relay admin dashboard. Make sure to set something secure and save it somewhere safe.

``RELAY_TRUSTED_DOMAINS`` - Which domains are "blessed", comma separated list. Typically means they have higher rate limits and won't get throttled by your relay. Should add ``*.host.bsky.network`` and other PDSes you know that you trust.

``RELAY_HOST_CONCURRENCY`` - Number of concurrent worker routines per upstream host. This probably depends on your machine specs but I've configured mine at ``4``.

Then you'll need to set up your environment variables for the database.

``DATABASE_URL`` - postgres://relay:POSTGRES_PASSWORD_HERE@localhost:5432/relay

``POSTGRES_USER`` - should be ``relay``

``POSTGRES_PASSWORD`` - a secure password of your choosing, e.g ``openssl rand -base64 32``

``POSTGRES_DB`` - also should be called ``relay``

## Proxy

The relay is designed to be run behind a [Reverse Proxy](https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04#introduction) to manage web ingress. This relay setup uses Caddy, but you can use Nginx or another option, following these Caddy settings:

```bash
yourdomain.com {
    tls {
      on_demand
    }

    handle /xrpc/com.atproto.sync.subscribeRepos {
      reverse_proxy 127.0.0.1:2470 {
        header_up Origin "yourdomain.com"
      }
    }

    reverse_proxy localhost:2470
}
```

Open the ``Caddyfile`` inside of the ``conf/`` directory and make these changes.

Replace all occurances of "yourdomain.com" with the actual domain you want your relay to be reachable at and then save the file.

> [!NOTE]
> Caddy users: For the ``header_up Origin "yourdomain.com"`` line make sure to keep the quotes when replacing the domain name with your actual domain name.

That should be all the set up to get the relay at least running, so the next step would be to run ``docker compose``. You'll want to be inside of the ``relay-docker`` directory.

```bash
docker compose up -d
```

You can verify that it is running by going to your domain in your browser.

## Bootstrapping Host List

Now that you have the Relay running in the container, you'll want to install a few more scripts on the host machine to help with connecting PDSes to your relay.

- Install ``goat``: https://github.com/bluesky-social/goat
- Install ``shuf``: https://linux.die.net/man/1/shuf
- Install ``parallel``: https://linux.die.net/man/1/parallel

> [!CAUTION]
> It is [recommended to increase the "new-hosts-per-day" limit temporarily before continuing with the next steps](https://github.com/bluesky-social/indigo/blob/main/cmd/relay/README.md#bootstrapping-host-list).

To increase the new hosts per day limit, go to your relay dashboard at ``yourdomain.com/dash/``. This should bring you to a login page.

![log in page for an atprotocol relay](relay-dashboard-login.png)

The "Access Token" would be your ``RELAY_ADMIN_PASSWORD`` that you set earlier in your ``.env`` file.

Once you're logged in, in the top right you should see an input that says "50 PDS/day". Change that number 50 to something really large temporarily and click update.

![a dashboard view of all the personal data servers a relay is connected to](relay-dashboard-pds-list.png)

Now, back in your terminal. Give execute permissions to the ``pull-hosts.sh`` bash script. All this script does is get a list of PDSes. It is [based on this repository](https://github.com/mary-ext/atproto-scraping).

```bash
chmod +x pull-hosts.sh
```

Then we can run the script and then send the output to a .txt file.

```bash
./pull-hosts > hosts.txt
```

With that done, we can now bootstrap the relay with hosts.

```bash
shuf hosts.txt | RELAY_HOST=http://localhost:2470 parallel goat relay admin host add {}
```

This may take a while to complete but once it's done you should be able to see all of the PDSes inside of your relay dashboard. Remember to switch that "new hosts per day" limit back to 50 once the above is done.

# What to be aware of

- Running a relay is fairly low maintenance, just check on it every so often but you shouldn't need to do anything after setting it up.
- Log in to your dashboard once or twice a week and bump the repo limit for non-bluesky PDSes that you trust that are reaching the repo limit to prevent them from being throttled by your relay. By default the repo limit for non-trusted PDSes is 100.