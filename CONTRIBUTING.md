## How you can help


### Packaging
Some time ago, during the `0.7.0` release, I expressed my dissatisfaction with
Linux packaging overall, since it takes too much of my time to achieve so
little of result[^1]. Since then I changed my mind about packaging in general.
I still have no desire to maintain any packages myself, but always welcome
anyone to help me with that.

The source code structure is really not well thought out for packaging, so any
suggestions are always welcome!

Below are the instructions describing ways this project can be correctly
deployed on Linux systems. Before proceeding to them, make sure to read the
README [details section](./README.md#details) to get an overall knowledge about
the technical part of this project.

Ok, now to the fun part.


#### Source code root
All the source code in located in `src/` directory.

#### Environmental configurations
Environmental configurations are placed in `environment/` directory and are
just a simple text files with syntax `NAME=VALUE` that sets the value for
environmental variables. Files from this directory are meant to be sourced
either by PAM or shell, therefore the potential places you can deploy them to
are:

- `/etc/environment`: Appending the content of `environment/*` to this file is
  the most compatible way of handling the environmental variables. The
  variables are sourced once after system boot by PAM. This approach is used by
  main installation script, but is very nasty to use with package managers.
- _(Preferred for packaging)_ `/etc/profile.d/`: **TODO**
- `/etc/environment.d/`: **TODO**
    - https://www.freedesktop.org/software/systemd/man/latest/environment.d.html

#### Fontconfig rules
Fontconfig rules are placed in `fontconfig/` directory and are meant to be deployed directly to the `/etc/fonts/conf.d/` directly, without any changes.


[^1]: ./CHANGELOG.md#release-070
