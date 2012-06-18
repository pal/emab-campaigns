emab-campaigns
==============

Simple tool to automate update of campaigns for EMAB members. 

Make sure you have a new domain and user setup according to the details in 
config/deploy.rb. Also setup password-less logins as per http://wiki.dreamhost.com/SSH#Passwordless_Login

Next, run
$ cap deploy:setup

And then:
$ cap deploy


To run locally:
$ ruby app.rb