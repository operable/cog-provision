# Cog Provisioning Support

This repository contains supporting tools and artifacts for provisioning and
managing the infrastructure to support a Cog installation.

## AWS CloudFormation

A template for Amazon Web Services CloudFormation service is available in
`cloudformation/template.json`. The template will provision a fully operational
Cog installation.

**Features:**
* Cog Host: EC2 Instance
  * Operating System: Ubuntu 16.04 LTS
  * Docker configured to run official Cog and Relay images
  * Autoscaling group to replace the instance on failure
  * ELB routing for Cog admin, services, and trigger APIs
  * Predefined IAM role and instance profile that you can attach your own policies to
* Bring your own Postgres database or automatically provision a Postgres RDS instance with optional support for multi-AZ failover.
* Manage Cog configuration variables as CloudFormation parameters.

**Requirements:**
* Existing VPC with at least one subnet (2+ recommended for HA)
* An existing EC2 keypair
* Slack API Token
* To configure Relay/Cog communication you'll need to generate and provide the following:
  * Relay ID: Type 4 UUID to automatically configure Relay (see: `uuidgen(1)`)
  * Relay Token: Shared secret for authentication

**Notes:**

* If you update the Cog configuration options in your CloudFormation stack, you need to update the EC2 instance with them as well. The easiest way to do this is to terminate the instance and let the autoscaling group replace it.
* The template is built using a Ruby DSL. You can regenerate it using a provided Rake task:

```
$ cd cloudformation
$ bundle install --path .bundle
$ rake cfn:write[template.json]
```
