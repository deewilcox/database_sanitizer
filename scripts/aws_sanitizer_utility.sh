#!/bin/bash

# Define variables
login_path="dev-sanitizer"
s3_url="s3://s3.bucket.url"
s3_profile="dev-sanitizer"
s3_region="us-east-1"
local_directory="/tmp/sanitized"

# Check for root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   exit 1
fi

# Check for aws cli tool and configuration file
if [ ! -f "/usr/local/bin/aws" ]; then
  echo "AWS CLI Tool does not seem to be installed. Visit http://docs.aws.amazon.com/cli/latest/userguide/installing.html#install-bundle-other-os"
  exit 1
fi

if [ ! -f "/root/.aws/config" ]; then
  echo "AWS config file is missing at /root/.aws/config"
  exit 1
fi

if [ ! -f "/root/.aws/credentials" ]; then
  echo "AWS credentials file is missing at /root/.aws/credentials"
  exit 1
fi

databases="products
categories
products_categories"

notification_message="<p>The following sanitized database dumps have been retrieved from S3 and are available on the utility server here: $local_directory:</p><ul>"

for database in $databases
do
  filename="_sanitized.sql.bz2"
  database_filename=$database$filename
  echo "Pulling $database_filename from S3 down locally to $local_directory/$database_filename"

  # Pull from S3
  /usr/local/bin/aws --profile $s3_profile s3 cp "$s3_url"/"$database_filename" "$local_directory"/"$database_filename" --region $s3_region

  # Adjust file permissions
  chmod 755 "$local_directory"/"$database_filename"

  # Build notification message
  notification_message="$notification_message <li>$database</li>"

  # Building logging message
  log_message="$log_message$database "
done

notification_message="$notification_message </ul><p>This completes the nightly sanitization process.</p>"

# Send email notification based on your server environment
# mail -s "Sanitizer Status" your@email.com <<< html_content

echo "Complete!"
exit
