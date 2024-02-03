# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, dash
, execline
, iproute2-iptables-legacy
}:
let
  iproute2 = iproute2-iptables-legacy;
  name = iproute2.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = iproute2.version;

  contents = [ dash execline iproute2 ];

  extraCommands = ''
    ln -sf dash bin/sh
  '';

  config = {
    Env = [ "PATH=/bin" ];
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}