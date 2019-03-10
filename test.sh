#!/bin/bash

DIALOG_CANCEL=1
DIALOG_NO=1
DIALOG_ESC=255
CURRENT_USER=$(whoami)

awskeyfile=""
awsprofile=""
awsregion=""
awsoutput=""

display_result() {
	dialog 	--title "$1" \
			--no-collapse \
			--msgbox "$result" 0 0
}

display_openvpn() {
	cmd=$(service openvpn restart)
	dialog 	--title "Restarting OpenVPN" \
			--no-collapse \
			--msgbox "$cmd" 0 0
}

display_pass_change() {
	exec 3>&1
	dialog 	--title "Change password for $CURRENT_USER" \
			--no-collapse \
			--inputbox "Type new password" 0 0 2> /tmp/inputbox.tmp.$$		
	exit_status=$?
	exec 3>&-
	
	if [ "$exit_status" -eq $DIALOG_CANCEL ]; then
		return
	elif [ "$exit_status" -eq $DIALOG_ESC ]; then
		return
	else
		user_input=$(cat /tmp/inputbox.tmp.$$)
		rm -f /tmp/inputbox.tmp.$$
			
		echo $CURRENT_USER:$user_input | sudo chpasswd
		  
		result=$(echo "Password changed for user: $CURRENT_USER")
		display_result "Password changed"
		
	fi
}

display_aws_config() {
		exec 3>&1
		VALUES=$(dialog --ok-label "Submit" \
			  --title "Configure AWS CLI" \
			  --form "Add Info" \
			15 90 0 \
			"KeyFile Full Path:"		1 1 "$awskeyfile" 	1 20 60 0 \
			"User/Profile:"    			2 1	"$awsprofile"   2 20 60 0 \
			"AWS Region:"   			3 1	"$awsregion"  	3 20 60 0 \
			"Output type:"    			4 1	"$awsoutput" 	4 20 60 0 \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-
		
		if [ "$exit_status" -eq $DIALOG_CANCEL ]; then
			return
		elif [ "$exit_status" -eq $DIALOG_ESC ]; then
			return
		else
		
			awskeyfile=$(echo $VALUES | cut -d " " -f 1)
			awsprofile=$(echo $VALUES | cut -d " " -f 2)
			awsregion=$(echo $VALUES | cut -d " " -f 3)
			awsoutput=$(echo $VALUES | cut -d " " -f 4)
			
			mkdir -p ~/.aws

			AWS_ACCESS_KEY=$(cat $awskeyfile | grep Access | cut -d "=" -f 2)
			AWS_SECRET_KEY=$(cat $awskeyfile | grep Secret | cut -d "=" -f 2)

			{
				echo [$awsprofile]
				echo region = $awsregion
				echo output = $awsoutput
			} > ~/.aws/config
			
			{
				echo [$awsprofile]
				echo aws_access_key_id = $AWS_ACCESS_KEY
				echo aws_secret_access_key = $AWS_SECRET_KEY
			} > ~/.aws/credentials
			
			result=$(aws s3 ls)
			display_result "AWS Connection check"
		fi
}

display_kinesis() {

		region=$(aws configure list | grep region | awk '{print $2}')
		
		exec 3>&1
		dialog --stdout --title "Create Kinesis Stream" \
		--yesno "Do you want to create a Kinesis Stream with the following details:\n\n
		Hostname: $HOSTNAME\n
		Region: $region\n" 10 60
		dialog_status=$?
		exec 3>&-
		
		
		if [ "$dialog_status" -eq $DIALOG_NO ]; then
			 return
		elif [ "$dialog_status" -eq $DIALOG_ESC ]; then
			return
		else
			stream_name=aws-kinesis-$region-$HOSTNAME
			aws kinesis create-stream --stream-name $stream_name --shard-count 1
			
			result=$(aws kinesis describe-stream --stream-nam $stream_name)
			display_result "Kinesis Stream"
		fi
		
		
}

while true; do
  exec 3>&1
  selection=$(dialog \
    --title "Menu" \
    --clear \
    --cancel-label "Exit" \
	--ok-label "Select" \
    --menu "What do you want to do:" 0 0 6 \
    "1" "Configure Networking" \
    "2" "Restart OpenVPN" \
    "3" "Change Your Password" \
	"4" "Configure AWS CLI" \
	"5" "Create Kinesis Stream" \
    2>&1 1>&3)
  exit_status=$?
  exec 3>&-
  case $exit_status in
    $DIALOG_CANCEL)
      clear
      echo "Bye Bye :(."
      exit
      ;;
    $DIALOG_ESC)
      clear
      echo "Program aborted." >&2
      exit 1
      ;;
  esac
  case $selection in
    0 )
		clear
		echo "Program terminated."
		;;
    1 )
		nmtui
		;;
    2 )
		display_openvpn
		;;
    3 )
		display_pass_change 
		;;
	4 )
		display_aws_config	  
		;;
	5 )
		display_kinesis
		;;
  esac
done
