#!/bin/bash
#
# Deploy data-ingestion-job into existing commons

# See cloud-automation/doc/kube-setup-data-ingestion-job.md for information on how to use this script

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

mkdir -p $(gen3_secrets_folder)/g3auto/data-ingestion-job
credsFile="$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_ingestion_job_config.json"

if (! (g3kubectl describe secret data-ingestion-job-secret 2> /dev/null | grep config.js > /dev/null 2>&1)) \
  && [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; 
then
  gen3_log_info "kube-setup-data-ingestion-job" "setting up data-ingestion-job resources"
  gen3_log_info "initializing data-ingestion-job config.json"
  cat - > "$credsFile" <<EOM
{
  "gs_creds": {
    "type": "service_account",
    "project_id": "",
    "private_key_id": "",
    "private_key": "",
    "client_email": "",
    "client_id": "",
    "auth_uri": "",
    "token_uri": "",
    "auth_provider_x509_cert_url": "",
    "client_x509_cert_url": ""
  }, 
  "aws_creds": {
    "aws_access_key_id": "",
    "aws_secret_access_key": ""
  },
  "gcp_project_id": "",
  "github_user_email": "",
  "github_personal_access_token": "",
  "github_user_name": ""
}
EOM
  gen3 secrets sync "initialize manifestservice/config.json"
fi

PHS_ID_LIST_PATH=$(gen3_secrets_folder)/g3auto/data-ingestion-job/data-ingestion-job-phs-id-list.txt
DATA_REQUIRING_MANUAL_REVIEW_PATH=$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_requiring_manual_review.tsv
CREATE_GOOGLE_GROUPS=false

while getopts ":a:" opt; do
  case $opt in
    phs_id_list_filepath)
      if [ ! -z $OPTARG ]; then
        echo 'setting PHS_ID_LIST_PATH to $OPTARG'
        PHS_ID_LIST_PATH=$OPTARG
      fi
    \?)
    data_requiring_manual_review_filepath)
      if [ ! -z $OPTARG ]; then
        echo 'setting DATA_REQUIRING_MANUAL_REVIEW_PATH to $OPTARG'
        DATA_REQUIRING_MANUAL_REVIEW_PATH=$OPTARG
      fi
    \?)
    create_google_groups)
      if [ ! -z $OPTARG ]; then
        echo 'setting CREATE_GOOGLE_GROUPS to $OPTARG'
        CREATE_GOOGLE_GROUPS=$OPTARG
      fi
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ ! -f $PHS_ID_LIST_PATH ] 
  then echo "A file containing a list of study accessions was not found at $PHS_ID_LIST_PATH. Please provide one! Exiting."
  exit
fi

g3kubectl delete configmap phs-id-list
g3kubectl delete configmap data-requiring-manual-review

g3kubectl create configmap phs-id-list --from-file=$PHS_ID_LIST_PATH
if [ -f "$DATA_REQUIRING_MANUAL_REVIEW_PATH" ]; then
  g3kubectl create configmap data-requiring-manual-review --from-file=$DATA_REQUIRING_MANUAL_REVIEW_PATH
fi

gen3 runjob data-ingestion-job