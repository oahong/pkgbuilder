# Build debian packages from dsc (debian source package)
```sh
Usage:
  pkgbuilder -n PACKAGE|-d DSC [-u HOST] [-s SOURCE] [-b|-p] [-r] [-h]
  pkgbuilder -l | --list-src

Package builder for deepin shanghai team, version $SVERSION

Help Options:
  -h, --help                   Show help options
Application Options:
  -d, --dsc=DSC                Build a debian package according to a DSC (debian src control file)
  -l, --list-src               Print a list of predefined upstream sources
  -n, --package=PACKAGE        Build PACKAGE
  -u, --upload=HOST            Upload build artifacts to HOST, define HOST in dput config
  -s, --source=SOURCE          Download source package from predefined SOURCE (Read -l output)
  -b, --build                  Perform a package build via dpkg-buildpackage
  -p, --pbuilder               Perform a package build via pbuilder (recommended for a clean buid)
  -r, --rebuild                Rebuild an architecture independent package


Examples:
  pkgbuilder -l                                        List predefined upstream sources
  pkgbuilder -n foo                                    Prepare for building package foo
  pkgbuilder -n dde-desktop -b -s debian               Build foo from scratch, get dsc from debian
  pkgbuilder -n dde-desktop -b -u staging              Build foo then upload to host staging
  pkgbuilder -a mips64el -n base-files -p              Build foo in a clean mips64el chroot
```
