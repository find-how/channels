#!/bin/bash

# Check if repository path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <repository-path>"
    exit 1
fi

REPO_PATH="$1"

# Check if the repository exists
if [ ! -d "$REPO_PATH" ]; then
    echo "Repository directory does not exist: $REPO_PATH"
    exit 1
fi

# Update meta.yaml with new requirements and configurations
cat > "$REPO_PATH/conda/recipe/meta.yaml" << 'EOF'
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
  script:
    # Unix configuration
    {% if not win %}
    - ./configure --prefix=$PREFIX \
        --enable-shared \
        --enable-static \
        --with-config-file-path=$PREFIX/etc/php \
        --with-config-file-scan-dir=$PREFIX/etc/php/conf.d \
        --enable-bcmath \
        --enable-calendar \
        --enable-dba \
        --enable-exif \
        --enable-ftp \
        --enable-mbstring \
        --enable-shmop \
        --enable-soap \
        --enable-sockets \
        --enable-sysvmsg \
        --enable-sysvsem \
        --enable-sysvshm \
        --with-bz2 \
        --with-curl \
        --with-freetype \
        --with-gd \
        --with-gettext \
        --with-gmp \
        --with-iconv \
        --with-jpeg \
        --with-webp \
        --with-png \
        --with-pdo-sqlite \
        --with-xsl \
        --with-zlib
    - make -j${CPU_COUNT}
    - make install
    {% else %}
    - cmake -G "NMake Makefiles" -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
        -DCMAKE_BUILD_TYPE=Release ^
        -DWITH_CURL=ON ^
        -DWITH_OPENSSL=ON ^
        -DWITH_ZLIB=ON
    - nmake
    - nmake install
    {% endif %}

requirements:
  build:
    - {{ compiler('c') }}
    - {{ compiler('cxx') }}
    - autoconf  # [not win]
    - automake  # [not win]
    - libtool  # [not win]
    - pkg-config
    - make  # [not win]
    - cmake  # [win]
    - bison
    - flex  # [not win]
    - re2c
    - m4  # [not win]
    - perl
    - gettext  # [not win]
    - libiconv  # [not win]
    
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
    - libgd  # [not win]
    - freetype  # [not win]
    - libjpeg-turbo  # [not win]
    - libpng  # [not win]
    - libwebp  # [not win]

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
    - php -i
    - php --ini
    - php -r "if(!extension_loaded('openssl')) exit(1);"
    - php -r "if(!extension_loaded('curl')) exit(1);"
    - php -r "if(!extension_loaded('json')) exit(1);"
    - php -r "if(!extension_loaded('mbstring')) exit(1);"
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

# Create post-link script
mkdir -p "$REPO_PATH/conda/recipe/post-link"
cat > "$REPO_PATH/conda/recipe/post-link/post-link.sh" << 'EOF'
#!/bin/bash

# Create configuration directories
mkdir -p $PREFIX/etc/php/conf.d

# Copy default php.ini
if [ -f $PREFIX/php.ini-production ]; then
    cp $PREFIX/php.ini-production $PREFIX/etc/php/php.ini
fi
EOF

chmod +x "$REPO_PATH/conda/recipe/post-link/post-link.sh"

# Update .github/workflows/php-build.yml to add conda-forge channel
sed -i 's/conda install conda-build conda-verify -y/conda install conda-build conda-verify -y -c conda-forge/' "$REPO_PATH/.github/workflows/php-build.yml"

# Add build caching to workflow
sed -i '/steps:/a\    - name: Cache conda packages\n      uses: actions/cache@v3\n      with:\n        path: ~/conda_pkgs_dir\n        key: ${{ runner.os }}-conda-${{ matrix.platform.name }}-${{ matrix.php-version }}-${{ hashFiles('\''conda/recipe/meta.yaml'\'') }}\n        restore-keys: |\n          ${{ runner.os }}-conda-${{ matrix.platform.name }}-${{ matrix.php-version }}-\n          ${{ runner.os }}-conda-${{ matrix.platform.name }}-\n          ${{ runner.os }}-conda-' "$REPO_PATH/.github/workflows/php-build.yml"

# Add error handling to build step
sed -i '/conda build/i\        set -e' "$REPO_PATH/.github/workflows/php-build.yml"

echo "Repository updated successfully at $REPO_PATH"
echo "Changes made:"
echo "1. Updated meta.yaml with new dependencies and build configurations"
echo "2. Added post-link script for PHP configuration"
echo "3. Added conda-forge channel to workflow"
echo "4. Added build caching to workflow"
echo "5. Added error handling to build steps"
echo ""
echo "Next steps:"
echo "1. Review changes"
echo "2. Test build locally if possible"
echo "3. Commit and push changes"
echo "4. Monitor GitHub Actions build"
EOF

# Make script executable
chmod +x update-repo-script.sh