{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.aerc;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  inherit (lib.meta) getExe;
  aercFilter = "${pkgs.aerc}/libexec/aerc/filters";
in
{
  options.my.aerc = {
    enable = mkEnableOption "aerc";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        bat # Preview text attachments with syntax highlighting.
        chawan # Render HTML mail in the terminal.
        dante # Provide socksify for terminal HTML renderers when needed.
        w3m # Fallback terminal HTML renderer.
      ]
      # `aba` is not available in every nixpkgs revision/platform, so keep
      # address-book support opportunistic instead of making aerc fail to eval.
      ++ lib.optionals (pkgs ? aba) [
        pkgs.aba # Address book helper for completion and contact capture.
      ];

    programs.aerc = {
      enable = true;
      extraConfig = {
        general = {
          default-menu-cmd = "${getExe pkgs.fzf}";
          pgp-provider = "gpg";
          unsafe-accounts-conf = true;
        };
        ui = {
          dirlist-tree = true;
          empty-message = "(no messages)";
          mouse-enabled = true;
          new-message-bell = true;
          timestamp-format = "2006-01-02 15:04";
          sort = "-r arrival";
          spinner = "◜,◠,◝,◞,◡,◟";
          tab-title-account = "{{.Account}} {{if .Unread}}({{.Unread}}){{end}}";
          fuzzy-complete = true;
          msglist-scroll-offset = 5;
          thread-prefix-dummy = "┬";
          thread-prefix-first-child = "┬";
          thread-prefix-folded = "+";
          thread-prefix-has-siblings = "├";
          thread-prefix-indent = "";
          thread-prefix-last-sibling = "╰";
          thread-prefix-limb = "─";
          thread-prefix-lone = " ";
          thread-prefix-orphan = "┌";
          thread-prefix-stem = "│";
          thread-prefix-tip = "";
          thread-prefix-unfolded = "";
          threading-enabled = true;
        };
        viewer = {
          pager = config.my.pager;
          header-layout = "From|To,Cc|Bcc,Date,Subject,DKIM+|SPF+|DMARC+";
        };
        filters = {
          "text/plain" = "${aercFilter}/colorize";
          "text/calendar" = "${getExe pkgs.gawk} -f ${aercFilter}/calendar";
          "text/html" =
            "!${getExe pkgs.chawan} --type text/html --opt display.image-mode=kitty --opt display.columns=100 --opt display.force-columns=true";
          "message/delivery-status" = "${aercFilter}/colorize";
          "message/rfc822" = "${aercFilter}/colorize";
          "application/x-sh" = "${getExe pkgs.bat} -fP -l sh";
        };
        compose = {
          inherit (config.my) editor;
        }
        // lib.optionalAttrs (pkgs ? aba) {
          address-book-cmd = "${getExe pkgs.aba} ls \"%s\"";
        };
        templates = {
          new-message = "new_message";
          quoted-reply = "quoted_reply";
          forwards = "forward_as_body";
        };
      };
      templates = {
        new_message = ''
          X-Mailer: aerc {{version}}
          {{- with .Signature }}

          {{.}}
          {{- end -}}
        '';

        quoted_reply = ''
          X-Mailer: aerc {{version}}

          On {{dateFormat (.OriginalDate | toLocal) "2006-01-02 15:04 MST"}}, {{.OriginalFrom | names | join ", "}} wrote:
          {{ if eq .OriginalMIMEType "text/html" -}}
          {{- exec `html` .OriginalText | trimSignature | quote -}}
          {{- else -}}
          {{- trimSignature .OriginalText | quote -}}
          {{- end}}
          {{- with .Signature }}

          {{.}}
          {{- end }}
        '';

        forward_as_body = ''
          X-Mailer: aerc {{version}}

          Forwarded message from {{.OriginalFrom | names | join ", "}} on {{dateFormat .OriginalDate "2006-01-02 15:04"}}:
          {{.OriginalText}}
          {{- with .Signature }}

          {{.}}
          {{- end }}
        '';
      };
      extraBinds = with osConfig.dot.keyboard.keys; {
        global = {
          "<C-p>" = ":prev-tab<Enter>";
          "<C-n>" = ":next-tab<Enter>";
          "<C-t>" = ":term<Enter>";
          "?" = ":help keys<Enter>";
        };
        messages = {
          q = ":quit<Enter>";

          "${j}" = ":next<Enter>";
          "<Down>" = ":next<Enter>";
          "<C-d>" = ":next 50%<Enter>";
          "<C-f>" = ":next 100%<Enter>";
          "<PgDn>" = ":next 100%<Enter>";

          "${k}" = ":prev<Enter>";
          "<Up>" = ":prev<Enter>";
          "<C-u>" = ":prev 50%<Enter>";
          "<C-b>" = ":prev 100%<Enter>";
          "<PgUp>" = ":prev 100%<Enter>";
          g = ":select 0<Enter>";
          G = ":select -1<Enter>";

          "${J}" = ":next-folder<Enter>";
          "${K}" = ":prev-folder<Enter>";
          "${H}" = ":collapse-folder<Enter>";
          "${L}" = ":expand-folder<Enter>";

          v = ":mark -t<Enter>";
          V = ":mark -v<Enter>";

          T = ":toggle-threads<Enter>";

          "<Enter>" = ":view<Enter>";
          d = ":prompt 'Really delete this message?' 'delete-message'<Enter>";
          D = ":move Trash<Enter>";
          A = ":archive flat<Enter>";

          C = ":compose<Enter>";

          rr = ":reply -a<Enter>";
          rq = ":reply -aq<Enter>";
          Rr = ":reply<Enter>";
          Rq = ":reply -q<Enter>";

          c = ":cf<space>";
          "$" = ":term<space>";
          "!" = ":term<space>";
          "|" = ":pipe<space>";

          "/" = ":search<space>-a<space>";
          "\\" = ":filter<space>";
          "${n}" = ":next-result<Enter>";
          "${N}" = ":prev-result<Enter>";
          "<Esc>" = ":clear<Enter>";
        };

        "messages:folder=Drafts" = {
          "<Enter>" = ":recall<Enter>";
        };

        view = {
          "/" = ":toggle-key-passthrough<Enter>/";
          q = ":close<Enter>";
          O = ":open<Enter>";
          S = ":save<space>";
          "|" = ":pipe<space>";
          D = ":move Trash<Enter>";
          A = ":archive flat<Enter>";

          "<C-l>" = ":open-link<space>";

          f = ":forward<Enter>";
          rr = ":reply -a<Enter>";
          rq = ":reply -aq<Enter>";
          Rr = ":reply<Enter>";
          Rq = ":reply -q<Enter>";

          "${H}" = ":toggle-headers<Enter>";
          "<C-${k}>" = ":prev-part<Enter>";
          "<C-${j}>" = ":next-part<Enter>";
          "${J}" = ":next<Enter>";
          "${K}" = ":prev<Enter>";
        }
        // lib.optionalAttrs (pkgs ? aba) {
          aa = ":pipe -m ${getExe pkgs.aba} parse --all<Enter>";
        };

        "view::passthrough" = {
          "$noinherit" = "true";
          "$ex" = "<C-x>";
          "<Esc>" = ":toggle-key-passthrough<Enter>";
        };

        compose = {
          "$noinherit" = "true";
          "$ex" = "<C-x>";
          "<C-${k}>" = ":prev-field<Enter>";
          "<C-${j}>" = ":next-field<Enter>";
          "<A-p>" = ":switch-account -p<Enter>";
          "<A-n>" = ":switch-account -n<Enter>";
          "<tab>" = ":next-field<Enter>";
          "<C-p>" = ":prev-tab<Enter>";
          "<C-n>" = ":next-tab<Enter>";
        };

        "compose::editor" = {
          "$noinherit" = "true";
          "$ex" = "<C-x>";
          "<C-${k}>" = ":prev-field<Enter>";
          "<C-${j}>" = ":next-field<Enter>";
          "<C-p>" = ":prev-tab<Enter>";
          "<C-n>" = ":next-tab<Enter>";
        };

        "compose::review" = {
          y = ":send<Enter>";
          "${n}" = ":abort<Enter>";
          p = ":postpone<Enter>";
          q = ":choose -o d discard abort -o p postpone postpone<Enter>";
          "${e}" = ":edit<Enter>";
          a = ":attach<space>";
          d = ":detach<space>";
        };

        terminal = {
          "$noinherit" = "true";
          "$ex" = "<C-x>";
          "<C-p>" = ":prev-tab<Enter>";
          "<C-n>" = ":next-tab<Enter>";
        };
      };
    };
  };
}
