# Pure Nix base64 decoder (no derivations).
{ lib }:
let
  inherit (builtins)
    elemAt foldl' genList length stringLength substring;
  inherit (lib)
    stringToCharacters listToAttrs imap0;

  b64chars = stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  b64table = listToAttrs (imap0 (i: c: { name = c; value = i; }) b64chars);

  asciiPrintable = stringToCharacters " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
  intToChar = listToAttrs (imap0 (i: c: { name = toString (i + 32); value = c; }) asciiPrintable);

  decode = s:
    let
      chars = builtins.filter (c: c != "=") (stringToCharacters s);
      vals = map (c: b64table.${c}) chars;
      n = length vals;
      nFull = n / 4;
      rem = n - nFull * 4;

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
