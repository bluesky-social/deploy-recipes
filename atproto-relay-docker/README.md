# Dockerized AT Protocol Relay

First and foremost, I would like to give credit to [Fig](https://bsky.app/profile/did:plc:hdhoaan3xa3jiuq4fg4mefid), [Futur](https://bsky.app/profile/did:plc:uu5axsmbm2or2dngy4gwchec) and [Bryan](https://bsky.app/profile/bnewbold.net) for their writeups/advice/configurations which helped me come up with this.


# Hardware

See [Bryan's writeup for the kind of hardware you'll need for this](https://whtwnd.com/bnewbold.net/3lo7a2a4qxg2l) but you can definitely [run a Relay on a Raspberry Pi](https://whtwnd.com/futur.blue/3lkubavdilf2m).

For my Relay I ended up going with OVH with these specs:

- OS: Ubuntu Server 24.04 "Noble Numbat" LTS
- CPU: Intel Xeon-D 1520 - 4c/8t - 2.2 GHz/2.6 GHz
- RAM: 32 GB ECC 2133 MHz
- HDD: 2×2 TB HDD SATA

Way more than what I need but only costs about $24 CAD a month.

# Setup

Once you have your machine ready to go the setup is relatively straightforward. Make sure to have ``shuf`` and ``parallel`` installed on your machine since it'll be needed for the last couple of steps.

To start, clone the example setup from Tangled and change directory into the ``relay-docker`` project.

```bash
git clone git@tangled.sh:dane.is.extraordinarily.cool/relay-docker
cd relay-docker
```

You'll then need to clone the ``indigo`` repository inside of the ``relay-docker``project.

```bash
git clone git@github.com:bluesky-social/indigo.git
```

There is an ``.env.example`` file that you'll need to rename and fill in the information for.

```bash
mv .env.example .env
```

Then in your favourite text editor, open the ``.env`` file, we'll walk through what each variable does. If you want to read more about how everything works, [head over to the indigo repository](https://github.com/bluesky-social/indigo/blob/main/cmd/relay/README.md#configuration-and-operation).

``RELAY_LENIENT_SYNC_VALIDATION`` - If true, allow legacy upstreams which don't implement atproto sync v1.1. Would recommend to set this to ``true``

``RELAY_REPLAY_WINDOW`` - The duration of output "backfill window", eg 24h. Basically how much data the Relay stores and for how long. ``48h`` is what I have mine set as and it takes up about 200-300GB of disk space.

``RELAY_PERSIST_DIR`` - Where on the host machine the data is persisted. You can decide where but I've let it as ``/data/relay/persist``. 

``RELAY_ADMIN_PASSWORD`` - this is the admin password you'll use to log in to the relay admin dashboard. Make sure to set something secure and save it somewhere safe.

``RELAY_TRUSTED_DOMAINS`` - Which domains are "blessed", comma separated list. Typically means they have higher rate limits and won't get throttled by your relay. Should add ``*.host.bsky.network`` and other PDSes you know that you trust.

``RELAY_HOST_CONCURRENCY`` - 

# database env
DATABASE_URL=
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=



