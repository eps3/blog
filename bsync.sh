#! /bin/sh
basepath=$(cd `dirname $0`; pwd)

cd $basepath

hexo clean && \
hexo d -g && \
rsync -avrz ./ root@sheep3.com:/usr/local/webserver/blog/

