## About
Tuning the Linux font rendering stack for a more visually pleasing output.

Includes tweaks for FreeType, fontconfig, and other components. See
[Overall](#overall) with [Details](#details) for more information, and
[Notes](#notes) for the list of known issues and possible mitigations.

Visual comparison is available on the project's
[wiki page](https://github.com/maximilionus/lucidglyph/wiki/Comparison).

> Note that this project is just a collection of tweaks that reflect the
> author's vision on how font rendering should look like.
>
> Due to the nature of the rendering stack features used in this project being
> still experimental or even completely not supported by most of the Linux
> desktop environments (like proper gamma correction and blending), correct
> rendering cannot be guaranteed in some cases.

> Previously known as **freetype-envision**

### Overall
- Improves visibility of the medium and small-sized fonts.
- Adjusts the font environment to support new experimental features of the font
  rendering stack.
- Keeps the system components and font list intact. No additions or removals,
  only rendering tweaks.


## Usage
### Install
1. Download the latest release from
   [here](https://github.com/maximilionus/lucidglyph/releases/latest)
   _(Assets - Source code)_ and unpack it.
2. Open the terminal in the unpacked directory.
3. Execute the command below with elevated permissions:

   ```sh
   sudo ./lucidglyph.sh install
   ```

   > See [User mode](#user-mode) for per-user installation
4. Reboot to apply the changes.

### Remove
1. Execute the same script from [Install](#install) section above with elevated
   permissions:

   ```sh
   sudo ./lucidglyph.sh remove
   ```
2. Reboot to apply the changes.

### Upgrade
- Follow the steps from the [Install](#install) section above and the script will
request user confirmation to allow the upgrade.

### User Mode
> **Warning**
>
> Experimental feature, expect things not to work as intended. User feedback is
> greatly appreciated.

> **Caution**
>
> If you are a power user that heavily relies on symbolic links for custom
> fontconfig rules and use lucidglyph versions from `0.10.0` to `0.11.1`,
> please [check this](https://github.com/maximilionus/lucidglyph/issues/19) to
> avoid the possible symlinks corruption on this project upgrade or removal in
> per-user mode.
>
> This issue has been resolved and mitigated in `0.12.0` release. No manual
> intervention is required.

User mode allows the project to be installed for the current user only, without
any need for elevated privileges (sudo) or system-wide changes.

To activate this mode, pass the `--user` (or `-u`) argument on main script run:
```sh
./lucidglyph.sh --user [COMMAND]
```


## Notes
### Chromium
Starting from version 133 (February 2025), Chromium now uses the self-written
replacement for FreeType called Fontations, as a new font system, with Skrifa
library being responsible for rendering in it.

Skrifa currently lacks any stem-darkening support[^1], which is one of the
crucial parts of the lucidglyph project _(see [Details](#details))_.

In Chromium `139.0.7258` the flag that was previously used to turn back the
FreeType rendering backend was completely removed[^2] with one of the
contributors stating that they _"...no longer intend to carry the FreeType
support."_[^3].

There's nothing more I can do here until the Fontations stack matures enough to
support the required functionality other than suggest switching your browser of
choice to any non-chromium-based one or make use of scaling and zoom features.

For the software that is still based on older Chromium versions, you can switch
to FreeType rendering in several ways:

**Command Line**  
Launch the software with the `--disable-features` flag:

```sh
$ <software> --disable-features=FontationsFontBackend
```

**Manual**  
1. Open this link: `chrome://flags/#enable-fontations-backend`
2. Set the flag to `Disabled`.
3. Restart the browser by closing the window.

You can track the detailed progress on this issue
[here](https://github.com/maximilionus/lucidglyph/issues/18).


### GNOME
While GNOME does use the grayscale anti-aliasing method by default, there are a
few Linux distributions that change this setting to the subpixel method, making
the font rendering appear incorrect after the tweaks from this project.

This issue is being tracked, but still requires manual user intervention.

[Check this report](https://github.com/maximilionus/lucidglyph/issues/7) to
see if you are being affected by this issue and get a temporary solution.


### KDE Plasma
By default, vanilla Plasma desktop environment does follow the fontconfig
rules, including the anti-aliasing settings, but in some cases this behavior
gets overwritten, presumably by above-level distro-specific configurations.
This causes improper font rendering due to misconfigured anti-aliasing
parameters.

This issue is being tracked, but still requires manual user intervention.

[Check this report](https://github.com/maximilionus/lucidglyph/issues/12) to
see if you are being affected by this issue and get a temporary solution.


### Kitty Terminal
Rendering dark fonts on light backgrounds _(light themes)_ in Kitty appears to
discard most of the applied emboldening _(stem-darkening, see
[Details](#details))_, making the fonts look thin again.

To remedy this issue, append this modified
[`text_composition_strategy`](https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.text_composition_strategy)
parameter to Kitty's user configuration file:

```conf
text_composition_strategy 1.7 0
```


## Details
- Environment configurations:
   - Stem-darkening (fonts emboldening) for `autofitter` (including custom
     darkening values), `type1`, `t1cid` and `cff` drivers. This feature
     improves visibility of the medium and small-sized fonts. Especially
     helpful on the low pixel density (LowPPI) outputs.
     [More information](https://freetype.org/freetype2/docs/hinting/text-rendering-general.html)
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


[^1]: https://github.com/googlefonts/fontations/issues/1407
[^2]: https://chromiumdash.appspot.com/commit/2fc1ae192a45eb6f1716e232dd1626317f8d299e
[^3]: https://github.com/googlefonts/fontations/pull/1496#issuecomment-3004330901
