# SPDX-FileCopyrightText: 2023 - 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ inputs, perSystem, ... }@top:
let
  lmd = top.self.lastModifiedDate;
  year = builtins.substring 0 4 lmd;
  month = builtins.substring 4 2 lmd;
  day = builtins.substring 6 2 lmd;
  hour = builtins.substring 8 2 lmd;
  minute = builtins.substring 10 2 lmd;
  second = builtins.substring 12 2 lmd;
  created = "${year}-${month}-${day}T${hour}:${minute}:${second}Z";
in
{
  perSystem = { pkgs, system, ... }:
    let
      ctrs = {
        caddy = pkgs.callPackage ../ctrs/caddy { };
        cfdyndns = pkgs.callPackage ../ctrs/cfdyndns { };
        cf-zerotrust = pkgs.callPackage ../ctrs/cf-zerotrust { };
        chrony = pkgs.callPackage ../ctrs/chrony { };
        coreutils = pkgs.callPackage ../ctrs/coreutils { };
        docker-restart-unhealthy = pkgs.callPackage ../ctrs/docker-restart-unhealthy { };
        iperf3 = pkgs.callPackage ../ctrs/iperf3 { };
        iproute2 = pkgs.callPackage ../ctrs/iproute2 { };
        jellyfin = pkgs.callPackage ../ctrs/jellyfin { };
        komga = pkgs.callPackage ../ctrs/komga { };
        netperf = pkgs.callPackage ../ctrs/netperf { };
        pbr = pkgs.callPackage ../ctrs/pbr { };
        protonvpn-qbittorrent-port-forward = pkgs.callPackage ../ctrs/protonvpn-qbittorrent-port-forward { };
        prowlarr = pkgs.callPackage ../ctrs/prowlarr { };
        qbittorrent-nox = pkgs.callPackage ../ctrs/qbittorrent-nox { };
        socat = pkgs.callPackage ../ctrs/socat { };
        sonarr = pkgs.callPackage ../ctrs/sonarr { };
        syncthing = pkgs.callPackage ../ctrs/syncthing { };
        veloren-healthcheck = pkgs.callPackage ../ctrs/veloren-healthcheck { };
        # vrising = pkgs.callPackage ../ctrs/vrising { };
        wireguard = pkgs.callPackage ../ctrs/wireguard { };

        cetusguard = pkgs.callPackage ../ctrs/cetusguard { src = inputs.cetusguard; };
      };

      manifest = (pkgs.writeText "manifest" (builtins.toJSON
        (builtins.mapAttrs
          (_: v: { name = v.imageName; tag = v.imageTag; })
          ctrs))).overrideAttrs (_: { allowSubstitutes = true; });
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (final: prev:
            let inherit (final) lib; in {
              is-online = final.callPackage ../pkgs/is-online { };
              mkS6RC = final.callPackage ../pkgs/mk-s6-rc { };

              dockerTools = prev.dockerTools // {
                streamLayeredImage = args: lib.pipe args [
                  (a: a // {
                    inherit created;
                    maxLayers = a.maxLayers or 125;
                    config = {
                      Labels = {
                        "org.opencontainers.image.source" =
                          "https://github.com/becometheteapot/${a.name}";
                      };
                    } // a.config or { };
                  })
                  prev.dockerTools.streamLayeredImage
                  (d: builtins.getAttr "overrideAttrs" d (old:
                    let
                      inherit (old) buildCommand;
                      streamScript = lib.pipe buildCommand [
                        (lib.splitString " ")
                        (l: builtins.elemAt l 1)
                      ];
                      patchedScript = final.runCommand "stream" { } ''
                        patch -o "$out" "${streamScript}" "${./layer-mtime.patch}"
                        chmod a+x "$out"
                      '';
                      newBuildCommand = builtins.replaceStrings
                        [ streamScript ]
                        [ "${patchedScript}" ]
                        buildCommand;
                    in
                    assert (lib.isStorePath streamScript);
                    { buildCommand = newBuildCommand; }
                  ))
                ];
              };

              iproute2-iptables-legacy = final.iproute2.override { iptables = final.iptables-legacy; };

              writers = prev.writers // {
                writeExecline = { flags ? "-WP" }: final.writers.makeScriptWriter {
                  interpreter = "${final.execline}/bin/execlineb"
                    + lib.optionalString (flags != "") " ${flags}";
                };
              };
            })
        ];
      };

      packages = ctrs // { inherit manifest; };
    };
}
