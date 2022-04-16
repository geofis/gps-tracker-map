#!/bin/bash

#  author: José Ramón Martínez Batlle, March, 7, 2022
#  GitHub: geofis
#  Twitter: @geografiard

rm -rf log
rm -rf sh
rm -f config.js
rm -f crontab_new
rm -f nohup.out
mv data/data-original.csv data/data.csv
