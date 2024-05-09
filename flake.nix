{
  description = "A very basic flake";
  nixConfig.bash-prompt-prefix = "(nix dev)";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system} = {
        default = pkgs.mkShell {
          name = "SwayNC shell";
          inherit (pkgs.swaynotificationcenter) buildInputs depsBuildBuild depsBuildBuildPropagated depsBuildTarget
            depsBuildTargetPropagated depsHostHost depsHostHostPropagated depsTargetTarget
            depsTargetTargetPropagated propagatedBuildInputs propagatedNativeBuildInputs strictDeps;

          # overrides for local development
          nativeBuildInputs = pkgs.swaynotificationcenter.nativeBuildInputs ++ (with pkgs; [
            sassc
            pantheon.granite
            vala-language-server
            uncrustify
          ]);

          configurePhase = "rm -r build ; meson setup build";
          buildPhase = "meson compile -C build";
          launchPhase = "meson devenv -C build ./src/swaync";
        };
      };
    };
}
