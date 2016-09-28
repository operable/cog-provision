# Cog CloudFormation Templates

This directory contains templates to provision a [Cog](https://github.com/operable/cog)
instance in Amazon Web Services.

## Quickstart

- [ ] [Create a new Slack API token](https://my.slack.com/services/new/bot).
- [ ] [Provision an RDS database](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=cog-rds&templateURL=https:%2F%2Foperable-prod-cfn-public.s3.amazonaws.com%2Flatest%2Fcog-rds.yaml).
- [ ] [Install Cog](https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=cog&templateURL=https:%2F%2Foperable-prod-cfn-public.s3.amazonaws.com%2Flatest%2Fcog.yaml).

More detailed explanations are available in the Cog Core Components and Cog RDS
Database sections below. 

## Cog Core Components: [cog.yaml](https://github.com/operable/cog-provision/blob/master/cfn-yaml/cloudformation/cog.yaml)

This template provides a Cog and Relay instance running within Docker on an
EC2 instance. The EC2 instance is managed by an auto-scaling group that
attempts to ensure that there is always a single healthy instance running.

**Requirements:**

* **VPC:** This template requires an existing VPC and subnets.
* **Slack API Token:** Cog needs a Slack API token in order to communicate
  with Slack. You can create a new one [here](https://my.slack.com/services/new/bot).
* **Postgres 9.5+:** Cog requires a Postgres database. You may either supply
  connection information or use the Cog RDS template below to create a new
  database server using Amazon RDS.
  * If you are providing your own database, you'll need to provide a database
    URL using this format:
    `ecto://<username>:<host>@<hostname>:<port>/<database_name>`.
* **Relay Shared Secret:** This is the shared secret that is used to
  manage authentication between Relay and Cog. We recommend creating a
  random string using your method of choice.

**Optional Configuration:**

* **S3 Bucket:** This CloudFormation stack uses Amazon S3 to store additional
  configuration information. You may use a prefix within an existing bucket
  by providing its name in the `CogBucketName` parameter.
* **SSL:** If you would like to use SSL with the Cog HTTP APIs you must provide
  an existing SSL certificate via the Amazon Certificate Manager service.
* **SMTP Server:** Cog requires an SMTP server in order for password reset
  email messages to be sent. If you do not care about password reset messages
  these parameters can be safely ignored.

**Outputs:**

* **CogInstanceRole:** IAM role that is associated with the Cog host. You may
  add additional policies to this role in order to provide access to AWS APIs
  for commands running on this Relay.
* **CogElbHostname:** The hostname for the ELB instance that supplies access
  to the Cog HTTP APIs. You may create a CNAME to this address if desired. If
  you create a CNAME, you should also set the `CogDnsname` parameter to match.
* **CogBucket:** S3 bucket for additional configuration. (See below)
* **CogSecurityGroup:** The VPC security group that the Cog host belongs to.
  You can use this security group to allow bundles running on the included
  relay to reach internal resources.

**Advanced: Additional Configuration:**

Any files that are stored at the configured S3 prefix under an `etc/`
subdirectory will be copied to the directory on the Cog host that
`docker-compose` is run from. This allows you to make configuration changes
to Cog for settings that are not exposed as parameters to this template.

To make these kinds of changes, we recommend creating a
`docker-compose.override.yml` file. You can read more about extending
Docker Compose configuration in the [compose documentation](https://docs.docker.com/compose/extends/).

For example, if your `CogBucketName` was set to *MyBucket* and your
`CogBucketPrefix` was set to */cog/*, you'd upload the override file to:
`s3://MyBucket/cog/etc/docker-compose.override.yml`.

## Cog RDS Database: [cog-rds.yaml](https://github.com/operable/cog-provision/blob/master/cfn-yaml/cloudformation/cog-rds.yaml)

This template can be used to supply the Postgres database that is required for
Cog with optional multi-az replication for high availability.

This template makes use of exported outputs in order to allow the Cog stack to
configure the database connection information and necessary security group
rules automatically.

**Requirements:**

* **VPC:** This template requires an existing VPC and subnets.
* **Password:** You'll need to provide a password for the RDS database user.
  We recommend generating a random password. Note that this password must be
  URL safe or you may have trouble configuring Cog to talk to it.

**Optional Configuration:**

* **Username:** The username for the RDS database user can be explicitly set
  if desired.
* **Instance Settings:** You can configure the instance type, storage size,
  backup retention age, and multi-AZ replication to meet your needs.
* **DatabaseUrlExport:** The name that the database URL will be exported under
  for use with the `Fn::ImportValue` function and cross-stack CloudFormation
  references. You only need to change this if you run more than one stack
  using this template in the same VPC.
* **SecurityGroupExport:** The name that the security group ID will be exported
  under. See `DatabaseUrlExport` above for more information on exported values.

**Outputs:**

* **CogRdsDatabase:** The Amazon RDS identifier for the database instance.
* **CogRdsDatabaseUrl:** The Ecto formatted database URL, suitable for
  use with Cog.
* **CogRdsSecurityGroup:** The security group ID for the RDS instance.
  Additional rules can be added to this security group to grant access to
  additional hosts.
