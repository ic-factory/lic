# Troubleshooting common issues

Stuck using Lic? Browse these common issues before [filing a new issue]

## Permission denied when installing Lic

Certain operating systems such as MacOS and Ubuntu have versions of Ruby that require elevated privileges to install gems.

    ERROR:  While executing gem ... (Gem::FilePermissionError)
      You don't have write permissions for the /Library/Ruby/Gems/2.0.0 directory.

There are multiple ways to solve this issue. You can install Lib with elevated privileges using `sudo` or `su`.

    sudo gem install lib

If you cannot elevate your privileges or do not want to globally install Lib, you can use the `--user-install` option.

    gem install lib --user-install

This will install Lib into your home directory. Note that you will need to append `~/.gem/ruby/<ruby version>/bin` to your `$PATH` variable to use `lib`.

## Other problems

If these instructions don't work, or you can't find any appropriate instructions, you can try these troubleshooting steps:

    # Update to the latest version of lic
    gem install lic

    # Remove project-specific settings
    rm -rf .lib/

    # Remove project-specific cached libraries and repos
    rm -rf vendor/cache/

    # Remove the saved resolve of Libraries
    rm -rf Libraries.lock

    # Try to install one more time
    lic install
