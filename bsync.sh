#! /bin/sh
basepath=$(cd `dirname $0`; pwd)

cd $basepath

hexo clean && \
hexo d -g && \
rsync -arzp ./ sheep3@47.94.154.184:/home/sheep3/prod_work/blog

