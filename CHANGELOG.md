## Release 0.12.0 - Dev
> **Notice**
>
> Previous issues with per-user mode possible symbolic link corruptions on
> uninstall and upgrade have been resolved and mitigated in this release. No
> manual intervention is required.

- New grouped structure for project modules in script to allow the selective
  installations using the new environmental variables: `ENABLE_ENVIRONMENT`,
  `ENABLE_FONTCONFIG` and `ENABLE_METADATA`.

- Fix the per-user symbolic link corruption issue on project uninstall or
  upgrade and automatically mitigate the already existing installations
  ([detailed report](https://github.com/maximilionus/lucidglyph/issues/19)).

- Attempting to install the project in per-user mode with elevated permissions
  will now request manual user confirmation after notice.


## Release 0.11.1
> **Caution for per-user mode**
>
> If you are a power user that heavily relies on symbolic links for custom
> fontconfig rules and use lucidglyph versions from `0.10.0` to `0.11.1`,
> please [check this](https://github.com/maximilionus/lucidglyph/issues/19) to
> avoid the possible symlinks corruption on this project upgrade or removal in
> per-user mode.

- Fix main installation script backwards compatibility handling and add
  detection for new potential installations through package managers.


## Release 0.11.0
> **Caution for per-user mode**
>
> If you are a power user that heavily relies on symbolic links for custom
> fontconfig rules and use lucidglyph versions from `0.10.0` to `0.11.1`,
> please [check this](https://github.com/maximilionus/lucidglyph/issues/19) to
> avoid the possible symlinks corruption on this project upgrade or removal in
> per-user mode.

- Main script now supports re-installation by user confirmation when
  attempting to install an already installed version of the project.

- Remove the `cff`, `type1`, `t1cid` drivers custom stem-darkening values that
  corrupted the font rendering and use the default ones. This will inevitably
  add back the Cantarell font regression, but that's a trade-off that has to be
  made.


## Release 0.10.1
> **Caution for per-user mode**
>
> If you are a power user that heavily relies on symbolic links for custom
> fontconfig rules and use lucidglyph versions from `0.10.0` to `0.11.1`,
> please [check this](https://github.com/maximilionus/lucidglyph/issues/19) to
> avoid the possible symlinks corruption on this project upgrade or removal in
> per-user mode.

- Per-user mode now prefers working with less widely used user shell
  configuration paths to avoid cluttering. For example, it will now prefer
  working with `.bash_profile` over `.bashrc`.


## Release 0.10.0
> **Caution for per-user mode**
>
> If you are a power user that heavily relies on symbolic links for custom
> fontconfig rules and use lucidglyph versions from `0.10.0` to `0.11.1`,
> please [check this](https://github.com/maximilionus/lucidglyph/issues/19) to
> avoid the possible symlinks corruption on this project upgrade or removal in
> per-user mode.

- New experimental per-user installation mode, allowing to apply all tweaks
  only for the current user. Enable by passing the `--user` (`-u`) flag.

- New tweak to fix variable fonts bold style rendering in Qt based software.
  Eliminates the incorrect rendering of bold fonts as heavy. (Reported by
  [@xalt7x](https://github.com/maximilionus/lucidglyph/issues/12#issuecomment-2822253637))

- Improved modular paths handling in main script, including support for the
  [`DESTDIR`](https://www.gnu.org/prep/standards/html_node/DESTDIR.html)
  (cherry-picked from
  [VictorQueiroz](https://github.com/VictorQueiroz/lucidglyph) fork)
  variable.


## Release 0.9.1
- Fix improperly handled installation steps.

- Improve script output.


## Release 0.9.0
Major improvements to multiple font drivers.

- Achieved completely correct rendering of emboldened `cff` driver fonts.

- Increased darkening for small fonts in `autofitter` driver.

- Enhanced visibility of different styles (regular, bold, italic) in
  `autofitter` driver.

- Main script will now print the help message if no command provided.


## Release 0.8.0
- Project has been renamed to "lucidglyph", as it now covers more than freetype
  itself (and I like how simple the new name is). Automatic updating from
  version `0.7.0` **is supported**.

- From now on, the project is licensed under GPLv3 again.

- New unsupported platform notice in the main script, which will appear on any
  attempts to run it on the non-Linux environments.

- Improved color output for main script.


## Release 0.7.0
- Project modes are now deprecated. There is no point in keeping the **full
  mode** anymore, as most of it's features are now included by default in
  **normal mode**. Passing any mode arguments to the script will now print out
  the warning message about deprecation and proceed with the **normal mode**
  installation.

- New web wrapper script added to project. Now you can install and control the
  project without having to download it manually

- Support for automatic project upgrades. Now you can install the project
  easily without having to manually deal with the previous version of it. This
  feature is only supported on versions above `0.7.0`, so upgrade to this
  release from previous versions will sadly still be manual, sorry :(

- Enhanced colored output and removed verbose information in main script.

- Environmental variables are now set in `/etc/environment` file and handled by
  PAM. The problem with using the `/etc/profile.d/` modular way, while being
  much easier to manage, causes dependency on the shell to actually source
  those values, which can be troublesome on some Linux distributions.

- Support for packaging is removed now with RHEL/Fedora (dnf) repository
  deprecated. No more updates will come to COPR repository, and it will be
  closed after Fedora 41 EOL. Deployment process became too complex, and I do
  not wish to waste my time on maintaining it all.

- Removed the ability to disable the state file through `STORE_STATE` variable
  from main script. Now, with project packaging being canceled, this feature
  lacks no purpose, as state file is required for manual installation project
  management.


## Release 0.6.0
- Secure state file load in manual management script.
> Parser will ensure that loaded values are safe and does not contain any
out-of-scope calls. The script must be run with root privileges and fully
sourcing the contents of an external file may lead to malicious behavior.


## Release 0.5.0
- New fontconfig rule to reject the usage of *Droid Sans* font family for
  Japanese and Chinese ([Issue #1](https://github.com/maximilionus/lucidglyph/issues/1)).
- Manual management script will now create special state files to store current
  installation information for further project management.
- Manual management script shortcut commands (`i`, `r`, `h`) are now deprecated
  and will be removed on `1.0.0` release.


## Release 0.4.0
- Enable `cff` driver in the **Normal** preset with new darkening values that
  reduce font distortion with this driver to a minimum. Major feature for
  vanilla **GNOME** users with **Cantarell** font.
- Stem-darkening values are now specified for all drivers (`cff`, `type1`, `t1cid`)
  in all presets for more predictive results.


## Release 0.3.0
- Project license changed to the BSD-3-Clause. I don't think it makes sense to
  use a license as restrictive as the GPL.
- Stem-darkening value increased for the min. sized fonts in "Full" preset.


## Release 0.2.3
- Stem-darkening values adjusted:
    - Improve the small-sized fonts visibility.
    - Reduced visual artifacts for medium-sized fonts.
    - Turned back on the darkening max. threshold for big-sized fonts.


## Release 0.2.2
- Minor enhancements to the installation script.


## Release 0.2.1
- Fixed problems with the lack of visual distinction between fonts of different
  weights on dark backgrounds.
- Visibility of small font sizes has been slightly improved.


## Release 0.2.0
> [!IMPORTANT]  
> When upgrading from versions `0.1.*`, be sure to uninstall the previous
> installation with its `uninstall.sh` script. Because of some incompatible
> enhancements made to the project it no longer can work with previous version
> tweaks.

- Revamped main script, everything in one place.
- Grayscale antialiasing enforcement is automated now, no manual actions
  required anymore.
- `cff` driver stem-darkening added to **full** preset.
- Enabled stem-darkening for `type1` and `t1cid` drivers.
- Stem darkening values tweaked to enhance visibility.
- Modes renamed:
    - `safe` --> `normal`.
    - `unsafe` --> `full`.
- Removed old control scripts `install.sh` and `uninstall.sh` cut from project.


## Release 0.1.1
- Improve the structure of profile.d scripts, add comment blocks describing
  actions.


## Release 0.1.0
Initial release of this project.
