# Chocolatey Packages
[![Build and Push all automatic packages](https://github.com/glennsarti/ChocolateyPackages/actions/workflows/build_and_push.yaml/badge.svg?branch=main)](https://github.com/glennsarti/ChocolateyPackages/actions/workflows/build_and_push.yaml)
![GitHub Gist last commit](https://img.shields.io/github/gist/last-commit/bd4f850684e8b9b26e9d64a87415d0ac?label=Update%20report&logo=github)

## Chocolatey Packages

This project contains the automatic updating packages for my public community chocolatey feed;

[https://chocolatey.org/profiles/GlennSarti](https://community.chocolatey.org/profiles/glennsarti)

## Package List

| Package | Link |
| ------- | ---- |
| gitsign | [Latest](https://community.chocolatey.org/packages/gitsign) |
| golangci-lint | [Latest](https://community.chocolatey.org/packages/golangci-lint) |

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
