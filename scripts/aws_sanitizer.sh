#!/bin/bash

# Define variables
login_path="dev-sanitizer"
s3_profile="dev-sanitizer"
s3_region="us-east-1"
s3_url="s3://s3.bucket.url"
local_directory="/tmp/sanitized"
filename="_sanitized.sql.bz2"

# Define empty lists for successes and failures.
# These will be populated with strings separated by whitespace, which function as elements in an array.
sanitized_success=""
sanitized_fail=""

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
    echo "AWS Config file is missing at /root/.aws/config"
    exit 1
fi

if [ ! -f "/root/.aws/credentials" ]; then
  echo "AWS Credentials file is missing at /root/.aws/credentials"
  exit 1
fi

# Create databases and definers
mysql --login-path=$login_path < /data/sites/database_sanitizer/databases/create.sql
mysql --login-path=$login_path < /data/sites/database_sanitizer/databases/definers.sql

# Loop through sanitizer routines directory to determine what we can sanitize
cd /data/sites/database_sanitizer/routines

# This regex assumes a file format similar to sanitize_products.sql
for routine in sanitize*.sql
do
    routine_name=$(echo $routine | sed 's/\.sql//')
    database=$(echo $routine | sed 's/\.sql//g ; s/^sanitize_// ')
    database_filename=$database$filename

    # Drop the database in sanitizer if it already exists
    mysql --login-path=$login_path -e "drop database if exists sanitize_$database;"

    # Create a database
    mysql --login-path=$login_path -e "create database sanitize_$database default character set utf8;"

    # Compile the stored routine for sanitization
    mysql --login-path=$login_path < $routine

    # Generate dump files of each database
    echo "Creating mysqldump of $database"
    mysqldump --login-path=$login_path --lock-tables=false $database | mysql --login-path=$login_path sanitize_$database

    # Run sanitization
    echo "Running sanitization routine $routine_name"
    sanitized=$(echo "call sanitize_$database.sanitize_$database(1);" | mysql --login-path=$login_path)

    # Check the status of compiling the stored routine
    # The stored routine should return the string "Success!". An error output will cause $? to return 0.
    if [ "$?" == 0]
    then
        echo "There was a problem executing the stored routine."
    fi

    if [ -z "$sanitized" ]
    then
        # Add entries to sanitized failure array. This is used to trigger an email notification at the end of the process.
        sanitized_fail+="$database "
        echo "The sanitization process for $database was not successful. No dump file will be created."
    fi

    if [ "$sanitized" ]
    then
        # Add entries to sanitized success array. This is used to trigger an email notification at the end of the process.
        sanitized_success+="$database "
        echo "The sanitization process was successful. Proceeding with creating the dump file."

        # Remove existing sanitized file
        rm -f "$local_directory"/"$database_filename"

        # Create compressed mysqldump file of the sanitized database
        mysqldump --login-path=$login_path --lock-tables=false --no-create-info --skip-triggers sanitize_$database | bzip2 > "$local_directory"/"$database_filename"

        # Send to S3
        /usr/local/bin/aws --profile $s3_profile s3 mv "$local_directory"/"$database_filename" "$s3_url"/"$database_filename" --region $s3_region

        echo "Compressed file $database_filename was created and sent to S3"
    fi

    # Drop the database
    mysql --login-path=$login_path -e "drop database sanitize_$database;"

    # Remove the SQL file if it still exists
    rm -f "$database"_sanitized.sql

    # Remove tar file so that we are not keeping the files on the server
    rm -f "$local_directory"/"$database_filename"
done

# Define array of databases that do not have sanitization queries
# Data from these databases is dumped directly from the database to a bzip2 file

databases="categories
products_categories"

for database in $databases
do
    database_filename=$database$filename

    # Make sure we are not working with null or empty database names
    if [ ! -z $database -a $database != " " ]
    then
        # Create mysqldump and pipe to compressed bzip file
        echo "Creating bzip compressed dump file of" $database

        mysqldump --login-path=$login_path --lock-tables=false --no-create-info --skip-triggers $database | bzip2 > "$local_directory"/"$database_filename"

        # Send to S3
        /usr/local/bin/aws --profile $s3_profile s3 mv "$local_directory"/"$database_filename" "$s3_url"/"$database_filename" --region $s3_region --sse

        # Remove SQL file artifact
        rm -f "$database"_sanitized.sql

        # Remove tar file so that we are not keeping the files on the server
        rm -f "$local_directory"/"$database_filename"
    fi
done

# Build HTML for an email notification
echo "Preparing email notification"
html_content="<p>The nightly sanitization process has completed.</p><h4>The following databases were sanitized without error and have been sent to S3:</h4><ul>"

for database in $sanitized_success
do
  html_content="$html_content <li>$database</li>"
done

html_content="$html_content </ul>"
html_content="$html_content <h4>The following databases could not be sanitized:</h4><ul>"

for database in $sanitized_fail
do
  html_content="$html_content <li>$database</li>"
done

html_content="$html_content </ul>"
html_content="$html_content <h4>The following databases do not contain sensitive data and have been sent to S3:</h4><ul>"

for database in $databases
do
  html_content="$html_content <li>$database</li>"
done

html_content="$html_content </ul>"

# Send email notification based on your server environment
# mail -s "Sanitizer Status" your@email.com <<< html_content

echo "Complete!"
exit
