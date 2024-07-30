#!/bin/bash
##
#  *******************************************************************************************************************************
#  * Script Name : pod-scale-up-down.sh
#  * Purpose : Generic utility to perform scale up and scale down operations for IKS pods using Argo CD setup with flexibility to customize setup
#  *           To be used by team to automate and eliminate manual effort involved in similar kind of activities
#  * Author  : Vivek Dubey(https://github.com/vivekdubeyvkd)
#  ********************************************************************************************************************************
##


#'''
#    Try it out on your pre-prod/lowers environments first before using it for production environments. 
#    You can make changes to the scripts as per your requirements and contribute back as well in case if the changes are generic.
#'''


## Script Name: pod-scale-up-down.sh
## ./pod-scale-up-down.sh e2e githuborg/githuborgrepo w2 ******************************* sd dryrun
## python3 parse-update-yaml.py git_source/manifest.yaml
## ./pod-scale-up-down.sh prd githuborg/githuborgrepo w2 ******************************* sd dryrun

## important point to note
 # Point [1]:
 # TAG_NAME is an external environment variable that is required for both scale down and scale up operations
 # please ensure that you set TAG_NAME env to correct values before running this script, you can set it as shown below:
 # export TAG_NAME=CORRECT_TAG_NAME_VALUE
 #
 # Point [2]:
 # NEW_APP_IMAGE_NAME is an external environment variable that is required for scale up operations
 # please ensure that you set NEW_APP_IMAGE_NAME env to new image to be used to update YAML file for application(s), you can set it as shown below:
 # export NEW_APP_IMAGE_NAME=YOUR_NEW_APP_IMAGE_NAME_TO_BE_USED_IN_MANIFEST_YAML_FILE


# validate user input and define env variables using user inputs that will be used later in the script
if [ $# -eq 6 ]
then
    export ENV_NAME=$1
    export GITHUB_ORG_REPO=$2
    export IKS_REGION=$3
    export GITHUB_API_TOKEN=$4
    export ACTION_TYPE=$5
    export RUNTYPE=$6
elif [ $# -eq 5 ]
then
    export ENV_NAME=$1
    export GITHUB_ORG_REPO=$2
    export IKS_REGION=$3
    export GITHUB_API_TOKEN=$4
    export ACTION_TYPE=$5
    export RUNTYPE=dryrun
else
    echo -e "\n"
    echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
    echo "Invalid user inputs, kindly check and rerun again .... exiting ...."
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Script Usage:"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "  [pod-scale-up-down.sh] [ENV NAME] [GITHUB ORG With REPO] [IKS AWS REGION] [GITHUB API TOKEN] [ACTION TYPE] [RUNTYPE]"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Input Parameters:"    
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "  ENV NAME: IKS env name e.g. e2e, qal, prd etc"
    echo "  GITHUB ORG With REPO: Deployment GitHub Org/Repo for the service e.g. githuborg/githubdeploymentrepo"
    echo "  IKS AWS REGION: IKS AWS deployment region i.e. e2 -> east 2, w2 -> west 2 etc"
    echo "  GITHUB API TOKEN: GitHub API OAuth2 TOKEN with write access to deployment repo"
    echo "  Action Type:"
    echo "          sd: scale down"
    echo "          suwm1pod: Scale up one pods with maintenance, without HorizontalPodAutoscaler and SyncJobs"
    echo "          suwmallpod: Scale up all pods with maintenance and without SyncJobs"
    echo "          su: Scale up by keeping changes from GitHub Tag as it is without SyncJobs"
    echo "  RUNTYPE: dryrun: do not commit changes, submit: commit changes to GitHub repo"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "\n"
        exit 1
fi

# validate ACTION_TYPE values
if [ "${ACTION_TYPE}" != "su" -a "${ACTION_TYPE}" != "sd" -a "${ACTION_TYPE}" != "suwmallpod" -a "${ACTION_TYPE}" != "suwm1pod" ]
then
      echo -e "\n"
      echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
      echo "Invalid ACTION_TYPE value, kindly check and rerun ..... exiting ....."
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      echo "Valid ACTION_TYPE values are:"
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      echo "        sd: scale down"
      echo "        suwm1pod: Scale up one pods with maintenance, without HorizontalPodAutoscaler and SyncJobs"
      echo "        suwmallpod: Scale up all pods with maintenance and without SyncJobs"
      echo "        su: Scale up by keeping changes from GitHub Tag as it is without SyncJobs"
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      echo -e "\n"
      exit 3    
fi

# validate RUNTYPE values
if [ "${RUNTYPE}" != "dryrun" -a "${RUNTYPE}" != "submit" ]
then
    echo -e "\n"
    echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
    echo "Invalid RUNTYPE value, kindly check and rerun ..... exiting ....."
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "Valid RUNTYPE values are:"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo " dryrun: do not commit changes, this is default value"
    echo " submit: commit changes to GitHub repo"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "\n"
    exit 3  
fi  

# validate TAG_NAME env var to ensure that it is not empty
if [ -z "${TAG_NAME}" ]
then
    echo -e "\n"
    echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
    echo "TAG_NAME environment variable is not defined but it is empty, kindly check and rerun ..... exiting ....."
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "\n"
    exit 4
fi

# validate THIS_DB_TYPE env var to ensure that it is not empty
if [ -z "${THIS_DB_TYPE}" ]
then
    if [ "${ACTION_TYPE}" = "su" -o "${ACTION_TYPE}" = "suwm1pod" -o "${ACTION_TYPE}" = "suwmallpod" ]
    then
        echo -e "\n"
        echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
        echo "THIS_DB_TYPE environment variable is not defined but it is empty, kindly check and rerun ..... exiting ....."
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo -e "\n"
        exit 5
    fi
fi


# validate appRepoOrgName env var to ensure that it is not empty
if [ -z "${appRepoOrgName}" ]
then
    if [ "${ACTION_TYPE}" = "su" -o "${ACTION_TYPE}" = "suwm1pod" -o "${ACTION_TYPE}" = "suwmallpod" ]
    then
        echo -e "\n"
        echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
        echo "appRepoOrgName environment variable is not defined but it is empty, kindly check and rerun ..... exiting ....."
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo -e "\n"
        exit 5
    fi
fi


# set git config
git config --global user.email "myuser@git.com"
git config --global user.name "myuser"

# clean up function to check and clean a directory
cleanDir () {
    inputDir=$1
    if [ -d  "${inputDir}" -o -f  "${inputDir}" ]
    then
        rm -rf "${inputDir}"
    fi
}

# checkout GitHub repo
checkoutRepo () {
    repoUrl=$1
    repoBranch=$2
    cloneDir=$3
    git clone "${repoUrl}" -b "${repoBranch}" "${cloneDir}"
}  

# validate if a file exists
fileCheck () {
    inputFile=$1
    if [ ! -f "${inputFile}" ]
    then
        echo -e "\n"
        echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
        echo "Manifest file ${inputFile} does not exist in the workspace ... kindly check and rerun .... exiting ....."
            echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            echo -e "\n"
            exit 2  
    else
        echo "Manifest file ${inputFile} exists in workspace"
    fi
}

# create GitHub Tag using env variable TAG_NAME which will be defined outside of this script
createTag () {
    cloneDir=$1
    repoOrigin=$2
    cd "${cloneDir}"
    git tag "${TAG_NAME}" "${ENV_BRANCH_NAME}" -m "Tag ${TAG_NAME} created on $(date +'%d%m%y%m') with Jenkins BUILD_NUMBER ${BUILD_NUMBER}"
    git push "${repoOrigin}" "${TAG_NAME}"
} 

# checkout GitHub Tag using env variable TAG_NAME for scale up operations
checkoutTag () {
    repoBranch=$1
    cloneDir=$2
    cd "${cloneDir}"
    git fetch origin "refs/tags/${TAG_NAME}"
    git checkout "tags/${TAG_NAME}"
    git branch -D "${repoBranch}"
    git checkout -b "${repoBranch}"
} 


# define more env variables
export ENV_BRANCH_NAME="environments/${ENV_NAME}-us${IKS_REGION}-eks"
export GITHUB_REPO_URL="https://oauth2:$GITHUB_API_TOKEN@github.com/${GITHUB_ORG_REPO}"
export MANIFEST_FILE_NAME="manifest.yaml"
export CW_DIR=$(pwd)
export GIT_CHECKOUT_DIR="${CW_DIR}/git_source"
export MNIFEST_FILE_PATH="${CW_DIR}/git_source/${MANIFEST_FILE_NAME}"
export ARGO_SYNC_TMP_FILE="${CW_DIR}/../$(echo ${appRepoOrgName}|cut -d"/" -f2|tr -s "-" "_").txt"

# display env vars
echo $ENV_BRANCH_NAME

# check and clean checkout directory
cleanDir "${GIT_CHECKOUT_DIR}"

# check and clean ARGO Sync branch name text file
cleanDir "${ARGO_SYNC_TMP_FILE}"

# check if the input branch exists on the GitHub repo
remote_branch_check=$(git ls-remote --heads "${GITHUB_REPO_URL}" "refs/heads/${ENV_BRANCH_NAME}" | wc -l)

if [ $remote_branch_check -gt 0 ]
then    
    # checkout deployment GitHub repo
    checkoutRepo "${GITHUB_REPO_URL}" "${ENV_BRANCH_NAME}" "${GIT_CHECKOUT_DIR}"

    # validate and checkout Tag in case of scale up operations
    if [ "${ACTION_TYPE}" = "su" -o "${ACTION_TYPE}" = "suwm1pod" -o "${ACTION_TYPE}" = "suwmallpod" ]
    then
        checkoutTag "${ENV_BRANCH_NAME}" "${GIT_CHECKOUT_DIR}"
        # change directory from Git clone dir to current working dir
        cd "${CW_DIR}"
    fi

    # check if manifest.yaml exists
    fileCheck "${MNIFEST_FILE_PATH}"

    # create a tag with the latest HEAD
    if [ "${RUNTYPE}" = "submit"  ]
    then
        # create a new tag with th latest only performing scale down operations
        if [ "${ACTION_TYPE}" = "sd" ]
        then
            createTag "${GIT_CHECKOUT_DIR}" "${GITHUB_REPO_URL}"
            # change directory from Git clone dir to current working dir
            cd "${CW_DIR}"
        fi
    fi

    # update manifest file
    if [ "${ACTION_TYPE}" = "sd" ]
    then
        # call script for scale down scenario
        python3 parse-update-yaml.py "${MNIFEST_FILE_PATH}" "${ACTION_TYPE}"
    else
        # call script for various scale up scenarios
        python3 parse-update-yaml.py "${MNIFEST_FILE_PATH}" "${ACTION_TYPE}" "${NEW_APP_IMAGE_NAME}"
    fi  

    # commit to the repo
    if [ "${RUNTYPE}" = "submit" ]
    then
        # define a temp timestamp
        # export TMP_TIME_STAMP=$(date +'%d%m%y%m')
        export TMP_TIME_STAMP=$(date +'%d%h%y%M%s')

        # code to commit changes in manifest XML file to repo
        cd "${GIT_CHECKOUT_DIR}"
        git add -f "${MANIFEST_FILE_NAME}"
        if [ "${ACTION_TYPE}" = "su" ]
        then
            export COMMI_MSG="updating ${MANIFEST_FILE_NAME} file for scaling up to disable maintenance, add back horizontal scaling settings ${TMP_TIME_STAMP}"
        elif [ "${ACTION_TYPE}" = "suwm1pod" ]
        then
            export COMMI_MSG="updating ${MANIFEST_FILE_NAME} file for scaling up with maintenance with just one pod ${TMP_TIME_STAMP}"
        elif [ "${ACTION_TYPE}" = "suwmallpod" ]
        then
            export COMMI_MSG="updating ${MANIFEST_FILE_NAME} file for scaling up with maintenance with all the pods ${TMP_TIME_STAMP}"          
        elif [ "${ACTION_TYPE}" = "sd" ]
        then
            export COMMI_MSG="updating ${MANIFEST_FILE_NAME} file for scaling down to enable maintenance, bring down pod count to 0, disable hooks ${TMP_TIME_STAMP}"
        fi  

        # commit the changes
        git commit -m "${COMMI_MSG}"

        # create a temp branch and check in Mnaifest YAML file changes to that temp branch
        export TMP_BRANCH_NAME="environments/tmp-${ENV_NAME}-us${IKS_REGION}-eks-${TMP_TIME_STAMP}"
            git checkout -b "${TMP_BRANCH_NAME}"
            git push "${GITHUB_REPO_URL}" "${TMP_BRANCH_NAME}"

        # save commit sha from temp branch HEAD in a text file under workspace to be used at the time of argo sync
        export COMMIT_SHA_VAL=$(git log -n 1 --pretty=format:%H)
        echo "${COMMIT_SHA_VAL}" > "${ARGO_SYNC_TMP_FILE}"
        echo "ARGO_SYNC_TMP_FILE details for ${appRepoOrgName} : ${ARGO_SYNC_TMP_FILE}"
    fi

    if [ "${RUNTYPE}" = "submit" ]
    then
        #create PR from tempp branch to input branch
        export GITHUB_USER=myuser
        export GITHUB_API_URL="https://github.com/api/v3/repos/${GITHUB_ORG_REPO}/pulls"

        # call GitHub rest API to create the PR
        curl -u "$GITHUB_USER:$GITHUB_API_TOKEN" -s -X POST  -d "{\"head\":\"${TMP_BRANCH_NAME}\",\"base\":\"${ENV_BRANCH_NAME}\", \"title\": \"${COMMI_MSG}\"}" "${GITHUB_API_URL}" > pr.json

        if [ -f "pr.json" ]
        then
            # print the new PR URL on console
            check_html_url_count=$(cat "pr.json"| grep -c html_url)
            if [ ${check_html_url_count} -gt 0 ]
            then
                echo -e "\n"
                cat "pr.json"| grep html_url|grep pull |tr -d '",'|sed 's#html_url#New PR URL#g'
                echo -e "\n"
            else
                echo -e "\n"
                echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"          
                echo "PR creation failed, error details are shared below"
                echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"      
                cat "pr.json"
                echo "++++++++++++++++++++++++++++++++++++++ ERROR ++++++++++++++++++++++++++++++++++++++"
                echo -e "\n"
            fi
        fi
    fi 
else
    echo -e "\n"
    echo "++++++++++++++++++++++++++++++++++++++ INFO ++++++++++++++++++++++++++++++++++++++"
    echo "Branch ${ENV_BRANCH_NAME} does not exists on the remote repo"
    echo "++++++++++++++++++++++++++++++++++++++ INFO ++++++++++++++++++++++++++++++++++++++"
    echo -e "\n"    
fi
