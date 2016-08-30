# ---------------------------------------------------------------------------
# ELB Configuration
# ---------------------------------------------------------------------------

resource "CogElbSecurityGroup",
  :Type => "AWS::EC2::SecurityGroup",
  :Properties => {
    :GroupDescription => "Cog Load Balancer",
    :VpcId => ref("VpcId"),
    :Tags => [
      {
        :Key => "Name",
        :Value => "cog-elb"
      }
    ]
  }

resource "CogElbEgressAny", :Type => "AWS::EC2::SecurityGroupEgress", :Properties => {
  :GroupId => ref("CogElbSecurityGroup"),
  :FromPort => -1,
  :ToPort => -1,
  :IpProtocol => -1,
  :CidrIp => "0.0.0.0/0"
}

resource "CogElbIngressICMP", :Type => "AWS::EC2::SecurityGroupIngress", :Properties => {
  :GroupId => ref("CogElbSecurityGroup"),
  :FromPort => -1,
  :ToPort => -1,
  :IpProtocol => 1,
  :CidrIp => "0.0.0.0/0"
}

resource "CogElbIngressAPI", :Type => "AWS::EC2::SecurityGroupIngress", :Properties => {
  :GroupId => ref("CogElbSecurityGroup"),
  :FromPort => 80,
  :ToPort => 80,
  :IpProtocol => 6,
  :CidrIp => "0.0.0.0/0"
}

resource "CogElbIngressServices", :Type => "AWS::EC2::SecurityGroupIngress", :Properties => {
  :GroupId => ref("CogElbSecurityGroup"),
  :FromPort => 4001,
  :ToPort => 4001,
  :IpProtocol => 6,
  :CidrIp => "0.0.0.0/0"
}

resource "CogElbIngressTriggers", :Type => "AWS::EC2::SecurityGroupIngress", :Properties => {
  :GroupId => ref("CogElbSecurityGroup"),
  :FromPort => 4002,
  :ToPort => 4002,
  :IpProtocol => 6,
  :CidrIp => "0.0.0.0/0"
}

resource "CogElb",
  :Type => "AWS::ElasticLoadBalancing::LoadBalancer",
  :Properties => {
    :CrossZone => true,
    :HealthCheck => {
      :Target => "HTTP:4000/v1/bootstrap",
      :HealthyThreshold => "3",
      :UnhealthyThreshold => "5",
      :Interval => "10",
      :Timeout => "5"
    },
    :Subnets => ref("SubnetIds"),
    :SecurityGroups => [ ref("CogElbSecurityGroup") ],
    :Listeners => [
      {
        :InstancePort => "4000",
        :InstanceProtocol => "HTTP",
        :LoadBalancerPort => "80",
        :Protocol => "HTTP"
      },
      {
        :InstancePort => "4001",
        :InstanceProtocol => "HTTP",
        :LoadBalancerPort => "4001",
        :Protocol => "HTTP"
      },
      {
        :InstancePort => "4002",
        :InstanceProtocol => "HTTP",
        :LoadBalancerPort => "4002",
        :Protocol => "HTTP"
      }
    ],
    :Tags => [
      {
        :Key => "Name",
        :Value => "cog"
      }
    ]
  }

output "CogElbHostname", :Value => get_att("CogElb", "DNSName")

# ---------------------------------------------------------------------------
# Instance Configuration
# ---------------------------------------------------------------------------

resource "CogInstanceSecurityGroup", :Type => "AWS::EC2::SecurityGroup", :Properties => {
  :GroupDescription => "Cog Security Group",
  :VpcId => ref("VpcId"),
  :Tags => [
    {
      :Key => "Name",
      :Value => "cog-instance"
    }
  ]
}

output "CogSecurityGroup", :Value => get_att("CogInstanceSecurityGroup", "GroupId")

resource "CogInstanceEgressAny", :Type => "AWS::EC2::SecurityGroupEgress", :Properties => {
  :GroupId => ref("CogInstanceSecurityGroup"),
  :FromPort => -1,
  :ToPort => -1,
  :IpProtocol => -1,
  :CidrIp => "0.0.0.0/0"
}

resource "CogInstanceIngressICMP", :Type => "AWS::EC2::SecurityGroupIngress", :Properties => {
  :GroupId => ref("CogInstanceSecurityGroup"),
  :FromPort => -1,
  :ToPort => -1,
  :IpProtocol => 1,
  :CidrIp => "0.0.0.0/0"
}

resource "CogInstanceIngressSSH", :Type => "AWS::EC2::SecurityGroupIngress", :Properties => {
  :GroupId => ref("CogInstanceSecurityGroup"),
  :FromPort => 22,
  :ToPort => 22,
  :IpProtocol => 6,
  :CidrIp => "0.0.0.0/0"
}

resource "CogInstanceIngressAPIs", :Type => "AWS::EC2::SecurityGroupIngress", :Properties => {
  :GroupId => ref("CogInstanceSecurityGroup"),
  :FromPort => 4000,
  :ToPort => 4002,
  :IpProtocol => 6,
  :SourceSecurityGroupId => ref("CogElbSecurityGroup")
}

resource "CogInstanceProfile",
  :Type => "AWS::IAM::InstanceProfile",
  :Properties => {
    :Path => "/cog/",
    :Roles => [ ref("CogInstanceRole") ]
  }

resource "CogInstanceRole",
  :Type => "AWS::IAM::Role",
  :Properties => {
    :AssumeRolePolicyDocument => {
      :Version => "2012-10-17",
      :Statement => [
        {
          :Effect => "Allow",
          :Principal => {
            :Service => [ "ec2.amazonaws.com" ]
          },
          :Action => [ "sts:AssumeRole" ]
        }
      ]
    },
    :Path => "/cog/"
  }

output "CogInstanceRole", :Value => get_att("CogInstanceRole", "Arn")

resource "CogAsg",
  :Type => "AWS::AutoScaling::AutoScalingGroup",
  :Properties => {
    :VPCZoneIdentifier => ref("SubnetIds"),
    :DesiredCapacity => 1,
    :HealthCheckType => "EC2", # ELB ...
    :HealthCheckGracePeriod => 300,
    :LaunchConfigurationName => ref("CogAsgLaunchConfig"),
    :LoadBalancerNames => [ ref("CogElb") ],
    :MaxSize => 1,
    :MinSize => 1

  }
resource "CogAsgLaunchConfig",
  :Type => "AWS::AutoScaling::LaunchConfiguration",
  :Properties => {
    :AssociatePublicIpAddress => true,
    :IamInstanceProfile => ref("CogInstanceProfile"),
    :ImageId => ref("ImageId"),
    :KeyName => ref("KeyName"),
    :InstanceType => ref("InstanceType"),
    :SecurityGroups => [ ref("CogInstanceSecurityGroup") ],
    :UserData => base64(join("",
      File.read(File.join(File.dirname(__FILE__), "..", "cloud-config")),
      "  - cfn-init -s ", ref("AWS::StackName"), " -r CogAsgLaunchConfig\n"
    ))
  },
  :Metadata => {
    "AWS::CloudFormation::Init" => {
      "configSets" => {
        "default" => [ "setup_paths", "configure", "run" ]
      },
      "setup_paths" => {
        "commands" => {
          "create_cog_home" => {
            "command" => "mkdir -m 0700 -p /opt/cog",
          }
        }
      },
      "configure" => {
        "files" => {
          "/opt/cog/.env" => {
            "content" => join("",
              "COG_IMAGE=", ref("CogImage"), "\n",
              "SLACK_API_TOKEN=", ref("SlackApiToken"), "\n",
              "DATABASE_URL=",
                fn_if("ProvisionRds",
                  join("", "ecto://", ref("RdsMasterUsername"), ":", ref("RdsMasterPassword"), "@", get_att("RdsDatabase", "Endpoint.Address"), ":", get_att("RdsDatabase", "Endpoint.Port"), "/cog"),
                  ref("DatabaseUrl")), "\n",
              "COG_ALLOW_SELF_REGISTRATION=", ref("CogAllowSelfRegistration"), "\n",
              fn_if("CogBootstrapInstance",
                join("",
                  "COG_BOOTSTRAP_EMAIL_ADDRESS=", ref("CogBootstrapEmailAddress"), "\n",
                  "COG_BOOTSTRAP_FIRST_NAME=", ref("CogBootstrapFirstName"), "\n",
                  "COG_BOOTSTRAP_LAST_NAME=", ref("CogBootstrapLastName"), "\n",
                  "COG_BOOTSTRAP_PASSWORD=", ref("CogBootstrapPassword"), "\n",
                  "COG_BOOTSTRAP_USERNAME=", ref("CogBootstrapUsername"), "\n"),
                ""),
              "COG_API_URL_HOST=",
                fn_if("CogApiUrlHostEmpty",
                  get_att("CogElb", "DNSName"),
                  ref("CogApiUrlHost")), "\n",
              "COG_API_URL_PORT=", ref("CogApiUrlPort"), "\n",
              "COG_SERVICE_URL_BASE=", ref("CogServiceUrlBase"), "\n",
              "COG_SERVICE_URL_HOST=",
                fn_if("CogServiceUrlHostEmpty",
                  get_att("CogElb", "DNSName"),
                  ref("CogServiceUrlHost")), "\n",
              "COG_SERVICE_URL_PORT=", ref("CogServiceUrlPort"), "\n",
              "COG_TRIGGER_URL_BASE=", ref("CogTriggerUrlBase"), "\n",
              "COG_TRIGGER_URL_HOST=",
                fn_if("CogTriggerUrlHostEmpty",
                  get_att("CogElb", "DNSName"),
                  ref("CogTriggerUrlHost")), "\n",
              "COG_TRIGGER_URL_PORT=", ref("CogTriggerUrlPort"), "\n",
              "RELAY_ID=", ref("RelayId"), "\n",
              "RELAY_IMAGE=", ref("RelayImage"), "\n",
              "RELAY_COG_TOKEN=", ref("RelayCogToken"), "\n"
            ),
            "mode" => "0600",
            "owner" => "root",
            "group" => "root"
          },
          "/opt/cog/docker-compose.yml" => {
            "content" => File.read(File.join(File.dirname(__FILE__), "..", "docker-compose.yml")),
            "mode" => "0600",
            "owner" => "root",
            "group" => "root"
          }
        }
      },
      "run" => {
        "commands" => {
          "docker_start" => {
            "command" => "/usr/local/bin/docker-compose up -d",
            "cwd" => "/opt/cog"
          }
        }
      }
    }
  }
