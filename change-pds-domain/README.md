# Changing Your PDS Domain

This guide walks through the process of changing the domain name for your AT Protocol Personal Data Server (PDS).

## Prerequisites

- Access to your PDS shell
- Your PDS rotation private key (available with root access to the PDS)
- Administrative access to your new domain's DNS settings

## Step-by-Step Instructions

### 1. Get your rotation private key

Retrieve your rotation private key from your PDS `/pds/pds.env` file. Look for the variable:

```
PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX
```

This key is required to authorize domain changes with the PLC directory.

### 2. Access the PLC Operation Tool

Go to the PLC operation tool at:
```
https://boat.kelinci.net/
```

### 3. Start the PLC Operation Process

- Select "Apply PLC Operations"
- Enter your handle or DID
- Select "my own rotation keys"

### 4. Enter Your Rotation Key

- Add the private key you retrieved in step 1
- Select "ES256K (secp256k1) private key" as the key type

### 5. Update the PDS URL

- Select "Append an operation" and click "Next"
- In the payload JSON, update the PDS URL by modifying the `services.atproto_pds.endpoint` field
- Confirm that you want to change the PDS URL

### 6. Update Your PDS Configuration Files

After completing the PLC operation, you need to update your PDS configuration:

- Update the `PDS_HOSTNAME` value in your `pds.env` file to reflect the new PDS URL
- Update the PDS hostname in the Caddy configuration file located at `/pds/caddy/etc/caddy/Caddyfile`.
This step is particularly important for applications that use OAuth to find your PDS' OAuth Protected resources.

### 7. Restart Your PDS

From the AT Proto PDS repository directory, restart your PDS to apply the changes:

```bash
docker compose up -d
```

## Troubleshooting

If you encounter issues:

- Verify that your DNS settings are correctly pointing to your server
- Check that the Caddyfile configuration is correct
- Ensure your firewall allows traffic on ports 80 and 443
- Review the PDS logs for any errors: `docker compose logs pds`

## Additional Notes

- The domain change may take some time to propagate through the PLC network
- Users who have already authenticated with your PDS may need to re-authenticate
- Make sure to update any documentation or references to your PDS URL
