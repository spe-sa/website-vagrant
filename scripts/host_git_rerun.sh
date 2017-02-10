echo "Setting Environment variables"
export DJANGO_BASE=../ubuntu/djangocms

cd $DJANGO_BASE

echo "Git clone website"
git clone https://github.com/spe-sa/website-code.git website
