{
  lib,
  stdenv,
  cmake,
  ninja,
  qt6,
}:

stdenv.mkDerivation {
  pname = "qt-quick-app";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../CMakeLists.txt
      ../include
      ../qml
      ../src
      ../tests
    ];
  };

  nativeBuildInputs = [
    cmake
    ninja
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ qt6.qtwayland ];

  cmakeFlags = [ "-DBUILD_TESTING=ON" ];
  doCheck = true;

  meta = {
    description = "A C++23 and Qt Quick application";
    mainProgram = "qt-quick-app";
    platforms = lib.platforms.unix;
  };
}
