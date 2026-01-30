{ lib, ... }:
{
  # Modern audio stack - PipeWire replaces PulseAudio + JACK + ALSA
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true; # For 32-bit games/apps
    pulse.enable = lib.mkDefault true; # PulseAudio compatibility
    jack.enable = lib.mkDefault true; # JACK compatibility
  };

  # Real-time audio priority
  security.rtkit.enable = lib.mkDefault true;
}
