# Research: local-folder selection in a locally-run Shiny app

Ticket: [Which local-folder-selection mechanism fits a Shiny app](11-folder-picker-mechanism.md)

## Options surveyed

**1. `shinyFiles::shinyDirButton()` / `shinyDirChoose()`.** Purpose-built
for exactly this: a Shiny widget that lets the user browse the *server's*
filesystem — which, since this app runs entirely on the technician's own
machine, is their own filesystem. Renders as an in-page breadcrumb/tree
file browser (not a native OS dialog). Cross-platform (macOS/Linux/
Windows), actively maintained (CRAN, last updated May 2026, by Thomas Lin
Pedersen — a well-established Shiny-ecosystem maintainer). Requires
declaring allowed "roots" up front (e.g. the user's home directory) — a
one-line security configuration, not a real friction point. This is the
standard, most-reached-for solution for this exact problem in the R/Shiny
ecosystem.
Sources: [CRAN page](https://cran.r-project.org/package=shinyFiles), [GitHub](https://github.com/thomasp85/shinyFiles)

**2. HTML5 `webkitdirectory` file input.** Looks like a directory picker
but is not one in effect — selecting a folder this way still uploads every
file inside it through the browser's normal file-upload mechanism.
**Disqualified**: this is exactly the per-file browser-upload behavior
already ruled out for large BAM batches in
[BAM input mechanism](03-bam-input-mechanism.md).

**3. Plain text path input + validation.** Simplest possible: a
`textInput` where the user pastes an absolute path, checked with
`dir.exists()`. No extra dependency. Works everywhere R runs. Weaker UX
for a non-technical audience — they need to already have an absolute path
in hand (via Finder "Copy as Pathname", Explorer's address bar, or a
terminal), which is exactly the kind of friction this app is meant to
remove.

**4. `rstudioapi::selectDirectory()`.** Native folder dialog, but only
works when the Shiny app happens to be running inside RStudio
(`rstudioapi::isAvailable()`). A field technician launching the app via a
plain `runShinyHaplotPrepApp()`-style call in a bare R console (the
expected launch path, consistent with today's `runShinyHaplot()`) would
not have RStudio running at all. Too fragile as the primary mechanism.

**5. `tcltk::tk_choose.dir()`.** A genuine native OS "Browse for Folder"
dialog — cross-platform, and arguably the *most* familiar pattern for a
non-technical user (it's the same dialog every desktop app uses). Simple,
one-line call. Two real caveats: (a) on macOS it requires X11/Tcl-Tk to be
present — the existing README already tells Mac users to install XQuartz
for other reasons, so this isn't a new dependency burden for this
audience; but (b) native dialogs launched from a Shiny app's R process can
open *behind* the browser window depending on window-manager focus
behavior, which for a non-technical user looks indistinguishable from the
app having frozen — a real usability risk specifically for this audience.

## Recommendation

**`shinyFiles`.** It's purpose-built for this exact scenario, is the
standard choice in the R/Shiny ecosystem for local-app folder browsing,
stays fully inside the browser window (no focus/z-order risk, unlike
`tcltk`), and needs no RStudio (unlike `rstudioapi`). The one-time "roots"
configuration (e.g. the user's home directory as the allowed root) is a
minor, one-line setup cost, not a per-use friction point.
