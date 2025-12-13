{
  pkgs,
  config,
  ...
}: let
  c = config.scheme;
in {
  programs.firefox = {
    enable = true;

    profiles.default = {
      settings = {
        # Enable userChrome.css and userContent.css
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "svg.context-properties.content.enabled" = true;
        # ==================== PERFORMANCE ====================
        # Hardware acceleration
        "gfx.webrender.all" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "layers.acceleration.force-enabled" = true;

        # Wayland support
        "widget.use-xdg-desktop-portal.file-picker" = 1;

        # Memory and cache
        "browser.cache.memory.enable" = true;
        "browser.cache.memory.capacity" = 524288; # 512MB
        "browser.sessionhistory.max_total_viewers" = 4;
        "browser.tabs.unloadOnLowMemory" = true;
        "browser.low_commit_space_threshold_mb" = 1024;

        # UI performance
        "browser.tabs.animate" = false;
        "browser.fullscreen.animate" = false;
        "toolkit.cosmeticAnimations.enabled" = false;
        "browser.startup.preXulSkeletonUI" = false;

        # Smooth scrolling
        "general.smoothScroll.msdPhysics.enabled" = true;
        "mousewheel.min_line_scroll_amount" = 40;

        # Network performance (balanced with privacy)
        "network.predictor.enabled" = true;
        "browser.sessionstore.interval" = 30000; # Save session every 30s instead of 15s

        # ==================== USER INTERFACE ====================
        # Homepage and new tab
        "browser.startup.homepage" = "chrome://browser/content/blanktab.html";
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;

        # Disable recommendations and suggestions
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;

        # Sidebar
        "sidebar.verticalTabs" = true;
        "sidebar.position_start" = false;
        "sidebar.revamp" = true;

        # Bookmarks
        "browser.bookmarks.showMobileBookmarks" = false;
        "browser.toolbars.bookmarks.showOtherBookmarks" = false;

        # Dark theme
        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
        "layout.css.prefers-color-scheme.content-override" = 0;
        "browser.theme.content-theme" = 0;
        "browser.theme.toolbar-theme" = 0;

        # ==================== PRIVACY & SECURITY ====================
        # Content blocking
        "browser.contentblocking.category" = "custom";
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.fingerprintingProtection" = true;
        "privacy.query_stripping.enabled" = true;
        "privacy.query_stripping.enabled.pbmode" = true;
        "privacy.annotate_channels.strict_list.enabled" = true;

        # Network privacy (Note: these reduce performance but increase privacy)
        "network.dns.disablePrefetch" = true;
        "network.http.speculative-parallel-limit" = 0;
        "network.prefetch-next" = false;

        # Bounce tracking protection
        "privacy.bounceTrackingProtection.mode" = 1;

        # Clear form data on shutdown
        "privacy.clearOnShutdown_v2.formdata" = true;

        # Enhanced tracking protection allowlists
        "privacy.trackingprotection.allow_list.baseline.enabled" = false;
        "privacy.trackingprotection.allow_list.convenience.enabled" = false;
        "privacy.trackingprotection.consentmanager.skip.pbmode.enabled" = false;

        # ==================== FEATURES ====================
        # DRM content (for streaming)
        "media.eme.enabled" = true;

        # Picture-in-Picture
        "extensions.pictureinpicture.enable_picture_in_picture_overrides" = true;

        # Autofill
        "dom.forms.autocomplete.formautofill" = true;

        # PDF
        "pdfjs.enableAltText" = true;
        "pdfjs.enableAltTextForEnglish" = true;

        # Translations
        "browser.translations.neverTranslateLanguages" = "de";

        # Type-ahead find
        "accessibility.typeaheadfind.flashBar" = 0;
      };

      userChrome = ''
        /* Base16 Theme - UI Elements */
        :root {
          --base00: #${c.base00}; /* Default Background */
          --base01: #${c.base01}; /* Lighter Background */
          --base02: #${c.base02}; /* Selection Background */
          --base03: #${c.base03}; /* Comments */
          --base04: #${c.base04}; /* Dark Foreground */
          --base05: #${c.base05}; /* Default Foreground */
          --base06: #${c.base06}; /* Light Foreground */
          --base07: #${c.base07}; /* Light Background */
          --base08: #${c.base08}; /* Red */
          --base09: #${c.base09}; /* Orange */
          --base0A: #${c.base0A}; /* Yellow */
          --base0B: #${c.base0B}; /* Green */
          --base0C: #${c.base0C}; /* Cyan */
          --base0D: #${c.base0D}; /* Blue */
          --base0E: #${c.base0E}; /* Magenta */
          --base0F: #${c.base0F}; /* Brown */
        }

        /* Remove all rounded corners */
        * {
          border-radius: 0 !important;
        }

        /* Main browser chrome */
        #navigator-toolbox {
          background-color: var(--base00) !important;
          border-color: var(--base01) !important;
        }

        /* Toolbars */
        toolbar {
          background-color: var(--base00) !important;
          color: var(--base05) !important;
        }

        /* URL bar */
        #urlbar {
          background-color: var(--base01) !important;
          color: var(--base05) !important;
          border: 1px solid var(--base02) !important;
        }

        #urlbar-background {
          background-color: var(--base01) !important;
          border: none !important;
          box-shadow: none !important;
        }

        #urlbar[focused="true"] {
          background-color: var(--base02) !important;
          border-color: var(--base0D) !important;
        }

        #urlbar[focused="true"] #urlbar-background {
          background-color: var(--base02) !important;
        }

        /* Search bar */
        #searchbar {
          background-color: var(--base01) !important;
          color: var(--base05) !important;
        }

        /* Tabs */
        .tabbrowser-tab {
          color: var(--base04) !important;
        }

        .tabbrowser-tab[selected] {
          background-color: var(--base01) !important;
          color: var(--base05) !important;
        }

        .tab-background {
          background-color: var(--base00) !important;
          border-color: var(--base01) !important;
        }

        .tab-background[selected] {
          background-color: var(--base01) !important;
          border-color: var(--base02) !important;
        }

        /* Sidebar */
        #sidebar-box {
          background-color: var(--base00) !important;
          border-color: var(--base01) !important;
          max-width: 300px !important;
        }

        #sidebar-header {
          background-color: var(--base00) !important;
          color: var(--base05) !important;
          border-color: var(--base01) !important;
        }

        #sidebar-main {
          background-color: var(--base00) !important;
          color: var(--base05) !important;
        }

        /* Sidebar splitter */
        #sidebar-splitter {
          background-color: var(--base01) !important;
          border-color: var(--base02) !important;
          width: 1px !important;
        }

        /* Menus and panels */
        menupopup,
        panel {
          background-color: var(--base01) !important;
          color: var(--base05) !important;
          border-color: var(--base02) !important;
        }

        menuitem:hover,
        menu:hover {
          background-color: var(--base02) !important;
          color: var(--base06) !important;
        }

        /* Context menus */
        #contentAreaContextMenu {
          background-color: var(--base01) !important;
          color: var(--base05) !important;
        }

        /* Buttons */
        toolbarbutton {
          color: var(--base05) !important;
        }

        toolbarbutton:hover {
          background-color: var(--base01) !important;
        }

        toolbarbutton:active,
        toolbarbutton[open] {
          background-color: var(--base02) !important;
        }

        /* Accent colors for active elements */
        .urlbarView-row[selected],
        .urlbarView-row:hover {
          background-color: var(--base02) !important;
        }

        /* Bookmarks bar */
        #PersonalToolbar {
          background-color: var(--base00) !important;
        }

        .bookmark-item {
          color: var(--base05) !important;
        }

        .bookmark-item:hover {
          background-color: var(--base01) !important;
        }

        /* Findbar */
        .findbar-textbox {
          background-color: var(--base01) !important;
          color: var(--base05) !important;
          border-color: var(--base02) !important;
        }
      '';

      userContent = ''
        /* Base16 Theme - Web Content */
        @-moz-document url-prefix(about:) {
          :root {
            --base00: #${c.base00};
            --base01: #${c.base01};
            --base02: #${c.base02};
            --base03: #${c.base03};
            --base04: #${c.base04};
            --base05: #${c.base05};
            --base06: #${c.base06};
            --base07: #${c.base07};
            --base08: #${c.base08};
            --base09: #${c.base09};
            --base0A: #${c.base0A};
            --base0B: #${c.base0B};
            --base0C: #${c.base0C};
            --base0D: #${c.base0D};
            --base0E: #${c.base0E};
            --base0F: #${c.base0F};
          }

          /* Apply to about: pages */
          body {
            background-color: var(--base00) !important;
            color: var(--base05) !important;
          }

          a {
            color: var(--base0D) !important;
          }

          a:visited {
            color: var(--base0E) !important;
          }

          a:hover {
            color: var(--base0C) !important;
          }

          input,
          textarea,
          select {
            background-color: var(--base01) !important;
            color: var(--base05) !important;
            border-color: var(--base02) !important;
          }

          button {
            background-color: var(--base02) !important;
            color: var(--base05) !important;
            border-color: var(--base03) !important;
          }

          button:hover {
            background-color: var(--base03) !important;
          }
        }
      '';
    };
  };
}
