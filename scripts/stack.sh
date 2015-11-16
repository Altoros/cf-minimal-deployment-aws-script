#!/usr/bin/env bash
# exit on any error
set -e

bucket_name=${STACK_NAME}-bosh-staff
jbrelease=0

echo stack: $STACK_NAME
echo bucket: $bucket_name

create-bucket(){
    aws cloudformation validate-template --template-body file://templates/s3.json
    #TBD add check if bucket already exist
    aws cloudformation create-stack --capabilities CAPABILITY_IAM \
                                    --disable-rollback \
                                    --stack-name ${STACK_NAME}-s3bucket \
                                    --template-body file://templates/s3.json \
                                    --parameters ParameterKey=NameOfBucket,ParameterValue=$bucket_name
    #TBD replace it with something more smart
    sleep 40
}

upload-templates() {
  FILES="vpc.json
  security-groups.json
  jumpbox.json
  nat.json"

  for file in $FILES
  do
  	echo "Processing $file"
    aws cloudformation validate-template --template-body file://templates/$file
    aws s3 cp templates/$file s3://$bucket_name/
  done
  aws s3 cp bosh.pem s3://$bucket_name/
  aws s3 cp manifests/ s3://$bucket_name/ --recursive --include "*.yml"
}



create-stack() {
  create-bucket
  aws ec2 create-key-pair --key-name bosh-${STACK_NAME} --query 'KeyMaterial' --output text > bosh.pem
  chmod 400 bosh.pem
  upload-templates
  aws cloudformation create-stack --capabilities CAPABILITY_IAM \
                                  --disable-rollback \
                                  --stack-name $STACK_NAME \
                                  --template-body file://templates/bosh.json \
                                  --parameters ParameterKey=EnvironmentName,ParameterValue=$STACK_NAME \
                                  ParameterKey=awsAccessKeyId,ParameterValue=$AWS_ACCESS_KEY_ID \
                                  ParameterKey=awsSecretAccessKey,ParameterValue=$AWS_SECRET_ACCESS_KEY \
                                  ParameterKey=bucketName,ParameterValue=$bucket_name \
                                  ParameterKey=jbrelease,ParameterValue=$jbrelease \
                                  ParameterKey=cfRelease,ParameterValue=$CF_RELEASE \
                                  ParameterKey=KeyName,ParameterValue=bosh-${STACK_NAME} \
                                  ParameterKey=secret,ParameterValue=${SECRET}

}

update-stack() {
  upload-templates
  aws cloudformation update-stack --capabilities CAPABILITY_IAM \
                                  --stack-name $STACK_NAME \
                                  --template-body file://templates/bosh.json \
                                  --parameters ParameterKey=EnvironmentName,ParameterValue=$STACK_NAME \
                                  ParameterKey=awsAccessKeyId,ParameterValue=$AWS_ACCESS_KEY_ID \
                                  ParameterKey=awsSecretAccessKey,ParameterValue=$AWS_SECRET_ACCESS_KEY \
                                  ParameterKey=bucketName,ParameterValue=$bucket_name \
                                  ParameterKey=jbrelease,ParameterValue=$jbrelease \
                                  ParameterKey=cfRelease,ParameterValue=$CF_RELEASE \
                                  ParameterKey=KeyName,ParameterValue=bosh-${STACK_NAME} \
                                  ParameterKey=secret,ParameterValue=${SECRET}
}

case $1 in
  create ) create-stack;;
  update ) update-stack;;
  describe ) aws cloudformation describe-stacks --stack-name $STACK_NAME --output text;;
esac
