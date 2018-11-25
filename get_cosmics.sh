#!/bin/bash

## Carrie Ganote
#  November 2018
#  
## Cosmic download helper

read -r -d '' usage <<EOF

Description:
  Get cosmic files from the web and download them to your current directory or to your $RESOURCE_LIB directory.

Usage: 
  bash getcosmics.sh [-hg19 || -h || ?]
  
  the -hg19 flag downloads the GRCh37 (Hg19) version of the human genome instead of the default GRCh38 version. The hg19 version is older but still in use.

Environment variables:
  Cosmic's licensing prevents us from distributing these files for you; you must provide your own login credentials for cosmic in order to access the download features in this script.
  Provide the environment variable named COSMIC_CREDS to automate login. It should be a string that contains your login email address for cosmic, followed by a colon (:) with no spaces, followed by your password. For example, in bash:
  export COSMIC_CREDS="youremail@example.com:mySUperSecurePassword"

  If you prefer, you may instead set the environment variable COSMIC_64 that is the previous string but passed through the base64 function. For example, in bash:
  export COSMIC_64=$(echo "youremail@example.com:mySUperSecurePassword" | base64)
  Note that base64 isn't real security, it just masks the plain text. Root users can always get your environment variables.

  Setting RESOURCE_LIB to a directory path will instruct this script to place the cosmic files into the folder $RESOURCE_LIB/cosmic.

EOF

# Set the file(s) to download
files="https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v87/CosmicMutantExport.tsv.gz https://cancer.sanger.ac.uk/cosmic/file_download/GRCh38/cosmic/v87/VCF/CosmicCodingMuts.vcf.gz"

if [ $1 ]; then
    if [ $1 == "-h" ]; then
	echo "$usage"
	exit 0
    elif [ $1 == "?" ]; then
	echo "$usage"
	exit 0
    elif [ $1 == "-hg19" ]; then
# Versions for HG19
	echo "Running version hg 19 of the human genome"
	files="https://cancer.sanger.ac.uk/cosmic/file_download/GRCh37/cosmic/v87/CosmicMutantExport.tsv.gz https://cancer.sanger.ac.uk/cosmic/file_download/GRCh37/cosmic/v87/VCF/CosmicCodingMuts.vcf.gz"
    fi
else
    echo "Running version GRch38 of the human genome"
fi

# Check for resource lib
if [ -n "${RESOURCE_LIB}" ]; then
    echo "Resource lib found at $RESOURCE_LIB."
    prefix="${RESOURCE_LIB}/cosmic/"
    mkdir -p $prefix 
fi

function getAuth {
    # Remember, Bash variables are all global =(
    if [ -n "$hash" ] && ! [ $fail ]; then
	return
    elif [ -n "${COSMIC_CREDS}" ] && ! [ $fail ]; then
	echo "Found cosmic credentials."
	hash=$(echo $COSMIC_CREDS | base64)
    elif [ -n "${COSMIC_64}" ] && ! [ $fail ]; then
	echo "Found cosmic 64."
	hash=$COSMIC_64
    else
	# Handy: https://stackoverflow.com/questions/3980668/how-to-get-a-password-from-a-shell-script-without-echoing
	# Read Password
	echo -n "Please enter your Cosmic Username (email): " 
	read username
	echo $username
	
	echo -n Password: 
	read -s password
	echo
	str="${username}:${password}"
	hash=$(echo $str | base64)
    fi
}

# Run Command

#ret='{ "url" : "https://cog.sanger.ac.uk/cosmic/GRCh38/cosmic/v85/classification.csv?AWSAccessKeyId=KFGH85D9KLWKC34GSl88&Expires=1521726406&Signature=Jf834Ck0%8GSkwd87S7xkvqkdfUV8%3D"} '

for file in $files; do
    # Start with authentication. Give the user 3 tries to get it right.
    i=1
    fail=
    while [ $i -lt 5 ]; do
	echo "Authorizing download $file"
	getAuth
	ret=$(curl -H "Authorization: Basic $hash" $file)
	# Instead of perl this time, doing bash substring check
	# https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
	echo $ret
        echo $ret | grep -e "ot authori" -e "Error" -e "error"
	ec=$?
	echo "Grep for not auth exited with $ec"
	if [ $ec -eq 0 ] ; then

	    echo "Attempt $i of 3: Something went wrong with the password provided. Hash: $hash"
	    i=$(( $i + 1))
	    fail=true
	else
	    echo "Success!"
	    fail=
	    break
	fi
    done

    if [ $fail ]; then
	echo "Too many auth failures, quitting."
	exit 1
    fi
    #echo $ret 
    lin=$(echo $ret | grep '"url"')
    #echo "found line with url: $lin"
    url=$(echo $lin | perl -p -e 's/.*"url".*:.*"([^"]+)".*/$1/' )
    echo "url is $url"
    #Remove the http://......./ from the file name
    basename=${file##*/}
    echo "Writing file $basename to ${prefix}${basename}"

    curl -o ${prefix}${basename}  $url
done
