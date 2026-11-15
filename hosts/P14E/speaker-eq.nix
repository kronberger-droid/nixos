# Speaker EQ for the built-in ALC274 speakers. Windows ships vendor tuning for
# them; Linux plays them raw, which sounds thin and boxy. This is a PipeWire
# filter-chain set up as a WirePlumber smart filter: it sits in front of the
# speaker sink only, so headphones and HDMI bypass it.
#
# The curve was tuned by ear, not measured. Adjust it live with
# `pw-cli s <eq node id> Props '{ params = [ "hp:Freq" 140 ] }'` and copy the
# values back here.
_: let
  # UCM node name of the speaker sink under SOF (sof-hda-dsp, HiFi verb).
  # If `wpctl status` shows a different name, fix it here: with no matching
  # target the smart filter is simply not inserted.
  speakerSink = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink";

  biquad = name: label: control: {
    type = "builtin";
    inherit name label control;
  };
in {
  services.pipewire.extraConfig.pipewire."90-speaker-eq" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Speaker EQ";
          "media.name" = "Speaker EQ";
          # A mono graph; filter-chain copies it once per channel.
          "audio.channels" = 2;
          "audio.position" = ["FL" "FR"];
          "filter.graph" = {
            nodes = [
              # Headroom for the boosts below, about -4 dB.
              (biquad "pre" "linear" {"Mult" = 0.63;})
              # The drivers cannot move air below this; cutting it lets them
              # play louder without distorting.
              (biquad "hp" "bq_highpass" {
                "Freq" = 130.0;
                "Q" = 0.707;
              })
              # Body.
              (biquad "low" "bq_peaking" {
                "Freq" = 250.0;
                "Q" = 1.0;
                "Gain" = 3.0;
              })
              # Boxy midrange.
              (biquad "mid" "bq_peaking" {
                "Freq" = 800.0;
                "Q" = 1.2;
                "Gain" = -2.0;
              })
              # Harshness.
              (biquad "harsh" "bq_peaking" {
                "Freq" = 3500.0;
                "Q" = 1.5;
                "Gain" = -2.5;
              })
              # Air.
              (biquad "air" "bq_highshelf" {
                "Freq" = 9000.0;
                "Q" = 0.707;
                "Gain" = 3.0;
              })
            ];
            links = [
              {
                output = "pre:Out";
                input = "hp:In";
              }
              {
                output = "hp:Out";
                input = "low:In";
              }
              {
                output = "low:Out";
                input = "mid:In";
              }
              {
                output = "mid:Out";
                input = "harsh:In";
              }
              {
                output = "harsh:Out";
                input = "air:In";
              }
            ];
          };
          "capture.props" = {
            "node.name" = "effect_input.speaker_eq";
            "media.class" = "Audio/Sink";
            "filter.smart" = true;
            "filter.smart.name" = "speaker-eq";
            "filter.smart.target" = {"node.name" = speakerSink;};
          };
          "playback.props" = {
            "node.name" = "effect_output.speaker_eq";
            "node.passive" = true;
          };
        };
      }
    ];
  };
}
