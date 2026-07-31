{
  fetchFromGitHub,
  ffmpeg,
  lib,
  mpvScripts,
  xdg-utils,
  ...
}:
mpvScripts.buildLua {
  pname = "mpv-lang-learner";
  version = "0-unstable-2025-07-08";

  src = fetchFromGitHub {
    owner = "liberlanco";
    repo = "mpv-lang-learner";
    rev = "2cd936ae4ab818fc72a74b2ac3640e5a6d4c97d9";
    hash = "sha256-4C9eWOEYhKMopbMZbny1ybAnHplmNLdWL1WhboK/Ztw=";
  };

  scriptPath = "lang-learner.lua";
  runtime-dependencies = [
    ffmpeg
    xdg-utils
  ];

  meta = {
    description = "Tune mpv into a video player for language learners";
    homepage = "https://github.com/liberlanco/mpv-lang-learner";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.all;
  };
}
