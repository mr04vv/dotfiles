{ config, pkgs, ... }:

{
  # Fonts configuration
  home.packages = with pkgs; [
    # JetBrains Mono
    jetbrains-mono

    # Noto fonts (Japanese + Emoji)
    noto-fonts
    noto-fonts-cjk-sans   # CJK (Chinese, Japanese, Korean) Sans
    noto-fonts-cjk-serif  # CJK Serif
    noto-fonts-color-emoji # Color Emoji

    # Optional: Nerd Fonts version of JetBrains Mono (includes icons)
    # (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  # macOS: Install fonts to ~/Library/Fonts
  # Linux: Fonts are automatically available through home.packages
  home.activation = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    installFonts = config.lib.dag.entryAfter ["writeBoundary"] ''
      echo "Installing fonts to ~/Library/Fonts..."
      mkdir -p "$HOME/Library/Fonts"

      # Link fonts from Nix store
      for font_dir in ${pkgs.jetbrains-mono}/share/fonts/*; do
        if [ -d "$font_dir" ]; then
          run ln -sf "$font_dir"/* "$HOME/Library/Fonts/" 2>/dev/null || true
        fi
      done

      for font_dir in ${pkgs.noto-fonts}/share/fonts/*; do
        if [ -d "$font_dir" ]; then
          run ln -sf "$font_dir"/* "$HOME/Library/Fonts/" 2>/dev/null || true
        fi
      done

      for font_dir in ${pkgs.noto-fonts-cjk-sans}/share/fonts/*; do
        if [ -d "$font_dir" ]; then
          run ln -sf "$font_dir"/* "$HOME/Library/Fonts/" 2>/dev/null || true
        fi
      done

      for font_dir in ${pkgs.noto-fonts-color-emoji}/share/fonts/*; do
        if [ -d "$font_dir" ]; then
          run ln -sf "$font_dir"/* "$HOME/Library/Fonts/" 2>/dev/null || true
        fi
      done
    '';
  };
}
