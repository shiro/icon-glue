# Icon Glue

Keep custom icons on Windows, even after software updates (I'm looking at you Ad*be).

## Usage

This script is best configured to run automatically on logon.

It can override icons of shortcuts located in the start menu
and associate icons with specific file types and set the default
application responsible to open the filetype.

Simply run again whenever your icons have been reverted.

### Shortcut icons

To override shortcut icons in the `start menu` (or any other folder)
recursively simply edit the `shortcuts` property of `config.json` to you liking.

### Filetypes

To associate a filetype (by extension) with an icon and default applicatoin
simply edit the `filetypes` property of `config.json` to you liking.

## Install

- Clone this repo
- Edit `config.json` to match your icons
