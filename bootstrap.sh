# make sure our data exists or bail
if [ -d "/vagrant/backups" ]; then
	echo 'data found; continuing...'
else
	echo 'no data found; stoping install...'
	echo 'cd to the /vagrant share/scripts directory and run copy_backup_files.sh until they complete'
	echo 'then run vagrant up --provision again'
	exit 1
fi

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }

cat /vagrant/files/.profile > /home/ubuntu/.profile
. /home/ubuntu/.profile

apt-get update
apt-get install apache2 python-pip python-virtualenv git mysql-client libmysqlclient-dev \
python-dev libjpeg8-dev zlib1g-dev libsasl2-dev libldap2-dev libssl-dev libgeoip-dev libapache2-mod-wsgi  -y

# id -u ubuntu &>/dev/null || useradd -d /vagrant/ubuntu -g www-data -m -G sudo ubuntu
# NOTE: instead of changing ownership of the www-data files I am instead adding ubuntu
# 	group to www-data user since vagrant takes care of making sure those are always set
usermod -a -G www-data ubuntu

debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
apt-get -y install mysql-server -y

mkdir -p /vagrant/status/
mkdir -p $DJANGO_BASE
mkdir -p $DJANGO_BASE/website_content
mkdir -p $DJANGO_BASE/website_content/media
mkdir -p $DJANGO_BASE/website_static

echo 'setting up databases'
export MYSQL_PWD=root

echo 'restore django database if it is not already running...'
mysql -u root django -e 'exit'
if [ $? -gt 0 ]
  then 
    echo 'database not found; restoring database...'
    try export ENVIRONMENT=`hostname`
	try export DUMPFILE=/vagrant/backups/django.mysqlprod.spe.org.sql.gz

	if [ ! -f $DUMPFILE ]
  	then
    	echo "$DUMPFILE does not exist - exiting"
    	exit 111
	fi
	echo 
	echo 
	mysql -u root -e 'create database django'
	echo restoring django database on $ENVIRONMENT
	try zcat $DUMPFILE | mysql --user=root django
	echo database restored....
	
	if [ -f "/vagrant/status/db_provisioned" ]; then
		echo 'database previously provisioned; skipping database provisioning...'
	else
		echo 'running database provisioning...'
		# echo 'bind-address            = 0.0.0.0' >> /etc/mysql/mysql.conf.d/mysqld.cnf
		cat /vagrant/files/mysqld.cnf > /etc/mysql/mysql.conf.d/mysqld.cnf
		echo **********
		mysql -u root -e "update mysql.user set host='%' where user = 'root';"
		echo **********
        echo 'attempting to add back users...'
        mysql -u root django < /vagrant/add_users_back.sql
		service mysql restart
		echo 'database provisioning complete...'
		echo 
		echo 
	fi
	
    touch /vagrant/status/db_provisioned
else
    echo 'existing database found; skipping restore...'
    echo 
    echo 
fi
echo 

# if we don't have a website folder attempt to git clone code into it
if [ -d "$DJANGO_BASE/website" ]; then
	echo 'website folder exists skipping git pull...'	
	echo
	echo
else
	echo 'setting up django website codebase from git repo...'
	git clone https://github.com/spe-sa/website-code.git website/
fi

# all the rest depend on website folder existing; if not then don't try to run these
if [ -d "$DJANGO_BASE/website" ]; then

	if [ -d "$DJANGO_BASE/website/mainsite" ]; then
		cd $DJANGO_BASE/website/mainsite
		echo
		echo 're-building wsgi.py from environment variables...'
		cat wsgi.py | egrep -v "os.environ|application = get_wsgi_application()" > wsgi.tmp
		echo "os.environ['DJANGO_SETTINGS_MODULE'] = 'mainsite.settings."$DJANGO_ENVIRONMENT\' >> wsgi.tmp
		echo "application = get_wsgi_application()"  >> wsgi.tmp
		mv wsgi.tmp wsgi.py	
	else
		echo 'ERROR: mainsite folder was not found; this should never happen...'
		echo ' try deleting the $DJANGO_BASE/website directory and then'
		echo ' try running /scripts/host_git_rerun.sh script manually from host until successful'
		echo ' then try running vagrant up --provision again'
		echo ' there should be a minsite subfolder created if the git pulled correctly'
		echo ' finally try running vagrant up --provision again'
		exit 1
	fi

	cd $DJANGO_BASE/website

	echo
	echo
	echo "upgrading pip..."
	pip install --upgrade pip

	echo
	if [ -f "$DJANGO_BASE/website/requirements.txt" ]; then
		echo "requirements.txt exists; installing modules from it..."
		pip install -r ./requirements.txt
		echo "making pip install files writeable for future updates..."
		cd /usr/local/lib/python2.7/dist-packages
		chmod -R g+w *
		echo "changing back to website directory for further processing..."
		cd $DJANGO_BASE/website 
		# /vagrant/scripts/django_setup2.sh >> /tmp/django_setup.out
		# pulling script in
		# TODO : fix so we know we provisioned the makemigrations and faked but not have files not checked in...
		if [ -f "/vagrant/status/migrations_provisioned" ]; then
			echo 'migrations previously provisioned; skipping database code sync...'
		else
			echo 'running django makemigrations and migrations --fake'
			./make_migrations.sh
			./manage.py migrate --fake
			touch /vagrant/status/migrations_provisioned
		fi
		if [ "$(ls -A $DJANGO_BASE/website_static)" ]; then
			echo 'collect static files directory not empty; skipping...'
		else
			echo 'static files directory empty; running django collectstatic...'
			./manage.py collectstatic --noinput
			touch /vagrant/status/collectstatic_provisioned
		fi	
		echo 'django setup and sync complete...'
	else
		echo 'ERROR: requirements.txt not found; skipping pip installs...'
		echo ' try running /scripts/host_git_rerun.sh script manually from host until successful'
		echo ' if a website directory exists delete and then try to run the script again'
		echo ' finally try running vagrant up --provision again'
		exit 1
	fi

	if [ -f "/vagrant/status/passwords_provisioned" ]; then
		echo 'passwords previously provisioned; skipping password provisioning...'
	else
		echo 'running password provisioning...'
		cp /vagrant/scripts/pwchange.py $DJANGO_BASE/website/
		cd  $DJANGO_BASE/website/
		for user in `mysql -s -N --user=root django -e "select username from auth_user;"`
  		do
    		echo updating $user
    		./pwchange.py $user
		done
		rm $DJANGO_BASE/website/pwchange.py
		touch /vagrant/status/passwords_provisioned
		echo 'password reset complete...'
	fi

	if [ "$(ls -A $DJANGO_BASE/website_content/media)" ]; then
		echo "$DJANGO_BASE/website_content content not empty skipping..."
	else
		echo "$DJANGO_BASE/website_content content empty; processing..."
		cd $DJANGO_BASE/website_content
		tar -xvzf /vagrant/backups/media.djangoprod.spe.org.tgz
		touch /vagrant/status/content_extraction_provisioned
	fi

	if [ -f "/etc/apache2/sites-available/provisioned" ]; then
		echo 'apache was provisioned; skipping apache configuration...'
	else
		echo 'configuring apache...'
		cat /vagrant/files/000-default.conf > /etc/apache2/sites-available/000-default.conf
		echo "ServerName localhost.localdomain"  >> /etc/apache2/apache2.conf
		a2enmod headers substitute
		service apache2 restart
		touch /etc/apache2/sites-available/provisioned
		touch /vagrant/status/apache_provisioned	
	fi
	echo 'provisioning complete!'
	echo 'run /scripts/host_create_env.sh to create a virtual env foder for your IDE to attach to'
	echo 'run vagrant ssh to manage things on your vm and look at logs'
	echo 'common operations:'
	echo '     sudo system apache2 restart'
else
	echo 'ERROR: website folder was not found; skipping everything else...'
	echo ' try running /scripts/host_git_rerun.sh script manually from host until successful'
	echo ' then try running vagrant up --provision again'
	exit 1
fi








