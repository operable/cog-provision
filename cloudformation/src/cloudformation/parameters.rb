# ===========================================================================
# Parameters
# ---------------------------------------------------------------------------

##
# Required AWS Configuration
#

aws_params = %w(VpcId SubnetIds KeyName InstanceType ImageId)

parameter "VpcId",
  :Description => "VPC ID for Cog deployment",
  :Type => "AWS::EC2::VPC::Id",
  :Default => "",
  :ConstraintDescription => "must be an existing VPC"

parameter "KeyName",
  :Description => "Name of an existing EC2 KeyPair to enable SSH access",
  :Type => "AWS::EC2::KeyPair::KeyName",
  :ConstraintDescription => "must be the name of an existing EC2 KeyPair"

parameter "InstanceType",
  :Description => "Cog Host EC2 instance type",
  :Type => "String",
  :Default => "t2.medium",
  :ConstraintDescription => "must be an HVM/EBS EC2 instance type"

parameter "ImageId",
  :Description => "Cog Host AMI",
  :Type => "String",
  :Default => "ami-81365496",
  :ConstraintDescription => "must be an Ubuntu 16.04 LTS HVM/EBS AMI"

parameter "SubnetIds",
  :Description => "Comma separated list of subnets - 2 or more required for MultiAZ RDS",
  :Type => "List<AWS::EC2::Subnet::Id>",
  :Default => "",
  :ConstraintDescription => "must be a list of VPC subnet IDs"

##
# Required Cog Configuration
#

cog_config(group: :required,
           name: :cog_image,
           description: "Cog Docker Image",
           default: Cog::COG_IMAGE,
           options: { :MinLength => "1" })

cog_config(group: :required,
           name: :slack_api_token,
           description: "Slack API token",
           options: { :NoEcho => "true" })

cog_config(group: :required,
          name: :relay_image,
          description: "Relay Docker Image",
          default: Cog::RELAY_IMAGE,
          options: { :MinLength => "1" })

cog_config(group: :required,
           name: :relay_id,
           description: "UUID for Relay",
           default: "00000000-0000-0000-0000-000000000000")

cog_config(group: :required,
           name: :relay_cog_token,
           description: "Shared secret for Relay",
           options: { :NoEcho => "true" })

##
# Cog Database Selection
#

parameter "DatabaseSource",
  :Description => "Provision new RDS database or use existing external Postgres database",
  :Type => "String",
  :AllowedValues => [ "RDS", "External Database" ],
  :Default => "RDS"

condition "ProvisionRds", equal(ref("DatabaseSource"), "RDS")

##
# Cog Database (External)
#

parameter "DatabaseUrl",
  :Description => "Database connection string for external database",
  :Type => "String",
  :AllowedPattern => "^(ecto://[^:]+:[^@]+@[^/]+/.*)?$",
  :ConstraintDescription => "must be a valid Cog database URL"

parameter "CogDbSsl",
  :Description => "Use SSL to connect to Postgres",
  :Type => "String",
  :AllowedValues => %w(false true),
  :Default => "false"

##
# Cog Database (RDS)
#

rds_params = %w(RdsMasterUsername RdsMasterPassword RdsInstanceType RdsStorage RdsBackupRetention RdsMultiAZ)

parameter "RdsMasterUsername",
  :Description => "Username for Postgres admin user",
  :Type => "String",
  :Default => "cog"

parameter "RdsMasterPassword",
  :Description => "Password for Postgres admin user",
  :Type => "String",
  :NoEcho => "true"

parameter "RdsInstanceType",
  :Description => "Instance type to use for RDS database",
  :Type => "String",
  :Default => "db.m3.medium"

parameter "RdsStorage",
  :Description => "Space in GB to allocate for database storage",
  :Type => "Number",
  :Default => "20"

parameter "RdsBackupRetention",
  :Description => "Number of days to retain automatic RDS backups",
  :Type => "Number",
  :Default => "30"

parameter "RdsMultiAZ",
  :Description => "Configure multi-AZ failover HA - requires 2 or more subnet IDs to be defined",
  :Type => "String",
  :AllowedValues => %w(false true),
  :Default => "false"

##
# Cog Configuration (Bootstrap)
#

parameter "CogBootstrapInstance",
  :Description => "Configure Cog admin user automatically with bootstrap settings or manually via cogctl",
  :Type => "String",
  :Default => "automatic",
  :AllowedValues => %w(automatic cogctl)

condition "CogBootstrapInstance",
  equal(ref("CogBootstrapInstance"), "automatic")

cog_config(group: :bootstrap,
           name: :cog_bootstrap_username,
           description: "Username for initial Cog administrator",
           default: "admin")

cog_config(group: :bootstrap,
           name: :cog_bootstrap_password,
           description: "Password for initial Cog administrator",
           default: "changeme")

cog_config(group: :bootstrap,
           name: :cog_bootstrap_first_name,
           description: "First name for initial Cog administrator",
           default: "Cog")

cog_config(group: :bootstrap,
           name: :cog_bootstrap_last_name,
           description: "Last name for initial Cog administrator",
           default: "Administrator")

cog_config(group: :bootstrap,
           name: :cog_bootstrap_email_address,
           description: "Email address for initial Cog administrator",
           default: "cog@example.com")


##
# Cog Configuration (Common)
#

cog_config(group: :common,
           name: :cog_allow_self_registration,
           description: "Allow users to register themselves with Cog",
           default: "false",
           allowed: %w(false true)
)

##
# Cog Configuration (Host Information)
#

cog_config(group: :host,
           name: :cog_api_url_host,
           description: "Hostname or IP for Cog API endpoint - defaults to ELB hostname")

cog_config(group: :host,
           name: :cog_api_url_port,
           description: "Port for Cog API endpoint",
           default: "4000")

cog_config(group: :host,
           name: :cog_trigger_url_base,
           description: "Base URL for Cog Trigger endpoint")

cog_config(group: :host,
           name: :cog_trigger_url_host,
           description: "Hostname or IP for Cog Trigger endpoint - defaults to ELB hostname")

cog_config(group: :host,
           name: :cog_trigger_url_port,
           description: "Port for for Cog Trigger endpoint",
           default: "4001")

cog_config(group: :host,
           name: :cog_service_url_base,
           description: "Base URL for Cog Service endpoint")

cog_config(group: :host,
           name: :cog_service_url_host,
           description: "Hostname or IP for for Cog Service endpoint - defaults to ELB hostname")

cog_config(group: :host,
           name: :cog_service_url_port,
           description: "Port for for Cog Service endpoint",
           default: "4002")

##
# Cloudformation UI Metadata
#

aws_labels = {
  "VpcId" => { "default" => "* VPC ID" },
  "KeyName" => { "default" => "* EC2 SSH Keypair" },
  "InstanceType" => { "default" => "* EC2 Instance Type" },
  "ImageId" => { "default" => "* EC2 AMI" },
  "SubnetIds" => { "default" => "* VPC Subnet IDs" },
  "RdsMasterUsername" => { "default" => "RDS Username" },
  "RdsMasterPassword" => { "default" => "RDS Password" },
  "RdsInstanceType" => { "default" => "DB Instance Type" },
  "RdsStorage" => { "default" => "Storage (GB)" },
  "RdsBackupRetention" => { "default" => "Backup Retention (Days)" },
  "RdsMultiAZ" => { "default" => "Multi-AZ HA" }
}

cog_labels = {
  "CogImage" => { "default" => "* Cog Docker Image" },
  "SlackApiToken" => { "default" => "* Slack API Token" },
  "RelayImage" => { "default" => "* Relay Docker Image" },
  "RelayId" => { "default" => "* Relay UUID" },
  "RelayCogToken" => { "default" => "* Relay Secret" },
  "DatabaseSource" => { "default" => "* Database Source" },
  "DatabaseUrl" => { "default" => "Database URL" },
  "CogDbSsl" => { "default" => "Use SSL" },
  "CogBootstrapInstance" => { "default" => "* Bootstrap Method" },
  "CogAllowSelfRegistration" => { "default" => "* Self Registration" }
}

bootstrap_labels = Hash[
  groups[:bootstrap].map do |param|
    [ param, { "default" => param.gsub(/CogBootstrap/, "").gsub(/(\w)([A-Z])/, "\\1 \\2") }]
  end.compact]

host_labels = Hash[
  groups[:host].map do |param|
    [ param, { "default" => param.gsub(/Cog/, "").gsub("Api", "API").gsub(/Url/, " ") }]
  end.compact]

cog_bootstrap = parameter_group(:bootstrap, "Cog Config (Bootstrap)")
cog_bootstrap[:Parameters].unshift("CogBootstrapInstance")

metadata "AWS::CloudFormation::Interface",
  :ParameterGroups => [
    {
      :Label => { "default" => "AWS Global Configuration" },
      :Parameters => aws_params
    },
    {
      :Label => { "default" => "Database Source" },
      :Parameters => %w(DatabaseSource)
    },
    {
      :Label => { "default" => "Database Configuration: External (Skip for RDS)" },
      :Parameters => %w(DatabaseUrl CogDbSsl)
    },
    {
      :Label => { "default" => "Database Configuration: RDS (Skip for External)" },
      :Parameters => rds_params
    },
    parameter_group(:required, "Cog Config (Required)"),
    cog_bootstrap,
    parameter_group(:common, "Cog Config (Frequently Updated)"),
    parameter_group(:host, "Cog Config (Host Settings)")
  ],
  :ParameterLabels => aws_labels.merge(cog_labels).merge(bootstrap_labels).merge(host_labels)
