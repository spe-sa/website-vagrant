#!/usr/bin/env python
import sys

cmdargs = str(sys.argv)

#print ("Args list: %s " % cmdargs)
#print ("Script name: %s" % str(sys.argv[0]))
#print ("First argument: %s" % str(sys.argv[1]))

from django.contrib.auth.models import User
u = User.objects.get(username=str(sys.argv[1]))
u.set_password('password')
u.save()
