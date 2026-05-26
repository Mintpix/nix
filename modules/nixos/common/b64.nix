# Pure Nix base64 decoder — no derivations, no external tools.
# Based on the pattern from home-manager's gpg-agent.nix hexStringToBase32
# and manveru's base64 encoder gist.
{ lib }:
let
  inherit (builtins)
    elemAt foldl' genList length stringLength substring;
  inherit (lib)
    stringToCharacters listToAttrs imap0;

  # Base64 alphabet
  b64chars = stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  # Lookup table: base64 char -> 6-bit integer value
  b64table = listToAttrs (imap0 (i: c: { name = c; value = i; }) b64chars);

  # ASCII printable range (32-126) as int->char lookup
  # Built from a literal string to avoid needing chr()
  asciiPrintable = stringToCharacters " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
  intToChar = listToAttrs (imap0 (i: c: { name = toString (i + 32); value = c; }) asciiPrintable);

  # Decode a base64 string to plain text (ASCII only)
  decode = s:
    let
      # Strip padding characters
      chars = builtins.filter (c: c != "=") (stringToCharacters s);
      vals = map (c: b64table.${c}) chars;
      n = length vals;
      nFull = n / 4;
      rem = n - nFull * 4;

      # Process a full group of 4 sextets -> 3 bytes
      fullGroup = g:
        let
          b = g * 4;
          v0 = elemAt vals b;
          v1 = elemAt vals (b + 1);
          v2 = elemAt vals (b + 2);
          v3 = elemAt vals (b + 3);
        in [
          (v0 * 4 + v1 / 16)
          (lib.mod v1 16 * 16 + v2 / 4)
          (lib.mod v2 4 * 64 + v3)
        ];

      # Handle trailing group (2 or 3 sextets -> 1 or 2 bytes)
      tailGroup =
        if rem == 2 then
          let
            b = nFull * 4;
            v0 = elemAt vals b;
            v1 = elemAt vals (b + 1);
          in [ (v0 * 4 + v1 / 16) ]
        else if rem == 3 then
          let
            b = nFull * 4;
            v0 = elemAt vals b;
            v1 = elemAt vals (b + 1);
            v2 = elemAt vals (b + 2);
          in [
            (v0 * 4 + v1 / 16)
            (lib.mod v1 16 * 16 + v2 / 4)
          ]
        else [ ];

      allBytes = builtins.concatMap fullGroup (genList (x: x) nFull) ++ tailGroup;
    in
      builtins.concatStringsSep "" (map (b: intToChar.${toString b}) allBytes);
in {
  inherit decode;
}
