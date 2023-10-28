{ lib
, stdenv
, fetchurl
, appimageTools
, makeWrapper
# graphs will not sync without matching upstream's major electron version
, electron_26
, git
, nix-update-script
}:

stdenv.mkDerivation (finalAttrs: let
  inherit (finalAttrs) pname tag version src appimageContents;
in {
  pname = "logseq";
  tag = "nightly";
  version = "0.9.19-alpha+nightly.20231027";

  src = fetchurl {
    url = "https://github.com/logseq/logseq/releases/download/${tag}/logseq-linux-x64-${version}.AppImage";
    hash = "sha256-RrG3tmILvPK0y2Iat8Tf4NiKH4G2LFduCiliCf1l68g=";
    name = "${pname}-${version}.AppImage";
  };

  appimageContents = appimageTools.extract {
    inherit pname src version;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname} $out/share/applications
    cp -a ${appimageContents}/{locales,resources} $out/share/${pname}
    cp -a ${appimageContents}/Logseq.desktop $out/share/applications/${pname}.desktop

    # remove the `git` in `dugite` because we want the `git` in `nixpkgs`
    chmod +w -R $out/share/${pname}/resources/app/node_modules/dugite/git
    chmod +w $out/share/${pname}/resources/app/node_modules/dugite
    rm -rf $out/share/${pname}/resources/app/node_modules/dugite/git
    chmod -w $out/share/${pname}/resources/app/node_modules/dugite

    mkdir -p $out/share/pixmaps
    ln -s $out/share/${pname}/resources/app/icons/logseq.png $out/share/pixmaps/${pname}.png

    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace Exec=Logseq Exec=${pname} \
      --replace Icon=Logseq Icon=${pname}

    runHook postInstall
  '';

  postFixup = ''
    # set the env "LOCAL_GIT_DIRECTORY" for dugite so that we can use the git in nixpkgs
    makeWrapper ${electron_26}/bin/electron $out/bin/${pname} \
      --set "LOCAL_GIT_DIRECTORY" ${git} \
      --add-flags $out/share/${pname}/resources/app \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "A local-first, non-linear, outliner notebook for organizing and sharing your personal knowledge base";
    homepage = "https://github.com/logseq/logseq";
    changelog = "https://github.com/logseq/logseq/releases/tag/${tag}";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" ];
  };
})
