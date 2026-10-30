{ config, pkgs, ... }:

let
  # nixpkgs ships Noto Color Emoji as CBDT/CBLC bitmaps, which CoreText does
  # not support: macOS silently ignores the font (and the COLRv1 build renders
  # blank). The same PNGs are repacked into an sbix table -- the format Apple
  # Color Emoji uses -- so macOS can actually render it.
  notoColorEmojiSbix = pkgs.runCommand "noto-color-emoji-sbix" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ];
  } ''
    mkdir -p $out/share/fonts/noto
    python3 ${pkgs.writeText "cbdt2sbix.py" ''
      import sys
      from fontTools.ttLib import TTFont, newTable
      from fontTools.ttLib.tables import sbixStrike, sbixGlyph
      from fontTools.ttLib.tables._g_l_y_f import Glyph

      f = TTFont(sys.argv[1])
      cblc, cbdt = f["CBLC"], f["CBDT"]

      sbix = newTable("sbix")
      sbix.version, sbix.flags, sbix.strikes = 1, 1, {}
      for i, strikeData in enumerate(cbdt.strikeData):
          ppem = cblc.strikes[i].bitmapSizeTable.ppemY
          strike = sbixStrike.Strike(ppem=ppem, resolution=72)
          for name, bmp in strikeData.items():
              bmp.decompile()
              m = bmp.metrics
              strike.glyphs[name] = sbixGlyph.Glyph(
                  glyphName=name, graphicType="png ", imageData=bmp.imageData,
                  originOffsetX=m.BearingX, originOffsetY=m.BearingY - m.height)
          sbix.strikes[ppem] = strike
      f["sbix"] = sbix
      del f["CBDT"], f["CBLC"]

      # sbix fonts still need an outline table; empty glyphs keep the hmtx metrics.
      glyf = newTable("glyf")
      glyf.glyphOrder = f.getGlyphOrder()
      glyf.glyphs = {n: Glyph() for n in glyf.glyphOrder}
      f["glyf"] = glyf
      f["loca"] = newTable("loca")
      f["head"].indexToLocFormat = 0
      maxp = f["maxp"]
      maxp.tableVersion = 0x00010000
      for a in ("maxTwilightPoints", "maxStorage", "maxFunctionDefs",
                "maxInstructionDefs", "maxStackElements", "maxSizeOfInstructions",
                "maxComponentElements", "maxPoints", "maxContours",
                "maxCompositePoints", "maxCompositeContours", "maxComponentDepth"):
          setattr(maxp, a, 0)
      maxp.maxZones = 1
      f.save(sys.argv[2])
    ''} \
      ${pkgs.noto-fonts-color-emoji}/share/fonts/noto/NotoColorEmoji.ttf \
      $out/share/fonts/noto/NotoColorEmoji.ttf
  '';
in
{
  # Fonts configuration
  home.packages = with pkgs; [
    # JetBrains Mono
    jetbrains-mono

    # Noto fonts (Japanese + Emoji)
    noto-fonts
    noto-fonts-cjk-sans   # CJK (Chinese, Japanese, Korean) Sans
    noto-fonts-cjk-serif  # CJK Serif
    # Color Emoji (macOS gets the sbix build; the stock CBDT one would shadow it)
    (if stdenv.isDarwin then notoColorEmojiSbix else noto-fonts-color-emoji)

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
    '';
  };
}
