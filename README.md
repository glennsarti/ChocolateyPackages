# Chocolatey Packages

[![](https://ci.appveyor.com/api/projects/status/github/puppetlabs/puppet-chocolatey-packages?svg=true)](https://ci.appveyor.com/project/puppetlabs/puppet-chocolatey-packages)
[Update status](https://gist.github.com/puppet-chocolatey-bot/07d26b70044a34c1d9aa5576057d515e)

## Chocolatey Packages

This project contains the automatic updating packages for my public community chocolatey feed;

[https://chocolatey.org/profiles/GlennSarti](https://community.chocolatey.org/profiles/glennsarti)

## Package List

* [tbc](https://chocolatey.org/packages/tba)

## Development

### Folder Structure

* automatic - where automatic packaging and packages are kept. These are packages that are automatically maintained using [AU](https://chocolatey.org/packages/au).

* icons - Where you keep icon files for the packages. This is done to reduce issues when packages themselves move around.

* setup - items for prepping the system to ensure for auto packaging.

For setting up your own automatic package repository, please see [Automatic Packaging](https://chocolatey.org/docs/automatic-packages)

### Requirements

* Chocolatey (choco.exe)

#### AU

* PowerShell v5+.
* The [AU module](https://chocolatey.org/packages/au).

For daily operations check out the AU packages [template README](https://github.com/majkinetor/au-packages-template/blob/master/README.md).
