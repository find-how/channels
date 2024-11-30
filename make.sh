#!/bin/bash

# Create the directory structure
mkdir -p conda/recipe
mkdir -p .github/workflows

# Create the recipe file
cat > conda/recipe/meta.yaml << 'EOF'
{% set name = "php" %}

package:
  name: {{ name }}
  version: {{ version }}

source:
  url: https://www.php.net/distributions/php-{{ version }}.tar.gz
  sha256: {% if version == "7.2.34" %}409e11bc6a2c18707dfc44bc61c820ddfd81e17481470f3405ee7822d8379903
         {% elif version == "7.3.33" %}de24a6494d8f3339c54f89ff5304d7e6dc49d3f6a5665b5f8e67e812a813672f
         {% elif version == "7.4.33" %}3aef56f23e1a4684ca1c6ee77d2bae24d9c0c54a5a17231b52e8816f1058cac7
         {% elif version == "8.0.30" %}c157e3aad153a8a9b95efb5caef69831da15b84c8571c15c7dc5f587f93dd73a
         {% elif version == "8.1.27" %}479e65c3f05714d4aace1370e617d78e49e996ec7a7579b8f13efc05cbedb463
         {% elif version == "8.2.17" %}98cab58662cb66a382d79932fdcb5f92f63858227f3dbf9325be836aa3fca4b8
         {% endif %}

build:
  number: 0
  detect_binary_files_with_prefix: true
  features:
    - vc14  # [win]

requirements:
  build:
    - vs2019_win-64  # [win]
    - windows-sdk_win-64  # [win]
    - {{ compiler('c') }}  # [not win]
    - {{ compiler('cxx') }}  # [not win]
    - autoconf  # [not win]
    - automake  # [not win]
    - libtool  # [not win]
    - pkg-config
    - make  # [not win]
    - cmake  # [win]
    - bison
    - re2c
    - perl  # [win]
    - nasm  # [win]
  host:
    - openssl
    - curl
    - zlib
    - libxml2
    - icu
    - oniguruma
    - libzip
    - libsqlite
    - libxslt  # [not win]
    - krb5  # [not win]
    - readline  # [not win]
  run:
    - openssl
    - curl
    - zlib
    - libxml2
    - icu
    - oniguruma
    - libzip
    - libsqlite
    - libxslt  # [not win]
    - krb5  # [not win]
    - readline  # [not win]

test:
  commands:
    - php --version
    - php -m
    - if not exist %LIBRARY_BIN%\php.exe exit 1  # [win]
    - test -f $PREFIX/bin/php  # [not win]

about:
  home: https://www.php.net/
  license: PHP-3.01
  license_family: OTHER
  license_file: LICENSE
  summary: PHP is a popular general-purpose scripting language
  description: |
    PHP is a popular general-purpose scripting language that is especially suited 
    to web development. Fast, flexible and pragmatic, PHP powers everything from 
    your blog to the most popular websites in the world.
  doc_url: https://www.php.net/docs.php
  dev_url: https://github.com/php/php-src

extra:
  recipe-maintainers:
    - find-how
EOF

# Create the workflow file
cat > .github/workflows/build.yml << 'EOF'
name: PHP Cross-Platform Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  prepare-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - id: set-matrix
        shell: bash
        run: |
          matrix_json='{"php-version":["7.2.34","7.3.33","7.4.33","8.0.30","8.1.27","8.2.17"],"platform":[{"os":"ubuntu-latest","arch":"x64","name":"linux-64"},{"os":"ubuntu-latest","arch":"arm64","name":"linux-aarch64"},{"os":"windows-latest","arch":"x64","name":"win-64"},{"os":"macos-latest","arch":"x64","name":"osx-64"},{"os":"macos-latest","arch":"arm64","name":"osx-arm64"}]}'
          echo "matrix=${matrix_json}" >> $GITHUB_OUTPUT

  build:
    needs: prepare-matrix
    strategy:
      matrix: ${{fromJson(needs.prepare-matrix.outputs.matrix)}}
      fail-fast: false

    runs-on: ${{ matrix.platform.os }}

    steps:
    - uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.10'

    - name: Install Conda
      uses: conda-incubator/setup-miniconda@v3
      with:
        auto-update-conda: true
        python-version: '3.10'
        activate-environment: build-env

    - name: Install conda-build
      shell: bash -el {0}
      run: |
        conda install conda-build conda-verify -y

    - name: Setup QEMU (for ARM builds)
      if: matrix.platform.arch == 'arm64'
      uses: docker/setup-qemu-action@v3
      with:
        platforms: arm64

    - name: Create build directory
      shell: bash -el {0}
      run: mkdir -p conda-build

    - name: Generate meta.yaml
      shell: bash -el {0}
      working-directory: conda-build
      run: |
        cat > meta.yaml << 'EOF'
        {% set version = "${{ matrix.php-version }}" %}
        EOF
        cat ../conda/recipe/meta.yaml >> meta.yaml

    - name: Configure conda for cross-compilation
      shell: bash -el {0}
      run: |
        # Add target platform to conda config
        conda config --append subdirs ${{ matrix.platform.name }}
        # Show current config for debugging
        conda config --show

    - name: Build PHP
      shell: bash -el {0}
      working-directory: conda-build
      env:
        CONDA_SUBDIR: ${{ matrix.platform.name }}
      run: |
        # Set build architecture
        export CONDA_BUILD_CROSS_COMPILATION=1
        
        # Handle different platforms
        case "${{ matrix.platform.name }}" in
          "win-64")
            conda build . --no-test --msvc-compiler=14.0
            ;;
          "osx-arm64")
            MACOSX_DEPLOYMENT_TARGET=11.0 conda build . --no-test
            ;;
          *)
            conda build . --no-test
            ;;
        esac

    - name: Collect build artifacts
      shell: bash -el {0}
      run: |
        mkdir -p channel/${{ matrix.platform.name }}
        if [ "${{ runner.os }}" = "Windows" ]; then
          cp $CONDA/conda-bld/${{ matrix.platform.name }}/*.tar.bz2 channel/${{ matrix.platform.name }}/ 2>/dev/null || :
        else
          cp ${CONDA}/conda-bld/${{ matrix.platform.name }}/*.tar.bz2 channel/${{ matrix.platform.name }}/ 2>/dev/null || :
        fi

    - name: Upload build artifacts
      uses: actions/upload-artifact@v3
      with:
        name: channel-${{ matrix.platform.name }}
        path: channel/
        if-no-files-found: error

  create-channel:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Download all artifacts
        uses: actions/download-artifact@v3
        with:
          path: channel

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Install conda-build
        uses: conda-incubator/setup-miniconda@v3
        with:
          auto-update-conda: true
          python-version: '3.10'
          activate-environment: build-env

      - name: Install conda tools
        shell: bash -el {0}
        run: conda install conda-build -y

      - name: Prepare channel structure
        shell: bash -el {0}
        run: |
          mkdir -p channel-root
          for platform_dir in channel/channel-*/; do
            if [ -d "$platform_dir" ]; then
              cp -r $platform_dir/* channel-root/
            fi
          done

      - name: Index channel
        shell: bash -el {0}
        run: |
          cd channel-root
          for platform in linux-64 linux-aarch64 win-64 osx-64 osx-arm64; do
            if [ -d "$platform" ]; then
              conda index $platform
            fi
          done
          conda index .

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./channel-root
          keep_files: false
          commit_message: Update conda channel

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          name: Latest Channel Update
          tag_name: channel-${{ github.sha }}
          files: channel-root/**/*
          body: |
            Latest update to the conda channel.
            
            Use this channel by adding the following to your conda configuration:
            ```
            conda config --add channels https://find-how.github.io/channels/
            ```
EOF

# Initialize git repository
git init
git add .
git commit -m "Initial commit"