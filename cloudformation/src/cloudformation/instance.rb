# ---------------------------------------------------------------------------
# S3 Bucket - Used for logs and advanced configuration.
# ---------------------------------------------------------------------------

resource "CogBucket",
  :Type => "AWS::S3::Bucket",
  :Properties => {
    :VersioningConfiguration => { :Status => "Enabled" },
    :Tags => [
      {
        :Key => "Name",
        :Value => "cog"
      }
    ]
  }

output "CogBucket", :Value => ref("CogBucket")

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

resource "CogElbEgressAny",
  :Type => "AWS::EC2::SecurityGroupEgress",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => -1,
    :ToPort => -1,
    :IpProtocol => -1,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressICMP",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => -1,
    :ToPort => -1,
    :IpProtocol => 1,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressAPI",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "SslDisabled",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 80,
    :ToPort => 80,
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressAPISsl",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "SslEnabled",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 443,
    :ToPort => 443,
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressTriggers",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "SslDisabled",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 4001,
    :ToPort => 4001,
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressTriggersSsl",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "SslEnabled",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 5001,
    :ToPort => 5001,
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressServices",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "SslDisabled",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 4002,
    :ToPort => 4002,
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressServicesSsl",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Condition => "SslEnabled",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 5002,
    :ToPort => 5002,
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbV2",
  :Type => "AWS::ElasticLoadBalancingV2::LoadBalancer",
  :Properties => {
    :Name => "cog",
    :SecurityGroups => [ ref("CogElbSecurityGroup") ],
    :Subnets => ref("ElbSubnetIds"),
    :Tags => [
      {
        :Key => "Name",
        :Value => "cog"
      }
    ]
  }

resource "CogElbApiTarget",
  :Type => "AWS::ElasticLoadBalancingV2::TargetGroup",
  :Properties => {
    :Name => "CogApiEndpoint",
    :VpcId => ref("VpcId"),
    :Protocol => "HTTP",
    :Port => 4000,
    :HealthCheckPort => 4000,
    :HealthCheckPath => "/v1/bootstrap",
    :HealthyThresholdCount => 3,
    :UnhealthyThresholdCount => 6,
    :HealthCheckTimeoutSeconds => 5,
    :HealthCheckIntervalSeconds => 10
  }

resource "CogElbApiListener",
  :Type => "AWS::ElasticLoadBalancingV2::Listener",
  :Condition => "SslDisabled",
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 80,
    :Protocol => "HTTP",
    :DefaultActions => [
      {
        :Type => "forward",
        :TargetGroupArn => ref("CogElbApiTarget")
      }
    ]
  }

resource "CogElbApiListenerSsl",
  :Type => "AWS::ElasticLoadBalancingV2::Listener",
  :Condition => "SslEnabled",
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 443,
    :Protocol => "HTTPS",
    :Certificates => [{ :CertificateArn => ref("SslCertificateArn") }],
    :DefaultActions => [
      {
        :Type => "forward",
        :TargetGroupArn => ref("CogElbApiTarget")
      }
    ]
  }

resource "CogElbTriggerTarget",
  :Type => "AWS::ElasticLoadBalancingV2::TargetGroup",
  :Properties => {
    :Name => "CogTriggerEndpoint",
    :VpcId => ref("VpcId"),
    :Protocol => "HTTP",
    :Port => 4001,
    :HealthCheckPort => 4000,
    :HealthCheckPath => "/v1/bootstrap",
    :HealthyThresholdCount => 3,
    :UnhealthyThresholdCount => 6,
    :HealthCheckTimeoutSeconds => 5,
    :HealthCheckIntervalSeconds => 10
  }

resource "CogElbTriggerListener",
  :Type => "AWS::ElasticLoadBalancingV2::Listener",
  :Condition => "SslDisabled",
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 4001,
    :Protocol => "HTTP",
    :DefaultActions => [
      {
        :Type => "forward",
        :TargetGroupArn => ref("CogElbTriggerTarget")
      }
    ]
  }

resource "CogElbTriggerListenerSSL",
  :Type => "AWS::ElasticLoadBalancingV2::Listener",
  :Condition => "SslEnabled",
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 5001,
    :Protocol => "HTTPS",
    :Certificates => [{ :CertificateArn => ref("SslCertificateArn") }],
    :DefaultActions => [
      {
        :Type => "forward",
        :TargetGroupArn => ref("CogElbTriggerTarget")
      }
    ]
  }

resource "CogElbServiceTarget",
  :Type => "AWS::ElasticLoadBalancingV2::TargetGroup",
  :Properties => {
    :Name => "CogServiceEndpoint",
    :VpcId => ref("VpcId"),
    :Protocol => "HTTP",
    :Port => 4002,
    :HealthCheckPort => 4000,
    :HealthCheckPath => "/v1/bootstrap",
    :HealthyThresholdCount => 3,
    :UnhealthyThresholdCount => 6,
    :HealthCheckTimeoutSeconds => 5,
    :HealthCheckIntervalSeconds => 10
  }

resource "CogElbServiceListener",
  :Type => "AWS::ElasticLoadBalancingV2::Listener",
  :Condition => "SslDisabled",
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 4002,
    :Protocol => "HTTP",
    :DefaultActions => [
      {
        :Type => "forward",
        :TargetGroupArn => ref("CogElbServiceTarget")
      }
    ]
  }

resource "CogElbServiceListenerSsl",
  :Type => "AWS::ElasticLoadBalancingV2::Listener",
  :Condition => "SslEnabled",
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 5002,
    :Protocol => "HTTPS",
    :Certificates => [{ :CertificateArn => ref("SslCertificateArn") }],
    :DefaultActions => [
      {
        :Type => "forward",
        :TargetGroupArn => ref("CogElbServiceTarget")
      }
    ]
  }

output "CogElbHostname", :Value => get_att("CogElbV2", "DNSName")

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

resource "CogInstancePolicyS3",
  :Type => "AWS::IAM::Policy",
  :Properties => {
    :Roles => [ ref("CogInstanceRole") ],
    :PolicyName => "CogInstancePolicyS3",
    :PolicyDocument => {
      :Version => "2012-10-17",
      :Statement => [
        {
          :Effect => "Allow",
          :Action => [ "s3:ListBucket" ],
          :Resource => [
            join("", "arn:aws:s3:::", ref("CogBucket")),
            join("", "arn:aws:s3:::", ref("CogBucket"), "/*")
          ]
        },
        {
          :Effect => "Allow",
          :Action => [ "s3:PutObject", "s3:GetObject" ],
          :Resource => [ join("", "arn:aws:s3:::", ref("CogBucket"), "/*") ]
        }
      ]
    }
  }

output "CogInstanceRole", :Value => get_att("CogInstanceRole", "Arn")

resource "CogAsg",
  :Type => "AWS::AutoScaling::AutoScalingGroup",
  :Properties => {
    :VPCZoneIdentifier => ref("InstanceSubnetIds"),
    :DesiredCapacity => 1,
    :HealthCheckType => "EC2", # ELB ...
    :HealthCheckGracePeriod => 300,
    :LaunchConfigurationName => ref("CogAsgLaunchConfig"),
    :TargetGroupARNs => [
      ref("CogElbApiTarget"),
      ref("CogElbTriggerTarget"),
      ref("CogElbServiceTarget")
    ],
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
    "AWS::CloudFormation::Authentication" => {
      :S3AccessCreds => {
        :type => "S3",
        :buckets => [ ref("CogBucket") ],
        :roleName => ref("CogInstanceRole")
      }
    },
    "AWS::CloudFormation::Init" => {
      :configSets => {
        :default => [ "setup_paths", "configure", "run" ]
      },
      :setup_paths => {
        :commands => {
          :create_cog_home => {
            :command => "mkdir -m 0700 -p /opt/cog",
          }
        }
      },
      :configure => {
        :files => {
          "/opt/cog/.env" => {
            :content => join("",
              "COG_IMAGE=", ref("CogImage"), "\n",
              "SLACK_API_TOKEN=", ref("SlackApiToken"), "\n",
              fn_if("ProvisionRds",
                join("",
                  "DATABASE_URL=", "ecto://", ref("RdsMasterUsername"), ":", ref("RdsMasterPassword"), "@", get_att("RdsDatabase", "Endpoint.Address"), ":", get_att("RdsDatabase", "Endpoint.Port"), "/cog", "\n"),
                join("",
                  "DATABASE_URL=", ref("DatabaseUrl"), "\n",
                  "COG_DB_SSL=", ref("CogDbSsl"), "\n")),
              "COG_ALLOW_SELF_REGISTRATION=", ref("CogAllowSelfRegistration"), "\n",
              fn_if("CogBootstrapInstance",
                join("",
                  "COG_BOOTSTRAP_EMAIL_ADDRESS=", ref("CogBootstrapEmailAddress"), "\n",
                  "COG_BOOTSTRAP_FIRST_NAME=", ref("CogBootstrapFirstName"), "\n",
                  "COG_BOOTSTRAP_LAST_NAME=", ref("CogBootstrapLastName"), "\n",
                  "COG_BOOTSTRAP_PASSWORD=", ref("CogBootstrapPassword"), "\n",
                  "COG_BOOTSTRAP_USERNAME=", ref("CogBootstrapUsername"), "\n"),
                ""),
              "COG_API_URL_BASE=",
                fn_if("SslEnabled", "https", "http"), # scheme
                "://",
                fn_if("CogDnsnameExists",             # hostname
                  ref("CogDnsname"),
                  get_att("CogElbV2", "DNSName")
                ),
                ":",
                fn_if("SslEnabled", 443, 80),         # port
                "\n",
              "COG_TRIGGER_URL_BASE=",
                fn_if("SslEnabled", "https", "http"), # scheme
                "://",
                fn_if("CogDnsnameExists",             # hostname
                  ref("CogDnsname"),
                  get_att("CogElbV2", "DNSName")
                ),
                ":",
                fn_if("SslEnabled", 5001, 4001),      # port
                "\n",
              "COG_SERVICE_URL_BASE=",
                fn_if("SslEnabled", "https", "http"), # scheme
                "://",
                fn_if("CogDnsnameExists",             # hostname
                  ref("CogDnsname"),
                  get_att("CogElbV2", "DNSName")
                ),
                ":",
                fn_if("SslEnabled", 5002, 4002),      # port
                "\n",
              "RELAY_ID=", ref("RelayId"), "\n",
              "RELAY_IMAGE=", ref("RelayImage"), "\n",
              "RELAY_COG_TOKEN=", ref("RelayCogToken"), "\n"
            ),
            :mode => "0600",
            :owner => "root",
            :group => "root"
          },
          "/opt/cog/docker-compose.yml" => {
            :content => File.read(File.join(File.dirname(__FILE__), "..", "docker-compose.yml")),
            :mode => "0600",
            :owner => "root",
            :group => "root"
          }
        },
        :commands => {
          # We do this with AWSCLI so cfn-init won't abort if the file is not
          # present.
          :copy_s3_resources => {
            :command => join("", "aws s3 cp --recursive s3://", ref("CogBucket"), "/etc/ /opt/cog || true")
          }
        }
      },
      :run => {
        :commands => {
          :docker_start => {
            :command => "/usr/local/bin/docker-compose up -d",
            :cwd => "/opt/cog"
          }
        }
      }
    }
  }
