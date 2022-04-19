#!/bin/bash

#  author: José Ramón Martínez Batlle, March, 7, 2022
#  GitHub: geofis
#  Twitter: @geografiard

################################################################################
# Help function                                                                #
################################################################################
Help()
{
   # Display Help
   echo
   echo "    BLA BLA BLA"
   echo
   echo "    Syntax: install [-piPh] -t thing identifier"
   echo "    Options:"
   echo "    t     Thing identifier"
   echo "    p     Path for folder to save dweets"
   echo "    i     Time interval (in minutes) to get latest dweet [5]"
   echo "    d     Number of dweets to show in map (all dweets are preserved, this only affects the map) [10]"
   echo "    P     HTTP port [9001]"
   echo "    h     Display help"
   echo
   echo "    Example:"
   echo "    ./install.sh -t 333"
   echo "    ./install.sh -t 333 -p $HOME/my_dweets -i 1 -P 9001"
   echo
   exit
}

################################################################################
# Main program                                                                 #
################################################################################

# Manage arguments with flags
while getopts ":t:p:i:d:P:h" opt; do
    case $opt in
        t) thing_id="$OPTARG"
        ;;
        p) path_to_dweets="$OPTARG"
        ;;
        i) interval="$OPTARG"
        ;;
        d) n_dweets_map="$OPTARG"
        ;;
        P) http_port="$OPTARG"
        ;;
        h) Help
        ;;
        \?) echo "  Invalid option -$OPTARG"
        exit;;
    esac
done
shift $((OPTIND -1))

# Helper function: create dir, skip if exists
create_dir () {
  local dir=$1
  if [ -d "$dir" ]; then
  echo "  Directory $dir already exists. Skipping creation"
  else
  echo "  Directory $dir not found. Creating it"
  mkdir -p $dir
  fi
}

# Install dir
install_dir=$PWD

# Services dir
serv_dir=services
create_dir $serv_dir

# Timestamp
timestamp=`date +'%Y%m%dT%H%M%S'`

# Shells dirs var, create shells dir
sh_dir=sh

# Log dir var, create log dir, log file var
log_dir=log
log_filename="$log_dir/install-errors-$timestamp.log"

# Create dirs
create_dir $sh_dir
create_dir $log_dir

# Home directory
home_dir=$HOME

# Arguments
echo "  Verifying arguments ..."
if [ -z $thing_id ]; then
  echo "  Thing identifier: required argument not provided. Exiting" 2>&1 | tee -a $log_filename
  exit 1
  else
  echo "  Thing identifier: $thing_id"
fi
if [ -z $path_to_dweets ]; then
  echo "  Path to dweets: argument not provided, using default ($home_dir/my_dweets)"
  path_to_dweets="$home_dir/my_dweets"
  else
  echo "  Path to dweets: $path_to_dweets"
fi
if [ -z $interval ]; then
  echo "  Time interval (in minutes) to get latest dweet: argument not provided, using default (5 minutes)"
  interval=5
  else
  echo "  Time interval (in minutes) to get latest dweet: $interval"
fi
if [ -z $n_dweets_map ]; then
  echo "  Number of dweets to show in map: argument not provided, using default (10)"
  n_dweets_map=10
  else
  echo "  Number of dweets to show in map: $n_dweets_map"
fi
if [ -z $http_port ]; then
  echo "  HTTP port: argument not provided, using default (9001)"
  http_port=9001
  else
  echo "  HTTP port: $http_port"
fi
echo "  Done"

# Create dweets dir
echo "  Creating dweets directory ..."
create_dir $path_to_dweets
echo "  Done"

# Create script for getting latest dweet
echo "  Creating script for getting latest dweet ..."
cat > $sh_dir/get_latest_dweet.sh <<EOF
#!/bin/bash
/usr/bin/curl -w '\n' https://dweet.io/get/latest/dweet/for/$thing_id >> $path_to_dweets/log-\`date +%Y%m%d\`-w-dup.json
sort $path_to_dweets/log-\`date +%Y%m%d\`-w-dup.json | uniq > $path_to_dweets/log-\`date +%Y%m%d\`.json
EOF
chmod +x $sh_dir/get_latest_dweet.sh
echo "  Done"

# Create script for converting JSON file to delimited format
echo "  Creating script for converting JSON file to delimited format ..."
cat > $sh_dir/convert_json_to_delimited.sh <<EOF
#!/bin/bash
/bin/sed 's/^{.*\[//g' $path_to_dweets/log-\`date +%Y%m%d\`.json | /bin/sed 's/\]}//g' | /usr/bin/jq -r '[.thing, .created] + (.content | [.lat, .long, .batt]) | @csv' | /bin/sed '1 i\\"thing","created","lat","lng","batt"' | sed $'s/,/|/g' | sed $'s/"//g' > $path_to_dweets/log-\`date +%Y%m%d\`.csv
/usr/bin/tail -$n_dweets_map $path_to_dweets/log-\`date +%Y%m%d\`.csv | /bin/sed '1 i\\thing|created|lat|lng|batt' > $path_to_dweets/log-\`date +%Y%m%d\`-for-mapping.csv
/bin/ln -fs $path_to_dweets/log-\`date +%Y%m%d\`-for-mapping.csv $install_dir/data/data.csv
EOF
chmod +x $sh_dir/convert_json_to_delimited.sh
echo "  Done"

# Create crontabs
echo "  Creating cron jobs ..."
crontab -l > crontab_new
if grep -q "^[^#].*$sh_dir/get_latest_dweet.sh" crontab_new
then
  echo "  An existing cron job for getting dweets was found. Please delete it using 'crontab -e' and run the install script again" 2>&1 | tee -a $log_filename
  exit 1
else
  echo "  No existing cron job for getting dweets found. Installing one."
  echo "*/$interval * * * * $install_dir/$sh_dir/get_latest_dweet.sh" >> crontab_new
fi

if grep -q "^[^#].*$sh_dir/convert_json_to_delimited.sh" crontab_new
then
  echo "  An existing cron job for converting dweets was found. Please delete it using 'crontab -e' and run the install script again" 2>&1 | tee -a $log_filename
  exit 1
else
  echo "  No existing cron job for converting dweets found. Installing one."
  echo "*/$interval * * * *  ( sleep 10 ; $install_dir/$sh_dir/convert_json_to_delimited.sh )" >> crontab_new
fi
crontab crontab_new
rm crontab_new
echo "  Done"

# Configure leaflet-simple-csv
echo "  Configuring leaflet-simple-csv ... "
cp config.js.template config.js
sed -i 's/var maxZoom = .*/var maxZoom = 19;/g' config.js
echo "  Done"

# Configure unit services
echo "  Configuring unit services ... "
cat > $serv_dir/simplehttpgps.service <<EOF
[Unit]
Description=Generate leaflet HTTP server for gps tracker map
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

StartLimitIntervalSec=10
StartLimitBurst=5

[Service]
Type=simple
User=pi
WorkingDirectory=$install_dir/gps-tracker-map
Restart=on-failure
RestartSec=5s
ExecStart=/usr/bin/python -m SimpleHTTPServer 9001

[Install]
WantedBy=multi-user.target
EOF
echo "  Done"

echo "  "
echo "  Finish the installation by running a HTTP server following these steps:"
echo "  1. Copy the service: sudo cp $serv_dir/simplehttpgps.service /etc/systemd/system/"
echo "  2. Reload daemons: sudo systemctl daemon-reload"
echo "  3. Restart the service: systemctl restart simplehttpgps.service"
echo "  Optional. Verify: sudo systemctl status simplehttpgps.service"
echo "  Optional. Check the logs: journalctl -u simplehttpgps.service"

exit
