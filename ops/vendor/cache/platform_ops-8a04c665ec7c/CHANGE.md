## 1.3.x
- Added blue/green deployment.
- Fixed bug in unused CIDR block calculator.
- Added rake task for finding available cidr blocks in a vpc.
- Can pass in optional `instance_type` for JumpBox. Default is changed from c4.large to t2.medium
- Fixed a bug that tfshell will remove the encrypted_state file if original state file does not exists. It should do nothing in this case.
- Can pass in optional `iam_instance_profile` to ami_builder.

## 1.2.x

- Jump box interface has changed. Please review your client code.
  * If you use the updated terraform module which removes ssh access from within VPC to app instances (https://github.com/MYOB-Technology/platform-terraform/commit/6ea7c45335e799d234002bf029743db2eadbd1e3), then you need to update to this version of Jump box to work with it. Specifically, you need to declare explicitly what security groups you want the jump box to have access to. An example can be seen here. https://github.com/MYOB-Technology/timesheet/blob/35677f3df1a18e94eb947ce914158df20f570f58/ops/tasks/jump.yml#L9-L12
- Added `launch_permission` option to AmiBuilder. So that you can share the built AMI with another AWS account, e.g. between `development` and `production` accounts.
- Updated ami_builder and jump_box to use ssh_authorized_keys in user_data to avoid rebooting
- Supported assume_role_credentials in all AWS client config
- Added EIP association support for Jump box, if you provide `eip_allocation_id` as option.
- Fixed a bug where destroying Jump box does not does not all resources due to paging behaviour in ec2.describe_tags
- Destroying a Jump box will now first untag the EC2 instance so that it won't be searchable by tag even if it's terminated.
- Added `ingress_cidrs` to Jump box
- Added `ssh_poll_private_ip` to Jump box to poll on private ip instead of public ip. Useful when polling from inside the VPC.
- Added db_container for setting up local database container.

## 1.1.x

- Switch to use `rewrite` branch of `aws_helpers`. Please change your project's `Gemfile` to point to `rewrite` branch to avoid version conflicts.
- Added a `Vagrantfile` to quickly set up a Ruby environment for running Platform Ops. You are encouraged to copy the `Vagrantfile` to your project and add more project specific stuff there.
- Added `SnapshotCleaner` to clean unused snapshots. This is needed if you manually deregister an AMI from AWS Console. The snapshots will remain in AWS and cost you money. Use this tool to clean them up. Alternatively, use `aws_helpers`'s `image_delete` to delete AMI, which will delete the associated snapshots as well.
