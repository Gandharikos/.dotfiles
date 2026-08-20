{ lib, pkgs, ... }:
{
  # Helper to generate the kanata configuration string based on the platform.
  mkKanataConfig =
    {
      isLinux ? pkgs.stdenv.hostPlatform.isLinux,
      isDarwin ? pkgs.stdenv.hostPlatform.isDarwin,
    }:
    let
      # Define the bottom row based on the OS (6 keys each)
      # Linux/PC: lctl lmet lalt           spc            ralt rctl
      # Darwin/Mac: lctl lalt lmet           spc            rmet ralt
      srcBottomRow =
        if isLinux then
          "lctl lmet lalt           spc            ralt rmet"
        else
          "lctl lalt lmet           spc            rmet ralt";

      # Base layer bottom row (the remap):
      # Linux: swap lctl and lmet, map ralt to rmet
      # Darwin: lctl lmet lalt (swap for consistency if desired, but Mac already uses Cmd for shortcuts)
      # User previously had: lmet lctl lalt spc rmet for Linux.
      baseBottomRow =
        if isLinux then
          "lmet lctl lalt           spc            rmet ralt"
        else
          "lctl lmet lalt           spc            @hyper rmet";

      # Print Screen key varies by platform in kanata.
      prtScKey = if isLinux then "prtsc" else "f13";
    in
    ''
      ;; Generated Kanata configuration
        (defcfg
          process-unmapped-keys yes
          concurrent-tap-hold yes
          ${lib.optionalString isLinux ''
            linux-continue-if-no-devs-found yes
          ''}
          ${lib.optionalString isDarwin ''
            macos-dev-names-include ("Apple Internal Keyboard / Trackpad")
          ''}
        )

      (defsrc
        tab  q    w    e    r    t    y    u    i    o    p bspc
        caps a    s    d    f    g    h    j    k    l    ;    '    ret
        lsft z    x    c    v    b    n    m    ,    .    / rsft
        ${srcBottomRow}
      )

      ;; vars
      (defvar
        tapping-term 150
        quick-tap 125
        oneshot-timeout 1000
        chord-timeout 30
      )

      (defalias
        caps_word (caps-word 1000)
        sft (one-shot $oneshot-timeout rsft)
        escctrl (tap-hold-press $tapping-term $quick-tap esc lctl)
        smart_sft (tap-dance 200 (@sft @caps_word))
        lp (fork S-9 S-, (lsft rsft))
        rp (fork S-0 S-. (lsft rsft))
        comma (fork , (unshift ;) (lsft rsft))
        dot (fork . S-; (lsft rsft))
        tab-mod (tap-hold-press $tapping-term $quick-tap tab (layer-while-held tab_layer))
        ;; German umlauts with shift support
        ä (fork (unicode ä) (unicode Ä) (lsft rsft))
        ö (fork (unicode ö) (unicode Ö) (lsft rsft))
        ü (fork (unicode ü) (unicode Ü) (lsft rsft))
        ß (fork (unicode ß) (unicode ẞ) (lsft rsft))
        ${lib.optionalString isDarwin ''
          hyper (multi lctl lalt lmet)
        ''}
      )

      (defchordsv2
        (u i) @lp  $chord-timeout all-released ()
        (i o) @rp  $chord-timeout all-released ()
        (w e) [    $chord-timeout all-released ()
        (e r) ]    $chord-timeout all-released ()
        (m ,) S--  $chord-timeout all-released ()
        (, .) =    $chord-timeout all-released ()
        (j k) -    $chord-timeout all-released ()
        (k l) S-=  $chord-timeout all-released ()
        (q a) S-1  $chord-timeout all-released ()
        (w s) S-2  $chord-timeout all-released ()
        (e d) S-3  $chord-timeout all-released ()
        (r f) S-4  $chord-timeout all-released ()
        (t g) S-5  $chord-timeout all-released ()
        (y h) S-6  $chord-timeout all-released ()
        (u j) S-7  $chord-timeout all-released ()
        (i k) S-8  $chord-timeout all-released ()
        (o l) grv  $chord-timeout all-released ()
        (p ;) \    $chord-timeout all-released ()
        (q w) esc  $chord-timeout all-released ()
        (a s) tab  $chord-timeout all-released ()
        (l ;) ret  $chord-timeout all-released ()
        (o p) bspc $chord-timeout all-released ()
        (s d) S-7  $chord-timeout all-released ()
        (d f) S-\  $chord-timeout all-released ()
        (x c) \    $chord-timeout all-released ()
        (c v) S-1  $chord-timeout all-released ()
      )

      (deflayer base
        @tab-mod   _    _    _    _    _    _    _    _    _    _    _
        @escctrl   _    _    _    _    _    _    _    _    _    '    ;    _
        _          _    _    _    _    _    _    _    @comma @dot _ _
        ${baseBottomRow}
      )

      (deflayer tab_layer
        _    C-f12 _    _    _    _    _    @ü   _    @ö    ${prtScKey} del
        _    @ä    @ß   _    _    _    left down up   right _    _    _
        _    _     _    _    _    _    _    _    _    _     _    _
        _    _    _              _              _    _
      )
    '';
}
