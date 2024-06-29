#!/bin/bash
#########################################################################################
# User cloning script                                           		#
# Version 1.0                                                                 		#
#                                                                             		#
#This script creates a new user based on an existing user in a multi-user environment.	#
#It provides features for creating the user, assigning the password,			#
#adding to the appropriate groups, creating the home directory, copying configuration files,
#and managing permissions.								#
#                                                                             		#
# Options :                                                                   		#
#   -h    Display this help message							#
#	  -u    Specify the name of the user to be cloned				#
#	  -c	Specify the name of the new cloned user					#
#	  -p    Specify the password of the new cloned user				#
#	  -d    Copying user home folder to clone home folder with permissions		#
#	  -s    Run in a sub-shell
#	  -f    Run in the background using fork
#	  -l    Change log directory
#	  -r    Restore default settings.                          			#
#                                                                             		#
# Usage :                                                              			#
#   ./script.sh -u <user> -c <clone> -p <pass>                                		#
#                                                                             		#
# Author :                                                                   		#
#   [FANAOUI Ayoub] [EL HAMRI Youssef] [DIOUANE Hicham]                         	#
#                                                                             		#
# creation date : [12/05/2024]                             				#
#########################################################################################


clone_user(){

	#creating clone
	if useradd "$clone" > /dev/null 2>&1; then
    	write_to_log "Clone user $clone was created successfully." "INFO"
	else
    	echo "Failed to create clone user $clone."
    	write_to_log "Failed to create clone user $clone." "ERROR"
      	exit 110
	fi

	#adding password to clone
	if yes "$password" | passwd "$clone" > /dev/null 2>&1; then  
    	write_to_log "Added a password for clone user $clone" "INFO"
	else
    	echo "Failed to add password for clone user $clone."
    	write_to_log "Failed to add password for clone user $clone." "ERROR"
      	exit 109
	fi

	#adding clone to user's group
	if usermod -aG $(groups "$user" | cut -d' ' -f 3- | tr ' ' ',') "$clone"; then
    	write_to_log "Clone user $clone was successfully added to the user $user groups." "INFO"
	else
    	echo "Failed to add the clone user $clone to the user $user groups."
    	write_to_log "Failed to add the clone user $clone to the user $user groups." "ERROR"
      exit 108
	fi

	#creating home folder for clone
	if ! [ -d "/home/$clone" ]; then
	  mkdir /home/"$clone"
	if [ -d "/home/$clone" ]; then
        write_to_log "The home directory for the clone user $clone has been created successfully." "INFO"
    	else
        echo "Failed to create home directory for the clone user $clone."
        write_to_log "Failed to create home directory for the clone user $clone.." "ERROR"
        exit 102
    fi
  else
    write_to_log "The home directory for the clone user $clone already exists creating it was skipped." "INFO"
  fi

	#copying config files to clone home folder if the config file exists
	if [ -d "/home/$user/.config" ]; then
	  if cp -a "/home/$user/.config" "/home/$clone"; then
	    write_to_log "The .config directory from $user's home directory was successfully copied to $clone's home directory." "INFO"
	    else
	    echo "Failed to copy the .config directory from $user's home directory to $clone's home directory."
	    write_to_log "Failed to copy the .config directory from $user's home directory to $clone's home directory." "ERROR"
	    exit 104
	   fi
	  #adding permission to the copied file for clone
	  if chown -R "$clone" "/home/$clone/.config"; then
	    write_to_log "Ownership of the .config directory in $clone's home directory was successfully changed." "INFO"
	    else
	    echo "Failed to change ownership of the .config directory in $clone's home directory."
	    write_to_log "Failed to change ownership of the .config directory in $clone's home directory." "ERROR"
	    exit 103
	   fi
	 else
	    write_to_log "The .config directory from $user's home directory does not exist copying it was skipped." "INFO"
	fi

	#user cloned successfully
	echo "$user has been cloned successfully."
	write_to_log "$user was cloned successfully." "INFO"

}

change_log_directory(){
	if ! [ -d "$new_log" ]; then
	  echo "$new_log is not a valid directory."
	  write_to_log "The new log directory $new_log was not a valid directory." "ERROR"
	  exit 107
	fi

	#changing log directory in the config file and the log variable
	echo "$new_log" > "$config_file"
	log_directory=$new_log

	echo "Log directory changed to $log_directory."
	write_to_log "Log direcory was changed to $log_directory." "INFO"
}

reset_default(){
	#reseting the log directory to the default value
	echo "$default_log" > "$config_file"
	echo "Log directory has been reset to $default_log."
	write_to_log "Log direcory was reset to $default_log." "INFO"
}

copy_home_folder(){ 

if [ -z "$duplicate_home" ]; then
 return
fi

  #copying user home folder to clone home folder
  if ! cp -a /home/"$user"/. /home/"$clone" > /dev/null 2>&1;then
    echo "Failed to copy $user home folder content to $clone home folder."
    write_to_log "Failed to copy $user home folder content to $clone home folder." "ERROR"
    exit 104
  else 
    write_to_log "The home folder content for $user was successfully copied to $clone." "INFO"
  fi

  #adding permission to the copied folder for clone
  if ! chown -R "$clone" /home/"$clone" > /dev/null 2>&1;then
    echo "Failed to set permissions for clone user $clone."
    write_to_log "Failed to set permissions for clone user $clone." "ERROR"
    exit 103
  else 
    write_to_log "Permissions for the clone user $clone were successfully set." "INFO"
  fi
}

display_help() {
    cat << EOF
	Usage: $(basename "$0") [options] [arguments]

	Options:

	  -h    Display this help message
	  -u    Specify the name of the user to be cloned
	  -c	Specify the name of the new cloned user
	  -p    Specify the password of the new cloned user
	  -d    Copying user home folder to clone home folder with permissions
	  -s    Run in a sub-shell
	  -f    Run in the background using fork
	  -l    Change log directory
	  -r    Restore default settings

	Description:
	This script performs user cloning by creating a new user based on an existing one. 
EOF
   write_to_log "Help was shown." "INFO"
}

timestamp(){
	date +"%Y-%m-%d %H-%M-%S"
}

write_to_log(){
	local message=$1
	local type=$2
	echo "$(timestamp) : $current_user : $type : $message" >> "$log_file"
}

#checking if script is run as sudo
if [ "$EUID" -ne 0 ]; then
	echo "The script should be run as sudo."
	exit 101
fi

default_log="/var/log/clone"
config_file="/home/.clone_script_config"
current_user=$(whoami)

#creating the default log directory if it does not exist
if ! [ -d "$default_log" ]; then
  mkdir "$default_log"
  if ! [ -d "$default_log" ]; then
    echo "Failed to create the default log directory."
    exit 102
  fi
fiUser cloning script

#creating config file for the script if it does not exist
if ! [ -f "$config_file" ]; then
  echo "$default_log" > "$config_file"
  if ! [ -f "$config_file" ]; then
    echo "Failed to create the config file."
    exit 102
   fi
fi

log_directory=$(</"$config_file")

#checking if the log location is a valid directory if not reverting to default directory
if ! [ -d "$log_directory" ]; then
  echo "$default_log" > "$config_file"
  log_directory=$default_log
fi

log_file="$log_directory/history.log"

#checking if the log file exists if not creating it
if ! [ -f "$log_file" ]; then
  echo "$(timestamp) : $current_user : INFO : The log file was created." > "$log_file"
  if ! [ -f "$log_file" ]; then
    echo "Failed to create the log file."
    exit 102
   fi
fi


while getopts ":hfsrdu:c:p:l:" flag; do
 case $flag in
   u)    
   user=$OPTARG
   ;;
   c) 
   clone=$OPTARG
   ;;
   p)
   password=$OPTARG
   ;;
   d)
   #copy home folder
   duplicate_home=1
   ;;
   h)
   #show help 
   display_help
   exit 0
   ;;
   f)
   #run sub-proccess using fork
   run_fork=1
   ;;
   s)
   #run in a sub-shell
   run_subshell=1
   ;;
   l)
   #change log directory
   new_log=$OPTARG
   ;;
   r)
   #restore the default settings
   reset_flag=1
   ;;
   *)
   #invalid option
   cat << EOF
-$OPTARG is an invalid option
Usage: $(basename "$0") [options] [arguments] use the -h option for more info.
EOF
   write_to_log "Invalid option -$OPTARG was detected." "ERROR"
   exit 100
   ;;
 esac
done

if [ -n "$reset_flag" ]; then
  reset_default
  exit 0
fi

if [ -n "$new_log" ]; then
  change_log_directory
  exit 0
fi

if [ -z "$user" ] || [ -z "$clone" ] || [ -z "$password" ]; then
  echo "Usage: $(basename "$0") [options] [arguments] use the -h option for more info."
  write_to_log "Invalid usage was detected not all required flags were provided." "ERROR"
  exit 100
fi

find=$(getent passwd $user)
if [ -z "$find" ]; then
  echo "User $user does not exist."
  write_to_log "User $user to clone was not found." "ERROR"
  exit 105
fi


#checking if the user already exist before creating the clone
find=$(getent passwd $clone)
if [ -n "$find" ]; then
  echo "User $clone already exists."
  write_to_log "User $clone already exists name $clone cannot be used." "ERROR"
  exit 106
fi

#checking if both -f and -s are set 
if [[ -n "$run_fork" && -n "$run_subshell" ]]; then
  echo "Using both -f and -s is not allowed."
  write_to_log "Both forking and running in a sub-shell were used." "ERROR"
  exit 100
fi


#running the clonning and copying using forking
if [ -n "$run_fork" ]; then
  write_to_log "The script was run in the background using fork." "INFO"
  #clonning
  clone_user &
  #copying if the -d flag is set
  copy_home_folder &
  wait
  exit 0
fi

#running the clonning and copying using a sub-shell
if [ -n "$run_subshell" ]; then
  write_to_log "The script was run in a sub-shell." "INFO"
  (
  clone_user
  copy_home_folder
  )
  exit 0
fi

write_to_log "The script was run in the foreground." "INFO"

clone_user
copy_home_folder

