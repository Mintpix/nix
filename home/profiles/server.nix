# Server profile: no extra dev tools.
# Server hosts use common.nix only (me + shell + git + packages).
{ flake, ... }:
{
  # No additional imports needed — common.nix provides everything.
}
