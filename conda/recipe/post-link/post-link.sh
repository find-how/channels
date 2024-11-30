#!/bin/bash

# Create configuration directories
mkdir -p $PREFIX/etc/php/conf.d

# Copy default php.ini
if [ -f $PREFIX/php.ini-production ]; then
    cp $PREFIX/php.ini-production $PREFIX/etc/php/php.ini
fi
