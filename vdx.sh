#!/bin/bash

USER="xxxxxxxx"
PASS="mypassword"

echo "-------------------"
echo "CERTBOT_DOMAIN: $CERTBOT_DOMAIN"
echo "CERTBOT_VALIDATION: $CERTBOT_VALIDATION"
echo "CERTBOT_TOKEN: $CERTBOT_TOKEN"
echo "CERTBOT_REMAINING_CHALLENGES: $CERTBOT_REMAINING_CHALLENGES"
echo "CERTBOT_ALL_DOMAINS: $CERTBOT_ALL_DOMAINS"
echo "CERTBOT_AUTH_OUTPUT: $CERTBOT_AUTH_OUTPUT"
echo "Args: $*"
echo "-------------------"

# Login
URL="$(
curl 'https://accounts.vdx.nl/login' \
  --location \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'g=8&username='$USER'&password='$PASS'&action=login&service=https%3A%2F%2Fmijn.vdx.nl%2Flogin' \
  --silent \
  | grep href | tail -1 | cut -f 2 -d '"'
  )"
echo $URL

# This is needed for some reason
curl "$URL" \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  --location \
  --silent \
  > /dev/null

# Get DNS ID
IFS=$'\n'
ACCOUNT=( $(
curl 'https://mijn.vdx.nl/accounts' \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  --location \
  --silent \
  | tr -d '\n' | grep -o -P 'https://mijn\.vdx\.nl/accounts/[0-9]+">[^<]*' | sed -e 's~.*/~~' -e 's/">/\t/'
  ) )
echo "DNS entries found: "
DOMAIN_ID=""
for x in ${ACCOUNT[@]}; do 
  {
  echo "$x";
  if [ "$CERTBOT_DOMAIN" == "$(echo $x | cut -f 2)" ]; then
    {
    DOMAIN_ID="$(echo $x | cut -f 1)"
    echo "Updating domain $DOMAIN_ID"
    }
  fi
  }
done

if [ "$DOMAIN_ID" == "" ]; then
  {
  echo "Domain $CERTBOT_DOMAIN not found. Exiting.."
  exit
  }
fi

# Get DNS settings for this domain
curl 'https://mijn.vdx.nl/accounts/'$DOMAIN_ID'/dns' \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  --location \
  --silent \
  > dns.txt

# Extract DNS table from page
cat dns.txt | tr -d '\n' | grep -o -P '<form action="https://mijn.vdx.nl/acc.*?</form>' | xmlstarlet fo --recover --html --dropdtd > table.txt

# Build form data from table
cat table.txt | xmlstarlet sel -t -m '//tbody/tr/td' -v $'concat(./input/@name,"\t",./input/@value,"\n")' | grep -v -P "^\t$" | awk -v "CERTBOT_VALIDATION=$CERTBOT_VALIDATION" -v "CERTBOT_DOMAIN=$CERTBOT_DOMAIN" '
BEGIN{
FS=OFS="\t";
ord_init();
printf "CopyDnsZone=0\n"
if(CERTBOT_VALIDATION != "")
  printf "&XvalA_1=_acme-challenge&Xtype_1=7&XvalB_1&XvalC_1=" CERTBOT_VALIDATION "&Xdel_1=0"
printf "&addZone=7&";
}

function ord_init(low, high, i, t)
{
low = sprintf("%c", 7) # BEL is ascii 7
if(low == "\a")    # regular ascii
  {
  low = 0
  high = 127
  }
  else
  if(sprintf("%c", 128 + 7) == "\a")    # ascii, mark parity
    {
    low = 128
    high = 255
    }
    else        # ebcdic(!)
      {
      low = 0
      high = 255
      }

for(i = low; i <= high; i++)
  {
  t = sprintf("%c", i)
  ord[t] = i
  }
}

function escape(str, c, len, res) {
len = length(str)
res = ""
for(i = 1; i <= len; i++)
  {
  c = substr(str, i, 1);
  if(c == " ")
    res = res "+"
    else
    if (c ~ /[0-9A-Za-z\-\.\*_]/)
      res = res c
      else
      res = res "%" sprintf("%02X", ord[c])
  }
return res
}

{
printf "%s=%s\n&\n", $1, escape($2)
}
' | head -n -1  `# Remove last ampersand` > data.txt

# Modify '_acme-challenge'

cat data.txt | tr -d '\n' > data2.txt

# Save the modified data
curl 'https://mijn.vdx.nl/accounts/'$DOMAIN_ID'/dns/save' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-binary @data2.txt \
  --cookie cookie.txt \
  --cookie-jar cookie.txt \
  --location \
  --silent \
  > /dev/null

rm -f cookie.txt dns.txt table.txt data.txt data2.txt

# Sleep to make sure the change has time to propagate over to DNS
sleep 30

# EOF
