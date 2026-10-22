#!/usr/bin/env bash

# change according to alpine and php release
PHP_VERSION=85

# Display PHP error's or not
if [[ "$ERRORS" != "1" ]] ; then
  sed -i -e "s/error_reporting =.*/error_reporting = E_ALL/g" /etc/php${PHP_VERSION}/php.ini
  sed -i -e "s/display_errors =.*/display_errors = stdout/g" /etc/php${PHP_VERSION}/php.ini
fi

# Disable opcache?
if [[ -v NO_OPCACHE ]]; then
    # opcache is built into PHP 8.5, so it can only be turned off with an ini setting
    echo 'opcache.enable = 0' > /etc/php${PHP_VERSION}/conf.d/zz-no-opcache.ini
fi

# Tweak nginx to match the workers to cpu's
procs=$(cat /proc/cpuinfo | grep processor | wc -l)
sed -i -e "s/worker_processes 5/worker_processes $procs/" /etc/nginx/nginx.conf

# Copy important env vars for PHP-FPM to access
PHP_ENV_FILE="/etc/php${PHP_VERSION}/php-fpm.d/${PHP_ENV_FILE:-env.conf}"
echo '[www]' > "$PHP_ENV_FILE"
echo 'user = nginx' >> "$PHP_ENV_FILE"
echo 'group = www-data' >> "$PHP_ENV_FILE"
echo 'listen.owner = nginx' >> "$PHP_ENV_FILE"
echo 'listen.group = www-data' >> "$PHP_ENV_FILE"
env | grep -e 'REPORT_DB_TYPE' -e 'REPORT_DB_HOST' -e 'REPORT_DB_PORT' -e 'REPORT_DB_NAME' -e 'REPORT_DB_USER' -e 'REPORT_DB_PASS' | sed "s/^\([^=]*\)=\(.*\)/env[\1] = '\2'/" >> "$PHP_ENV_FILE"

# compat from older image where variable was not existing
grep -e ^REPORT_DB_PORT "$PHP_ENV_FILE" || echo env[REPORT_DB_PORT] = 3306 >> "$PHP_ENV_FILE"

# create log directory
mkdir -p /var/log/dmarc 2>/dev/null

# Get and parse dmarc reports once at startup to avoid PHP errors with a new database
# may be disabled for tests
if [ $PARSER_RUN_ON_STARTUP -eq 1 ]; then
  if /usr/bin/dmarcts-report-parser.pl -i -d -r > /var/log/dmarc/dmarc-reports-parser.log 2>&1; then
    echo 'INFO: Dmarc reports parsed successfully'
  else
    echo 'CRIT: Dmarc reports could not be parsed. Check your IMAP and MYSQL Settings.'
    echo -e "DEBUG: Parsing failed with the following output:\n"
    cat /var/log/dmarc/dmarc-reports-parser.log
    exit 1
  fi
fi

# replace scheduling params in crontab file
sed -i "s/%%PARSER_CRON_HOUR%%/$PARSER_EXECUTION_HOUR/g"	/etc/cron.d/root
sed -i "s/%%PARSER_CRON_MIN%%/$PARSER_EXECUTION_MIN/g"		/etc/cron.d/root
sed -i "s/%%AGGREG_CRON_HOUR%%/$AGGREGATOR_EXECUTION_HOUR/g"	/etc/cron.d/root
sed -i "s/%%AGGREG_CRON_MIN%%/$AGGREGATOR_EXECUTION_MIN/g"	/etc/cron.d/root
sed -i "s/%%AGGREG_DELY_DAYS%%/$AGGREGATOR_DELAY_DAYS/g"	/etc/cron.d/root
sed -i "s/%%PURGER_CRON_HOUR%%/$PURGER_EXECUTION_HOUR/g"	/etc/cron.d/root
sed -i "s/%%PURGER_CRON_MIN%%/$PURGER_EXECUTION_MIN/g"		/etc/cron.d/root
sed -i "s/%%PURGER_RETN_DAYS%%/$PURGER_DATA_RETENTION_DAYS/g"	/etc/cron.d/root

# replace params in supervisor config files
sed -i "s/%%EXPORT_DELY_DAYS%%/$EXPORTER_DELAY_DAYS/g"		/etc/supervisor/conf.d/exporter.conf

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf
