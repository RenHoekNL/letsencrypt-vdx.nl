# letsencrypt-vdx.nl
This script is used with Letsencrypt certbot to easily create and renew wildcard DNS SSL certificates with the Dutch DNS host vdx.nl.

VDX is a Dutch DNS hosting company that doesn't offer an easy API to manipulate DNS entries, so this script screen-scrapes what is needed to add the challenges to your DNS. This makes automatic renewal possible.

I'm assuming you already certbot, if not, follow the instructions here: https://certbot.eff.org/instructions
I'm also assuming you have a domain registered with vdx.nl, otherwise what are you doing here? :)

```
apt install xmlstarlet           # Be sure this is installed

mkdir vdx
cd vdx
wget https://raw.githubusercontent.com/RenHoekNL/letsencrypt-vdx.nl/main/vdx.sh
chmod a+x vdx.sh
nano vdx.sh             # Put in your USERNAME and PASSWORD for the vdx website on the top of the script

certbot certonly --manual --manual-auth-hook ./vdx.sh -d mydomain.nl -d *.mydomain.nl --preferred-challenges dns
```

You should now have a new (or updated) certificate under /etc/letsencrypt/live/mydomain.nl/

Don't forget to restart your web daemon and other services to let them pick up the new certificate!
