name: Release

on:
  push:
    branches: ["main", "cross"]
  workflow_dispatch:

env:
  BIN_NAME: cocox

jobs:
  #   release-please:
  #     runs-on: ubuntu-latest
  #     permissions:
  #       contents: write
  #       pull-requests: write
  #     outputs:
  #       release_created: ${{ steps.release.outputs.release_created }}
  #       tag_name: ${{ steps.release.outputs.tag_name }}
  #     steps:
  #       - name: Release
  #         id: release
  #         uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0

  #       - uses: actions/checkout@v6
  #         if: ${{ steps.release.outputs.release_created }}

  release-build:
    name: Build ${{ matrix.target }}
    runs-on: ${{ matrix.runner }}
    # needs: release-please
    # if: ${{ needs.release-please.outputs.release_created }}
    strategy:
      matrix:
        include:
          - target: x86_64-unknown-linux-gnu
            runner: ubuntu-latest
            os_name: linux
            arch: amd64
            use_cross: true
          - target: aarch64-unknown-linux-gnu
            runner: ubuntu-latest
            os_name: linux
            arch: arm64
            use_cross: true
          - target: x86_64-pc-windows-gnu
            runner: ubuntu-latest
            os_name: windows
            arch: amd64
            use_cross: true
          - target: x86_64-apple-darwin
            runner: macos-latest
            os_name: darwin
            arch: amd64
            use_cross: false
          - target: aarch64-apple-darwin
            runner: macos-latest
            os_name: darwin
            arch: arm64
            use_cross: false

    steps:
      - uses: actions/checkout@v6

      - name: Install Rust
        uses: actions-rust-lang/setup-rust-toolchain@v1
        with:
          toolchain: stable
          target: ${{ matrix.target }}

      - name: Install Cross
        if: matrix.use_cross
        run: cargo install cross --git https://github.com/cross-rs/cross

      - name: Build
        if: matrix.use_cross
        run: cross build --target ${{ matrix.target }} --release

      - name: Build (cargo fallback) # specifically for mac
        if: ${{ !matrix.use_cross }}
        run: cargo build --target ${{ matrix.target }} --release

      - name: Set archive name
        id: archive
        shell: bash
        run: |
          VERSION="v0.4.0"
          echo "name=${BIN_NAME}_${VERSION}_${{ matrix.os_name }}_${{ matrix.arch }}" >> $GITHUB_OUTPUT

      - name: Archive binary (Unix)
        if: matrix.os_name != 'windows'
        run: |
          mkdir -p dist
          cp target/${{ matrix.target }}/release/"$BIN_NAME" dist/"$BIN_NAME"
          tar -czf ${{ steps.archive.outputs.name }}.tar.gz -C dist "$BIN_NAME"


      - name: Archive binary (Windows)
        if: matrix.os_name == 'windows'
        run: |
          mkdir -p dist
          cp target/${{ matrix.target }}/release/"$BIN_NAME".exe dist/"$BIN_NAME".exe
          tar -czf ${{ steps.archive.outputs.name }}.tar.gz -C dist "$BIN_NAME".exe

      - name: Upload to GitHub Release
        uses: softprops/action-gh-release@v3
        with:
          tag_name: v0.4.0
          # tag_name: ${{ needs.release-please.outputs.tag_name }}
          files: ${{ steps.archive.outputs.name }}.tar.gz
