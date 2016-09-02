# ===========================================================================
# RDS Setup
# ---------------------------------------------------------------------------

resource "RdsSubnetGroup",
  :Type => "AWS::RDS::DBSubnetGroup",
  :Condition => "ProvisionRds",
  :Properties => {
    :DBSubnetGroupDescription => "Cog Database",
    :SubnetIds => ref("InstanceSubnetIds"),
    :Tags => [
      {
        :Key => "Name",
        :Value => "cog"
      }
    ]
  }

# ---------------------------------------------------------------------------
# RDS Security Group
# ---------------------------------------------------------------------------

resource "RdsSecurityGroup",
  :Type => "AWS::EC2::SecurityGroup",
  :Condition => "ProvisionRds",
  :Properties => {
    :GroupDescription => "Cog RDS Security Group",
    :VpcId => ref("VpcId"),
    :Tags => [
      {
        :Key => "Name",
        :Value => "cog-rds"
      }
    ],
  }

resource "RdsEgressAny",
  :Type => "AWS::EC2::SecurityGroupEgress",
  :Condition => "ProvisionRds",
  :Properties => {
    :GroupId => ref("RdsSecurityGroup"),
    :FromPort => -1,
    :ToPort => -1,
    :IpProtocol => -1,
    :CidrIp => "0.0.0.0/0"
  }

resource "RdsIngressICMP",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "ProvisionRds",
  :Properties => {
    :GroupId => ref("RdsSecurityGroup"),
    :FromPort => -1,
    :ToPort => -1,
    :IpProtocol => 1,
    :CidrIp => "0.0.0.0/0"
  }

resource "RdsIngressPg",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "ProvisionRds",
  :Properties => {
    :GroupId => ref("RdsSecurityGroup"),
    :FromPort => 5432,
    :ToPort => 5432,
    :IpProtocol => 6,
    :SourceSecurityGroupId => ref("CogInstanceSecurityGroup")
  }

# ---------------------------------------------------------------------------
# RDS Datbase Setup
# ---------------------------------------------------------------------------

resource "RdsDatabase",
  :Type => "AWS::RDS::DBInstance",
  :Condition => "ProvisionRds",
  :Properties => {
    :AllocatedStorage => ref("RdsStorage"),
    :BackupRetentionPeriod => ref("RdsBackupRetention"),
    :DBName => "cog",
    :DBInstanceClass => ref("RdsInstanceType"),
    :DBSubnetGroupName => ref("RdsSubnetGroup"),
    :Engine => "postgres",
    :MultiAZ => ref("RdsMultiAZ"),
    :StorageType => "gp2",
    :VPCSecurityGroups => [ ref("RdsSecurityGroup") ],
    :MasterUsername => ref("RdsMasterUsername"),
    :MasterUserPassword => ref("RdsMasterPassword"),
    :Tags => [
      {
        :Key => "Name",
        :Value => "cog"
      }
    ]
  }

output "CogDatabaseHost",
  :Condition => "ProvisionRds",
  :Value => get_att("RdsDatabase", "Endpoint.Address")

output "CogDatabasePort",
  :Condition => "ProvisionRds",
  :Value => get_att("RdsDatabase", "Endpoint.Port")
