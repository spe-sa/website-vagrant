	echo "attempting to update virtualenv and then create an env"
	cd ..
	virtualenv env
	source env/bin/activate
	pip install -r ubuntu/djangocms/website/requirements.txt
	deactivate
	echo "done"
