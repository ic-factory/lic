# Lic: Library manager for Integrate Circuit designs

Lic is an application that manages IP libraries for IC projects, whether that being a chip project or a higher level library. It does this by managing the libraries that the IC chip project - or IP library - depends on. Given a list of libraries, it can automatically download and install those gems at a local or shared direcotry, as well as any other libraries needed by the libraries that are listed. It checks the versions of every library to make sure that they are compatible and can all be loaded at the same time. After the libraries have been installed, Lic can help you update some or all of them when new versions become available. Finally, it records the exact versions that have been installed, so others can install the exact same libraries.

It is a fork of the tool called [Bundler](http://bundler.io), which is used to manage Ruby packages (gems). The Ruby gem file format is basically just a TAR file which includes the package data and a specification of the package (version, dependencies etc.). This file format is also used by Lic for IP libraries, since this enables reused of existing tools like Gem (to create the libraries) and [GemInABox](https://github.com/geminabox/geminabox) to allow easy browsing.

### Installation and usage

To install (or update to the latest version):

```
gem install lic
```

To install a prerelease version (if one is available), run `gem install lic --pre`. To uninstall Lic, run `gem uninstall lic`.

Lic is used to manage your projects's IP library dependencies. For example, these commands will allow you to use Lic to manage a library called `iic_master` for your project:

```
lic init
lic add iic_master
lic install
```

### Troubleshooting

For help with common problems, see [TROUBLESHOOTING](doc/TROUBLESHOOTING.md).

### Other questions

To see what has changed in recent versions of Lic, see the [CHANGELOG](CHANGELOG.md).

### Contributing

If you'd like to contribute to Lic, that's awesome. Just reach out to us!

### License

Lic is available under an [MIT License](https://github.com/ic-factory/lic/blob/master/LICENSE.md).
