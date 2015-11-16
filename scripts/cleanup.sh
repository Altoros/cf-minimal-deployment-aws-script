#!/usr/bin/env bash
bucket_name=${STACK_NAME}-bosh-staff
jbrelease=0

echo stack: $STACK_NAME
echo bucket: $bucket_name

read -p "DO NOT FORGET TO DELETE ALL DEPLOYMENTS! Are you sure? (y/N)" -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi


aws s3 rm s3://$bucket_name --recursive
aws cloudformation delete-stack --stack-name ${STACK_NAME}-s3bucket

  # deleting stack
echo Deleting stack
aws cloudformation delete-stack --stack-name ${STACK_NAME}
aws ec2 delete-key-pair --key-name bosh-$STACK_NAME
rm -f bosh.pem
