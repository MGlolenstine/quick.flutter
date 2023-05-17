{
  description = "Flutter mobile app";

  # Nixpkgs / NixOS version to use.
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    flutterNixpkgs = {
      type = "github";
      owner = "gilice";
      repo = "nixpkgs";
      rev = "8330de3339ea2353dbac4a3bfceaba9522fb7ff1";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flutterNixpkgs,
    fenix,
    utils,
  }:
    utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        flutterPkgs = import flutterNixpkgs {
          system = "x86_64-linux";
          config = {
            allowUnfree = true;
          };
        };

        androidBuildToolsVersion = "33.0.1";

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          toolsVersion = "26.1.1";
          platformToolsVersion = "33.0.3";
          buildToolsVersions = [androidBuildToolsVersion "29.0.2"];
          includeEmulator = false;
          emulatorVersion = "32.1.8";
          platformVersions = ["33"];
          includeSources = true;
          includeSystemImages = false;
          systemImageTypes = ["google_apis_playstore"];
          abiVersions = ["armeabi-v7a" "arm64-v8a"];
          cmakeVersions = ["3.22.1"];
          includeNDK = false;
          ndkVersions = ["25.1.8937393"];
          useGoogleAPIs = false;
          useGoogleTVAddOns = false;
          includeExtras = [
            "extras;google;gcm"
          ];
          extraLicenses = [
            "android-googletv-license"
            "android-sdk-arm-dbt-license"
            "android-sdk-license"
            "android-sdk-preview-license"
            "google-gdk-license"
            "intel-android-extra-license"
            "intel-android-sysimage-license"
            "mips-android-sysimage-license"
          ];
        };

        # Tools used for compiling the app for Linux
        linuxBuildTools = with pkgs; [
          at-spi2-core.dev
          clang
          cmake
          dbus.dev
          flutterPkgs.flutter
          gtk3
          libdatrie
          libepoxy.dev
          util-linux.dev
          libselinux
          libsepol
          libthai
          libxkbcommon
          ninja
          pcre
          pcre2.dev
          pkg-config
          xorg.libXdmcp
          xorg.libXtst
          libdeflate
        ];

        androidSdk = androidComposition.androidsdk;

        nativeBuildInputPackages = with pkgs; [
          llvmPackages_14.llvm
          llvmPackages_14.libunwind.dev
          pkg-config
          openssl
          binutils
          jdk11_headless
          glibc_multi
          libunwind.dev
        ];

        buildInputPackages = with pkgs;
          [
            libunwind.dev
            androidComposition.androidsdk
            androidComposition.platform-tools
            git
            unzip
            kotlin-language-server
            jdt-language-server
          ]
          ++ linuxBuildTools;
      in {
        devShell = pkgs.mkShell {
          nativeBuildInputs = nativeBuildInputPackages;
          buildInputs = buildInputPackages;

          shellHook = ''
            unset ANDROID_NDK
            unset ANDROID_NDK_HOME

            export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
            export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk-bundle"
            export CPATH="${pkgs.glibc_multi.dev}/include"
            export FLUTTER_ROOT="${flutterPkgs.flutter.unwrapped}/bin"
            export LD_LIBRARY_PATH="${pkgs.libepoxy}/lib"
            export LIBCLANG_PATH="${pkgs.llvmPackages_14.libclang.lib}/lib"

            # Fix for dart run ffigen
            export PATH="$FLUTTER_ROOT:$PATH"
          '';

          # Should fix Gradle errors
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${androidBuildToolsVersion}/aapt2";
        };
      }
    );
}
