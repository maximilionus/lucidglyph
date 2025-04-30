## About
Carefully tuned adjustments designed to improve font rendering on Linux,
including tweaks for freetype, fontconfig and other components.

Visual comparison is available on the project's
[wiki page](https://github.com/maximilionus/lucidglyph/wiki/Comparison).

> [!NOTE]  
> Previously known as **freetype-envision**
>
> As the project grew from simple tweaks to freetype and started to cover many
> additional components of linux environments, the decision was made to rename
> it to something more relevant.


### Overall
- Improve the visibility of medium and small-sized fonts.
- Prepare the font environment for experimental freetype features.


## Usage
### Install
1. Download the latest release
   [here](https://github.com/maximilionus/lucidglyph/releases/latest)
   *(download "Source code")* and unpack it to any user available location.
2. Open the terminal in the unpacked directory.
3. Run the command below, root required:
   > It is also possible to install the project only for the current user,
   > without any need for system-wide access.
   > See [Per-User Mode](#per-user-mode).

   ```sh
   sudo ./lucidglyph.sh install
   ```
4. Reboot to apply the changes.

### Remove
1. Run the command below, root required:
   ```sh
   sudo ./lucidglyph.sh remove
   ```
2. Reboot to apply the changes.

### Upgrade
**Versions after `0.7.0`:**  
Follow the same steps from "Install" section. If there's a supported version of
the project already installed, the "install" command will prompt the user to
allow the upgrade.

**Versions before `0.7.0`:**  
1. Follow the "Remove" section steps using the script exactly the version of
   the project that is currently installed on the system.
2. Now you can install the new version by simply following the "Install"
   section.

### Per-User Mode
> [!NOTE]  
> This feature is only available starting from `0.10.0` version.

> [!IMPORTANT]  
> Experimental feature, expect things not to work as intended. User feedback is
> greatly appreciated.

Per-user mode allows the project to be installed only for the current user,
without any need for elevated permissions (sudo) or system-wide changes. This
is very handy for immutable file systems where any system-wide changes are
forbidden or overwritten on upgrade.

To activate this mode, pass the `--user` (or `-u`) argument on main script run:
```sh
./lucidglyph.sh --user [COMMAND]
```


## Notes
### GNOME
While GNOME does use the grayscale anti-aliasing method by default, there are a
few Linux distributions that change this setting to the subpixel method, making
the font rendering appear incorrect after the tweaks from this project.

This issue is already being tracked, but manual user intervention is still
required for now.

To see if you are being affected by this issue and get a temporary solution,
[check this report](https://github.com/maximilionus/lucidglyph/issues/7).


### KDE Plasma
By default, vanilla KDE Plasma desktop environment does follow the fontconfig
rules, including the anti-aliasing settings, but in some cases this behavior
gets overwritten, presumably by above-level distro-specific configurations.
This causes improper font rendering due to misconfigured anti-aliasing
parameters.

This issue is already being tracked, but manual user intervention is still
required for now.

To see if you are being affected by this issue and get a temporary solution,
[check this report](https://github.com/maximilionus/lucidglyph/issues/12).


## Details
- Environmental configurations:
   - Stem-darkening *(fonts emboldening)* with custom values for `autofitter`,
     `type1`, `t1cid` and `cff` drivers. This feature improves visibility of
     the medium and small-sized fonts. Especially helpful for the LowPPI
     displays. More
     [information](https://freetype.org/freetype2/docs/hinting/text-rendering-general.html)
     and
     [usage documentation](https://freetype.org/freetype2/docs/reference/ft2-properties.html#no-stem-darkening).

   - Disable synthesized bold fonts in Qt-based software. There is an issue
     that causes bold glyphs to appear heavy in variable fonts. More
     information:
     Fedora reports (
     [#1](https://bugzilla.redhat.com/show_bug.cgi?id=2179854),
     [#2](https://pagure.io/fedora-kde/SIG/issue/461)
     ),
     [Qt report](https://bugreports.qt.io/browse/QTBUG-112136).

- Rules for fontconfig:
   - Enforce grayscale anti-aliasing (disable sub-pixel). Grayscale
     anti-aliasing should be enforced in the system to make the stem-darkening
     from the above work properly.

   - Reject usage of "Droid Sans" family for Japanese and Chinese characters
     and force the environment to use other fonts. Stem-darkening does not work
     well with this typeface, causing characters over-emboldening.
