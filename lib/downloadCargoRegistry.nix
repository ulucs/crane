{ fetchurl
, urlForCargoPackage
, runCommand
, lib
}:

{ packages, overrideVendorCargoPackage ? _: d: d }:
let
  getTarball = ({ name, version, checksum, ... }@args:
    let
      pkgInfo = urlForCargoPackage args;
    in
    {
      inherit name version checksum;
      tarball = fetchurl (pkgInfo.fetchurlExtraArgs // {
        inherit (pkgInfo) url;
        name = "${name}-${version}";
        sha256 = checksum;
      });
    });

  fakeDrv = {
    overrideAttrs = f: f { };
  };

  extract = (package:
    let
      tarball = getTarball package;
      outPath = "$out/${lib.escapeShellArg "${tarball.name}-${tarball.version}"}";
      drv = overrideVendorCargoPackage package fakeDrv;
    in ''
      mkdir -p ${outPath}
      tar -xf ${tarball.tarball} -C ${outPath} --strip-components=1
      pushd ${outPath}
      echo '{"files":{}, "package":"${tarball.checksum}"}' > .cargo-checksum.json
      ${drv.patchPhase or ""}
      popd
    '');
in
runCommand "extract-cargo-packages" { } ''
  mkdir -p $out
  ${lib.strings.concatMapStrings extract packages}
''
