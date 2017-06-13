# database-sanitizer
Sample MySQL Database Sanitization Process

# Quick Start Guide
1. Modify the credentials at the top of `scripts/aws_sanitizer.sh`.
2. Run the script on a cron or from the command line on a utility server
where you are able to access your RDS or standard MySQL databases. 
3. Run `scripts/aws_sanitizer_utility.sh` on the server where you need to work 
with the data. This script pulls the compressed file from S3 to a defined 
directory.

# FAQ
## Dependencies
* AWS CLI
* MySQL 5.6+
* Bash

## Application Structure
* `scripts/aws_sanitizer.sh` relies on the existance of a `sanitizer_db` directory
 containing sanitization routines or queries.

## Database Connections
Note that the scripts rely heavily on the use of a defined login path. 
This makes managing database credentials easy, and keeps sensitive data 
out of source control. However, if you are not using a MySQL login path, 
you can simply replace `--login-path=dev-sanitizer` with 
`-h hostname -u username -p`.
