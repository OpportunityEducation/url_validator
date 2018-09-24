# Setup

## System Updates

Launch the App Store, go to the "Updates" section, and run "Update All"

## Xcode

Launch the App Store, search for Xcode, and install.  This will probably take a while.

## Command Line Tools

Open Terminal and run the following command:

`xcode-select --install`

Follow the prompts as necessary

## Homebrew

Homebrew allows us to install and compile software packages easily from source.

Homebrew comes with a very simple install script. If it asks you to install XCode CommandLine Tools, say yes.  However, since we did this in the previous step, this should be unnecessary.

Open Terminal and run the following command:

`ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`

## Installing JRuby

For all platforms, make sure you have [Java SE](http://www.oracle.com/technetwork/java/javase/downloads/index.html) installed. You can test this by running the command `java -version`.

## rbenv & ruby-build

Now that we have Homebrew installed, we can use it to install Ruby.

We're going to use rbenv to install and manage our Ruby versions.

To do this, run the following commands in your Terminal:

```shell
brew install rbenv ruby-build

# Add rbenv to bash so that it loads every time you open a terminal
echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.profile
source ~/.profile

# Install Ruby
rbenv install jruby-9.1.17.0
ruby -v
```

## Bundler

In rbenv, gems are silo'ed to each specific ruby version.  That means, whenever we install a new ruby version, we also need to globally install bundler for that version.

Open Terminal and run the following command:

```shell
# Ensure you're using the correct ruby version
ruby -v # Should be the version installed above

gem install bundler --no-ri --no-rdoc
```

## Install git

OSX ships with a version of git, but it's locked to the OS.  We want to use the homebrew version of git, so install that now.

Open Terminal and run the following command:

`brew install git`

## Configure git

We'll be using Git for our version control system so we're going to set it up to match our [Github](https://github.com) account. If you don't already have a Github account, make sure to [register](https://github.com). It will come in handy for the future.

Replace the example name and email address in the following steps with the ones you used for your Github account.

```shell
git config --global color.ui true
git config --global user.name "YOUR NAME"
git config --global user.email "YOUR@EMAIL.com"
```

## Generate SSH Keys

SSH keys are easier to manage than username/password when interacting with github over the command line, so let's generate those now:

`ssh-keygen -t rsa -C "YOUR@EMAIL.com"`

The next step is to take the newly generated SSH key and add it to your Github account. You want to copy and paste the output of the following command and paste it [here](https://github.com/settings/ssh).

```shell
# pbcopy will copy the output to your clipboard
cat ~/.ssh/id_rsa.pub | pbcopy
```

Once you've done this, you can check and see if it worked:

`ssh -T git@github.com`

You should get a message like this:

`Hi username! You've successfully authenticated, but GitHub does not provide shell access.`

## Install oh-my-zsh (Optional)

I prefer zsh to bash for many reasons (of which I'm too lazy to enumerate here).

To install, open Terminal and run the following command:

`sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"`

## Install Inconsolata (Optional)

Inconsolata is an awesome monospaced font.

To install, [download the OpenType file](http://www.levien.com/type/myfonts/Inconsolata.otf), launch the file, and then click "Install Font" in the launched window.

## Clone the project

I like to keep all of my projects in either a `projects` directory or an `oef` directory.  Let's set that up first.

Open Terminal and run the following:

```shell
cd ~
mkdir oef
cd oef
```

Alternatively, if you installed zsh, you can shorten this to:

```shell
cd ~
take oef
```

Now let's clone the project into our newly created directory:

`git clone git@github.com:OpportunityEducation/url_validator.git`

## Bundle gems

If you're not already in the directory, `cd` into the project and run the following:

`bundle install --path vendor`

This will isolate your gems per project instead of installing them globally.  The unfortunate side effect of this is that you must prefix most rails commands with `bundle execute`.  This can be mitigated by both `binstub`s and `alias`es (discussed later).

## Run the tests

A good way to see whether or not everything is set up and properly configured is to run the tests.

`bundle exec rspec`

## Executing the app script

Make sure you're in the main directory

```shell
cd ~/oef/url_validator
```

Run the script, passing in the required env variables

```shell
SENDGRID_API_KEY="API_KEY_HERE" AWS_ACCESS_KEY_ID=API_KEY_HERE AWS_SECRET_ACCESS_KEY=API_KEY_HERE \
QUEST_URL=https://org-opportunityeducation-quest-production-report.s3.amazonaws.com/quest_urls.json \
RESOURCE_URL=https://org-opportunityeducation-quest-production-report.s3.amazonaws.com/resource_urls.json \
MAX_THREADS=200 WHITELIST='npr.org,quora.com,usanews.com' TO=links@questforward.org ./app.rb
```

Explanation of env vars:

`SENDGRID_API_KEY`: The sendgrid API key - required to send the email

`AWS_ACCESS_KEY_ID`: The AWS access key ID - required to upload the report

`AWS_SECRET_ACCESS_KEY`: The AWS access secret key - required to upload the report

`QUEST_URL`: The list of quest external URLs

`RESOURCE_URL`: The list of resource external URLs

`MAX_THREADS`: The number of threads to use - I recommend 200

`WHITELIST`: Comma-delimited list of domains to ignore - these domains typically give back false negatives

`TO`: The email address to send the report to

## Setup profile and aliases (Optional)

I've come up with a few aliases over the years that I think help with rails development.  Those are documented here:

* [My profile](https://github.com/jerhinesmith/dotfiles/blob/master/profile)
* [My aliases](https://github.com/jerhinesmith/dotfiles/blob/master/aliases)

## Helpful Apps

Here's a list of apps that I find useful on OSX:

### Development

* [Sublime Text 3](http://www.sublimetext.com/3) is a sophisticated text editor for code, markup and prose.

### Other
* [f.lux](https://justgetflux.com/) makes the color of your computer's display adapt to the time of day, warm at night and like sunlight during the day.
* [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) is a tiny program that puts an icon in the right side of your menu bar. Click it to prevent your Mac from automatically going to sleep, dimming the screen or starting screen savers.
* [1password](https://agilebits.com/onepassword) creates strong, unique passwords for every site, remembers them all for you, and logs you in with a single tap.
