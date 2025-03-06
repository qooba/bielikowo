region          = "eu-north-1"
key_name       = "bielik-key"

# CHECK UBUNTU AMI ID FOR THE SELECTED REGION
# aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" --query "Images[*].[ImageId,CreationDate]" --region eu-north-1 --output text | sort -k2 -r | head -n 1
ami_id         = "ami-0e1e3f09a53becce1"
ebs_volume_size = 50

# CHECK SPOT PRICE FOR THE INSTANCE TYPE
# aws ec2 describe-spot-price-history --instance-types g4dn.xlarge --product-descriptions "Linux/UNIX" --region eu-north-1 --query "SpotPriceHistory[*].[InstanceType, SpotPrice, Timestamp]" --output table
spot_price     = "0.17"