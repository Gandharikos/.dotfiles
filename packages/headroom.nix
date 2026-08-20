{
  lib,
  stdenv,
  python3Packages,
  fetchurl,
  ast-grep,
  autoPatchelfHook,
  makeWrapper,
  ...
}:
let
  inherit (lib) makeBinPath;
  pname = "headroom-ai";
  version = "0.27.0";

  # headroom-ai is built with maturin and ships a compiled Rust extension
  # (headroom/_core.so) alongside the Python sources. Building from the sdist
  # would require the full Rust/Cargo toolchain plus offline crate vendoring,
  # so we install the prebuilt abi3 wheel instead (cp310-abi3 → works on any
  # CPython >= 3.10, including nixpkgs' 3.13). autoPatchelfHook fixes up the
  # manylinux .so against the Nix store libc/libgcc.
  wheels = {
    "x86_64-linux" = {
      platformTag = "manylinux_2_28_x86_64";
      hash = "sha256-ZA5npBdDJlN2WCqSaRoZKowkSO8LIWeg4UoqRYrb4t0=";
    };
    "aarch64-linux" = {
      platformTag = "manylinux_2_28_aarch64";
      hash = "sha256-+PoVAGHbJRPoWE0uS1CvkwExvP4wEID5dGSzUaA/V3c=";
    };
    "aarch64-darwin" = {
      platformTag = "macosx_11_0_arm64";
      hash = "sha256-ALVLcFM8hB9HAv/68hXv+Euv7XYSwHpW1nXvih/6tUM=";
    };
  };

  wheel =
    wheels.${stdenv.hostPlatform.system}
      or (throw "headroom-ai: unsupported platform ${stdenv.hostPlatform.system}");
in
python3Packages.buildPythonPackage {
  inherit pname version;
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/cp310/h/headroom_ai/headroom_ai-${version}-cp310-abi3-${wheel.platformTag}.whl";
    inherit (wheel) hash;
  };

  # autoPatchelfHook only meaningful for the manylinux ELF .so on Linux.
  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # libgcc_s / libstdc++ for the maturin-built Rust extension module.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  # Core deps minus ast-grep-cli (a PyPI wrapper that only bundles the Rust
  # `ast-grep` binary — we provide the native nixpkgs binary on PATH instead),
  # plus the full [proxy] extra so the `headroom proxy` server is functional.
  dependencies = [
    # core
    python3Packages.tiktoken
    python3Packages.pydantic
    python3Packages.litellm
    python3Packages.click
    python3Packages.rich
    python3Packages.opentelemetry-api
    # [proxy] extra
    python3Packages.fastapi
    python3Packages.uvicorn
    python3Packages.httpx
    python3Packages.h2 # httpx[http2]
    python3Packages.openai
    python3Packages.mcp
    python3Packages.magika
    python3Packages.zstandard
    python3Packages.websockets
    python3Packages.onnxruntime
    python3Packages.transformers
    python3Packages.watchdog
    python3Packages.sqlite-vec
  ];

  # The wheel's METADATA still lists `ast-grep-cli` as a core Requires-Dist;
  # we intentionally drop it in favour of the native `ast-grep` binary, so the
  # runtime-deps check would otherwise fail on a "missing" dependency.
  dontCheckRuntimeDeps = true;

  # No test suite at runtime; tests need network/ML models.
  doCheck = false;

  # Make the `ast-grep` binary (CodeCompressor / astgrep interceptor) reachable
  # from the wrapped console script. nixpkgs ships only `ast-grep` (not `sg`),
  # and headroom resolves it via shutil.which("ast-grep").
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (makeBinPath [ ast-grep ])
  ];

  pythonImportsCheck = [ "headroom" ];

  meta = {
    description = "Context optimization layer for LLM applications (token-compression proxy for Claude Code / Codex)";
    homepage = "https://github.com/chopratejas/headroom";
    changelog = "https://github.com/chopratejas/headroom/blob/main/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "headroom";
    platforms = lib.attrNames wheels;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
