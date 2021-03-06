#############################################Global variables##############################
readonly SS_MONITOR_SCRIPT="[Unit]
Description=SSR monitor

[Service]
ExecStart=/usr/bin/python3 /root/log_monitor.py -tn 100"
readonly SELF_DEFINED_COMMENT="#########-------"
readonly FUNC_NAME=${FUNCNAME[0]}
readonly HISTORY_PATH=/etc/profile
readonly LOGIN_ACCOUNT=/home/edee
readonly LOGIN_SSH_PATH=/home/edee/.ssh/
readonly SSH_KEY_PATH=/home/edee/.ssh/authorized_keys
readonly SS_MONITOR_PATH=/lib/systemd/system/ss_monitor.service
readonly BLACKLIST_IMAGE_NAME="edisonleeeee/blacklist_sqlite"
readonly CONTIANER_NAME="blacklist_sqlite"
readonly TARGET_PATH="/etc/sqlite/docker_sqlite_db/"
readonly BLACKLIST_SQL_NAME="blacklist.sql"
readonly BLACKLIST_DB_NAME="blacklist.db"
readonly ufw_BIN_PATH="/usr/sbin/"
readonly NORMAL_BIN_PATH="/usr/bin/"
declare -A commandN_to_installN=( ["docker"]="docker" \
	                              ["systemctl"]="systemd" \
	                              ["ufw"]="ufw")
# waiting for runtime init, global writable
PACKAGE_MANAGER=""                                   # yum or apt
OS_NAME=""                                           # centos/ubuntu

###########################################################################################

###########################################################################################
# Utility Functions
#######################################
# Return the name of running funciton
# Globals:
# Arguments:
#   None
#######################################
function func_prologue(){
  echo "--------------------------------------------"
  echo $1
  echo "Installing command $2"
  echo "--------------------------------------------"
}

###########################################################################################
#######################################
# check OS and config essential variables
# Globals:
#   PACKAGE_MANAGER
#   OS_NAME
# Arguments:
#   None
#######################################
function os_checker(){
  read_os_info="$(grep "^NAME" $"/etc/os-release" | awk -F'"' '{print $2}')"
  if [[ "$read_os_info" == "Ubuntu" ]];
  then
  	# ubuntu
  	echo "$read_os_info system!"
    PACKAGE_MANAGER="apt"
    OS_NAME="ubuntu"
  else
  	# centos
  	echo "$read_os_info system!"
    PACKAGE_MANAGER="yum"
    OS_NAME="centos"
  fi
}

#######################################
# docker install on Centos
# Globals:
# Arguments:
#   None
#######################################
function kernel_upgrade_centos(){
  uname -msr                                                                                # show current version
  yum upgrade                                                                               # update packages
  rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org                                # enable the repo
  rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm                # install the repo
  yum list available --disablerepo='*' --enablerepo=elrepo-kernel                           # listout all kernel available
  yum --enablerepo=elrepo-kernel install kernel-ml                                          # install latest kernel
  # ?????? /etc/default/grub???GRUB_DEFAULT=X -> GRUB_DEFAULT=0  ???????????????sed ???????????????
  grub2-mkconfig -o /boot/grub2/grub.cfg
}

#######################################
# docker install on Centos
# Globals:
# Arguments:
#   None
#######################################
function install_docker_centos(){
# docker engine installation
  yum remove docker \
             docker-client \
             docker-client-latest \
             docker-common \
             docker-latest \
             docker-latest-logrotate \
             docker-logrotate \
             docker-engine
  yum install -y yum-utils
  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  yum install docker-ce docker-ce-cli containerd.io
  systemctl start docker
# docker compose installation
  curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
}

#######################################
# ufw install on Centos
# Globals:
# Arguments:
#   None
#######################################
function install_ufw_centos(){
  yum install epel-release
  yum install ufw
}

#######################################
# docker install on Ubuntu
# Globals:
# Arguments:
#   None
#######################################
function install_docker_ubuntu(){
# clean the prev installation
  apt-get remove docker docker-engine docker.io containerd runc
# docker engine installation
  apt-get install \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg \
      lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get install docker-ce docker-ce-cli containerd.io
# docker compose installation
  curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
}

#######################################
# Setup ssh account and config the permission
# Globals:
#   LOGIN_ACCOUNT
#   LOGIN_SSH_PATH
#   SSH_KEY_PATH
# Arguments:
#   None
#######################################
function ssh_secure(){
# setup login account
  adduser edee                     # add new account for login only
  passwd edee                      # setup pwd
  gpasswd -a edee wheel            # add edee to wheel group
  lid -g wheel                     # check all sudoers
# /home/edee/.ssh
  if [[ ! -f $LOGIN_SSH_PATH ]]
  then
    mkdir -p $LOGIN_SSH_PATH
  fi
# /home/edee/.ssh/authorized_keys
  if [[ -f $SSH_KEY_PATH ]]
  then
    touch $SSH_KEY_PATH
  fi
# setup priviledges
  chmod g-w $LOGIN_ACCOUNT
  chmod 700 $LOGIN_SSH_PATH
  chmod 400 $SSH_KEY_PATH
  chattr +i $SSH_KEY_PATH
  chattr +i $LOGIN_SSH_PATH

# google 2FA check, [coming soon...]

# last step, lock all critical files
  lsattr /etc/passwd /etc/shadow
  chattr +i /etc/passwd /etc/shadow
  lsattr /etc/passwd /etc/shadow

# change history length
# needs to sed /etc/profile and change the number, do it later, [coming soon...]
  source $HISTORY_PATH

# change logout strategy
# needs to sed .bash_logout, and add history -c and clear
}

#######################################
# Initialize the apt/yum and make it ready
# Globals:
#   None
# Arguments:
#   None
#######################################
function package_manager_init(){
  $PACKAGE_MANAGER update
  $PACKAGE_MANAGER upgrade
}

#######################################
# Run necessary systemctl application
# Globals:
#   None
# Arguments:
#   systemctl application name
#######################################
function run_systemctl_app(){
  echo "Starting service $1"
  if [[ "$1" == "ufw.service" ]];
  then
    ufw enable
  else
    systemctl start $1
  fi
}

#######################################
# Run blacklist_sqlite image
# Globals:
#   BLACKLIST_IMAGE_NAME
#   PACKAGE_MANAGER
# Arguments:
#   1 -- systemctl (command checked)
#   2 -- systemd   (installation list if not exist)
# eg: if there is no systemctl, then you need to install
#     systemd
#######################################
function check_command_existence(){
  func_prologue ${FUNCNAME[0]} $1
  installer="install_"
  command_name=$1
  command_bin_path=""

  # [TODO] ??????????????????????????????
  if [[ $command_name == "ufw" ]];
  then
    command_bin_path="$1_BIN_PATH"             # command_bin_path???????????????????????? ?????????????????????${!command_bin_path}
  else
    command_bin_path="NORMAL_BIN_PATH"
  fi
  
  if [ ! command -v $1 &> /dev/null ] || [ ! -f ${!command_bin_path}$1 ];
  then # command doesn't exist
    #shift   # [Caution!] drop one arg
    echo "$1 could not be found"
    echo "Installing command $1..."
    shift
    if ! $PACKAGE_MANAGER install "$@";
    then
      echo "$PACKAGE_MANAGER install error, alter to specific installer!"
      installer+="${commandN_to_installN[$command_name]}"
      installer+="_"
      installer+="$OS_NAME"
      if ! $installer;                                        # here, should never use [[]], or will never literally run it
      then
        echo "Installation crapped! Abort!"
        exit 0
      else
        echo "Successful!"
      fi
    else
      echo "$PACKAGE_MANAGER installing...."
    fi
    echo "Done!!!"
  else
    echo "$SELF_DEFINED_COMMENT $1 already exits! Ready to use!"
  fi
}

#######################################
# Make ss_monitor systemctl service &
# run it as well
# Globals:
#   SS_MONITOR_PATH   -- .service path
#   SS_MONITOR_SCRIPT -- .service content
# Arguments:
#   None
#######################################
function make_ss_monitor_systemctl(){
  # config
  if [[ -f $SS_MONITOR_PATH ]]
  then
    echo "SS_MONITOR_PATH exits! Will do the writing procedure!"
  else
    echo "Creating service file..."
    touch $SS_MONITOR_PATH
    echo "Finish creating service file!"
  fi
  echo "$SS_MONITOR_SCRIPT" > $SS_MONITOR_PATH
  systemctl daemon-reload
  echo "SS_MONITOR has been added to systemctl!"
  echo "Locating at $SS_MONITOR_PATH"
  # run
  
  # systemctl start ss_monitor.service
  # should fail at this moment
  # systemctl status ss_monitor
}

#######################################
# Run blacklist_sqlite container
# Globals:
#   BLACKLIST_IMAGE_NAME
# Arguments:
#   None
#   a. path to blacklist.sql
#   b. path to blacklist.db
#   c. path to docker-entrypoint.sh
# Necessary Files:
#   1. blacklist.sql 
#   2. blacklist.db
#   3. scripts/docker-entrypoint.sh
# Notice:
# ???????????????????????????bash??????????????????????????????docker-entrypoint.sh
# ????????????????????????????????????????????? ???Dockerfile_sqlite????????????  
#######################################
function run_blacklist_sqlite_container(){
# check existence of docker image
  if [[ "$(docker images -q $BLACKLIST_IMAGE_NAME 2> /dev/null)" == "" ]];
  then
    echo "Downloading image $BLACKLIST_IMAGE_NAME..."
    docker pull $BLACKLIST_IMAGE_NAME
    echo "Finish downloading the image!"
  fi
# prepare all necessary files
  mkdir -p $TARGET_PATH
  mkdir -p $TARGET_PATH/scripts
  cp ../firewall/log_monitor.py /root/log_monitor.py
  # install all requirements
  #if [ ! apt install python3-pip ] || [ ! pip3 install pyufw ] || [ ! pip3 install docker ];
  #then
  #  echo "run_blacklist_sqlite_container abort!"
  #  exit 0
  #fi
  apt install python3-pip
  pip3 install pyufw
  pip3 install docker
  cp ../db/docker_db/blacklist.sql $TARGET_PATH/blacklist.sql
  cp ../db/docker_db/blacklist.db  $TARGET_PATH/blacklist.db
  cp ./docker-entrypoint.sh        $TARGET_PATH/scripts/docker-entrypoint.sh
# check existence of blacklist sql file
  if [ ! -f $TARGET_PATH/blacklist.sql ];
  then
    echo "blacklist.sql not found!"
    exit 1
  fi
# check existence of blacklist db file
  if [ ! -f $TARGET_PATH/blacklist.db ];
  then
    echo "blacklist.db not found!"
    exit 1
  fi
# check existence of docker-entrypoint.sh
  if [ ! -f $TARGET_PATH/scripts/docker-entrypoint.sh ];
  then
    echo "docker-entrypoint.sh not found!"
    exit 1
  fi
# run docker image
  docker run -idt \
             --restart=always \
             --name blacklist_sqlite \
             -v $TARGET_PATH/blacklist.sql:/etc/sqlite/docker_sqlite_db/blacklist.sql \
             -v $TARGET_PATH/blacklist.db:/etc/sqlite/docker_sqlite_db/blacklist.db \
             869b76e60d2a
}

#######################################
# Completly harmless to cleanup docker container [?]
# Globals:
#   $CONTAINER_NAME
# Arguments:
# Necessary Files:
#######################################
function cleanup(){
  docker stop $CONTIANER_NAME
  docker rm   $CONTIANER_NAME
}

###########################################################################################
#-----------MAIN PART (ubuntu supported currently)

# env setup
os_checker
package_manager_init
check_command_existence systemctl systemd
check_command_existence docker docker.io
check_command_existence ufw ufw
run_systemctl_app docker
make_ss_monitor_systemctl

# run services orchestration
#run_blacklist_sqlite_container
#run_systemctl_app ufw.service
#run_systemctl_app ss_monitor.service