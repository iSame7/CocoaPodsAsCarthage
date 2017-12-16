#!/bin/bash


# github token
GithubToken="YOUR_GITHUB_TOKEN"

# Search for a pod in CocoaPods search engine
function searchForPod {
CURL='/usr/bin/curl'
podName=$1
echo "getting pod name..."
echo $podName
RVMHTTP="http://search.cocoapods.org/api/pods?query=$podName"
CURLARGS="-f -s -S -k -H Accept:application/vnd.cocoapods.org+flat.hash.json;version=1"
json="$($CURL $CURLARGS $RVMHTTP)"
echo "JSON Response"
echo ${json} | jq '.'

repoURL=$(echo ${json} | jq '.[0].source.git')
echo "repo url ...."
echo $repoURL
# combine source and binary option
combine=$2;
echo $combine
}
searchForPod $1 $2

# let's create a FORK from that repoURL
reponameToFork=$(echo $repoURL | awk -v FS="(https://github.com/|.git)" '{print $2}')
echo $reponameToFork
GITHUBAPI="https://api.github.com/repos/$reponameToFork/forks"
ARGS="-X POST -u $GithubToken:x-oauth-basic"
GithubJSON="$($CURL $ARGS $GITHUBAPI)"
echo ${GithubJSON} | jq '.'
sshURL=$(echo ${GithubJSON} | jq '.ssh_url')

# clonning remote git repo
function lazyclone {
url=$1;
reponame=$(echo $url | awk -F/ '{print $NF}' | sed -e 's/.git"//');
url=$(echo "$url" | tr -d '"')
git clone $url $reponame;
cd $reponame;
}

lazyclone $sshURL

# using carthage to create dynamic framework from .xcodeproj
carthage build --no-skip-current

cd "Carthage/Build/iOS"

# Go back to repo main directory
cd ..
cd ..
cd ..

# Create a directory called framework that hold the binary
mkdir framework

# Copy .framework from Carthage/Build/iOS directory to framwork directory
cp -R ${PWD}/Carthage/Build/iOS/$reponame.framework ${PWD}/framework
cp -R ${PWD}/Carthage/Build/iOS/$reponame.framework.dSYM ${PWD}/framework

# Change .podspec so it should contain s.ios.vendored_frameworks

if [ "$combine" = "--SourceAndBinary" ]
then
echo "Cool Beans"
sed -i '' '/source_files/c\
s.source_files = '"'""'"'
$'\n'' ./${reponame}.podspec

sed -i '' '/end/i\
s.subspec '"'"Binary"'"' do |binary| binary.vendored_frameworks = '"'"framework/${reponame}.framework"'"' end

$'\n'' ./${reponame}.podspec

sed -i '' '/end/i\
s.subspec '"'"Source"'"' do |source| source.source_files = '"'"${reponame}/${reponame}.swift"'"' end

$'\n'' ./${reponame}.podspec

else
echo "Not Cool Beans"
sed -i '' '/source_files/c\
s.source_files = '"'""'"'
$'\n'' ./${reponame}.podspec

sed -i '' '/end/i\
s.ios.vendored_frameworks = '"'"framework/${reponame}.framework"'"'

$'\n'' ./${reponame}.podspec

fi

# Remove Carthage directory
rm -r Carthage

# Commit and push .podspec and framework to remote repo
function lazyPush() {
git add .
git commit -a -m "$1"
git push
}

lazyPush "Change pod spec to support dynamic framework + add dynamic framework"
echo "Done!"
echo "Now you have a framework for this dependency, just do pod install in your project to use it"
echo "Have a good day!"

