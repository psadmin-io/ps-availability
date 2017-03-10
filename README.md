# PeopleSoft System Status Notifications

Do you get notified if an app server, web server or process scheduler go down? If you do, good for you! If not, here is a solution I put together that will send you notifications (and build a status page) if a web server, app server, or process scheduler go down.

If you are an admin who doesn't have access to monitoring tools (and there are lots of you), this post will go over a script I wrote to build a System Status page and send email notifications. You can run the script on any machine and it will send an email if anything has gone down. A `status.html` page is also generated so that users can go check on the status for their system.

<img src="https://github.com/psadmin-io/ps-availability/blob/master/version2.gif" alt="Status HTML Page" />

This page and script is something I put together over a few days. We wanted a simple page that would give us the status of each component in an environment. I used the Ruby Gem Mechanize to open the login page, login as a user, and navigate to the Process Monitor Server List page.

This isn't the most robust script (I'll explain the limitations in the post), but I wanted to share the scripts so other people could use it. If you rely on end users to tell if you an environment is down, this script can help you out.

**Version 2.0**

I made some improvements to the script for version 2.0. 

* Removed `Redcarpet` gem dependancy and interim Markdown tables
* Switched from `.bat` files and commands to Powershell
* Added checks for Fluid homepages
* Check for Stale process schedulers
* Report back IB Domain Status (only reports - does not influence up/down notifications)
* Hide IB Domain info - click on environment to see detail

With Version 2.0, there are three additional configuration settings in the file: 

* Fluid Homepage title check (default: `Homepage`)
* Time zone for your process schedulers (default: `US Central`)
* Stale interval for your process schedulers (default: `30` minutes)


## Install Prerequisites

The script is written in Ruby, uses Mechanize gem for interacting with Peoplesoft, Markdown for formatting, the Redcarpet gem for generating HTML documents, and the Mail gem for emailing status updates. So we'll need to install all those parts. It sounds like a lot, but it's pretty simple.

We'll walk through the installation process. I'm writing the instructions for Windows, but the Linux steps will be similar.

### Oracle Client

The script uses `tnsping` to check the database status, so we need to have the Oracle Client installed on the machine. You also need to have a `tnsnames.ora` file with entries for all the databases you want to check. You can place the `tnsnames.ora` file anywhere on the server; the `status.bat` script will set the `TNS_ADMIN` environment variable to point to your `tnsnames.ora` file.

### Ruby Dev Kit

We'll install the Ruby Dev Kit (2.2.4 is what I'm using) on the machine where our scripts will run. Download the Ruby installer from here:

    http://rubyinstaller.org/downloads/
    

I installed the files to `e:\ruby22-x64` and selected the option to add executables to the PATH variable.

Next, download the DevKit from the same site. The DevKit includes tools to build Gems from source, so we need to the additional tools included with the DevKit. If you run into issues install the Gems, this might be why.

I installed the DevFiles to `e:\ruby22-x64-devkit`. Open a new command prompt as an Administrator.

1.  `e:`
2.  `cd ruby22-x64-devkit`
3.  `ruby dk.rb init`
4.  `notepad config.yml`
5.  Add `- e:/ruby22-x64` to the end of the file (notice the dash and forward slash)
6.  Save and close the `config.yml` file
7.  `ruby dk.rb install`

> [Follow the instructions here if you have issues with the DevKit installation.][1]

### Gems

Ruby has a powerful package manager called "Gems". The `gem` command is part of the Ruby Dev Kit, so we can install the extra packages we'll use for our status page. Open a new command prompt as an Administrator and we'll install the Gems.

1.  `where ruby`

Make sure this command points to our new `e:\ruby22-x64` folder first.

1.  `gem install mechanize`
3.  `gem install mail`

That's it for the Gems.

## More Information

To get more details on the script, visit [psadmin.io](http://psadmin.io) and [check out the blog post on the script](http://psadmin.io/2016/03/14/peoplesoft-system-status-notifications/).

 [1]: https://github.com/oneclick/rubyinstaller/wiki/Development-Kit
