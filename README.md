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
You can easily install and upgrade with web wrapper:
```sh
bash <(curl -s -L https://maximilionus.github.io/lucidglyph/wrapper.sh) \
    install
```

Version can also be selected by declaring the `VERSION` environmental variable:
```sh
VERSION="0.2.0" bash <(curl -s -L https://maximilionus.github.io/lucidglyph/wrapper.sh) \
    [COMMAND]
```


### Install
1. Download the latest release
   [here](https://github.com/maximilionus/lucidglyph/releases/latest)
   *(download "Source code")* and unpack it to any user available location.
2. Open the terminal in the unpacked directory.
3. Run the command below, root required:
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
**Versions above `0.7.0`:**  
Follow the same steps from "Install" section. If there's a supported version of
the project already installed, the "install" command will prompt the user to
allow the upgrade.

**Versions below `0.7.0`:**  
1. Follow the "Remove" section steps using the script exactly the version of
   the project that is currently installed on the system.
2. Now you can install the new version by simply following the "Install"
   section.


## Details
- Environmental configurations:
   - Stem-darkening *(fonts emboldening)* with custom values for `autofitter`,
   `type1`, `t1cid` and `cff` drivers.
   > This feature improves visibility of the medium and small-sized fonts.
   > Especially helpful for the LowPPI displays.

- Rules for fontconfig:
   - Enforce grayscale antialiasing (disable sub-pixel).
   > Grayscale antialiasing should be enforced in the system to make the
   > stem-darkening work properly.

   - Reject usage of *Droid Sans* family for Japanese and Chinese, force the
     environment to use other fonts.
   > Stem-darkening does not work well with these typefaces, causing characters
   > over-emboldening.


## Notes
### GNOME DE
#### Antialiasing
While GNOME does use the grayscale antialiasing method by default, there are a
few Linux distributions that change this setting to the subpixel method, making
the font rendering appear incorrect after the tweaks from this project. This
issue is [already
tracked](https://github.com/maximilionus/lucidglyph/issues/7), but
manual user intervention is still required for now.

To see if your environment uses the subpixel font antialiasing you can check
the output of the command below:

```sh
$ gsettings get org.gnome.desktop.interface font-antialiasing
'rgba'
```

If you get the same output as above - you are using the subpixel antialiasing,
and switching to grayscale antialiasing can be done by executing the next
command:

```sh
gsettings set org.gnome.desktop.interface font-antialiasing grayscale
```

To revert the changes:

```sh
gsettings reset org.gnome.desktop.interface font-antialiasing
```
