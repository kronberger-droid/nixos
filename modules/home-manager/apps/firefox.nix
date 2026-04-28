{config, pkgs, inputs, ...}: let
  addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
in {
  programs.firefox = {
    enable = true;
    # Pin to the legacy profile path. With `home.stateVersion = "26.05"` HM's
    # default is `${xdg.configHome}/mozilla/firefox`, but nixpkgs' firefox
    # wrapper still exports `MOZ_LEGACY_PROFILES=1`, so the browser reads from
    # `~/.mozilla/firefox`. Without this override the declarative profile is
    # written to a directory firefox never opens.
    configPath = ".mozilla/firefox";

    profiles.default = {
      extensions.packages = with addons; [
        ublock-origin
        darkreader
        privacy-badger
      ];

      search = {
        default = "Brave Search";
        force = true;
        engines = {
          "Brave Search" = {
            urls = [{template = "https://search.brave.com/search?q={searchTerms}";}];
            definedAliases = ["@b"];
          };
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                {name = "query"; value = "{searchTerms}";}
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@np"];
          };
          "MyNixOS" = {
            urls = [{template = "https://mynixos.com/search?q={searchTerms}";}];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@mn"];
          };
          "bing".metaData.hidden = true;
          "ebay".metaData.hidden = true;
          "amazondotcom-us".metaData.hidden = true;
          "wikipedia".metaData.hidden = true;
          "google".metaData.hidden = true;
        };
      };

      settings = {
        # Auto-enable extensions installed by Nix
        "extensions.autoDisableScopes" = 0;

        # Dark mode: tell websites to use dark color scheme
        "layout.css.prefers-color-scheme.content-override" = 0;
        "ui.systemUsesDarkTheme" = 1;

        # Enable userChrome.css and userContent.css
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "svg.context-properties.content.enabled" = true;
        # ==================== PERFORMANCE ====================
        # Hardware acceleration
        "gfx.webrender.all" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "media.webrtc.camera.allow-pipewire" = true;
        "layers.acceleration.force-enabled" = true;

        # Wayland support
        "widget.use-xdg-desktop-portal.file-picker" = 1;

        # Memory and cache
        "browser.cache.memory.enable" = true;
        "browser.cache.memory.capacity" = 524288; # 512MB
        "browser.sessionhistory.max_total_viewers" = 4;
        "browser.tabs.unloadOnLowMemory" = true;
        "browser.low_commit_space_threshold_mb" = 1024;

        # Warm-start: defer tab work until each tab is actually focused.
        # Makes window restore paint instantly; tabs load on click.
        "browser.sessionstore.restore_on_demand" = true;
        "browser.sessionstore.restore_tabs_lazily" = true;
        "browser.sessionstore.restore_pinned_tabs_on_demand" = true;
        # Show a blank window immediately instead of waiting for XUL.
        "browser.startup.blankWindow" = true;

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

      # Custom CSS to hide window controls
      userChrome = ''
        /* Hide close button */
        .titlebar-buttonbox-container > .titlebar-buttonbox > .titlebar-close {
          display: none !important;
        }
      '';
    };
  };
}
