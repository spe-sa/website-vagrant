#!/bin/bash
mkdir -p ../backups
scp jenkins.spe.org:/tmp/django.mysqlprod.spe.org.sql.gz ../backups/
scp jenkins.spe.org:/tmp/media.djangoprod.spe.org.tgz ../backups/ 
