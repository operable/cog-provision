# ---------------------------------------------------------------------------
# Custom Timestamp Resource
# ---------------------------------------------------------------------------

# This resource uses a Lambda function that returns a simple timestamp
# when it is created and any time any of the values in the ParamData list
# in properties are updated. We use this in the ASG LaunchConfiguration in
# order to update a comment in UserData and trigger an instance replacement
# when relevant parameters are updated.

resource "Time",
  :Type => "Custom::TimestampFunction",
  :Properties => {
    :ServiceToken => get_att("TimestampFunction", "Arn"),
    :ParamData => [
      ref("ImageId"),
      ref("InstanceSubnetIds"),
      ref("InstanceType"),
      ref("KeyName"),
      ref("CogDnsname"),
      ref("RdsMasterPassword"),
      ref("RdsMasterUsername"),
      get_att("RdsDatabase", "Endpoint.Address"),
      get_att("RdsDatabase", "Endpoint.Port"),
      ref("CogImage"),
      ref("RelayImage"),
      ref("CogDbSsl"),
      ref("DatabaseSource"),
      ref("DatabaseUrl"),
      ref("SlackApiToken"),
      ref("CogAllowSelfRegistration"),
      ref("CogBootstrapEmailAddress"),
      ref("CogBootstrapFirstName"),
      ref("CogBootstrapInstance"),
      ref("CogBootstrapLastName"),
      ref("CogBootstrapPassword"),
      ref("CogBootstrapUsername"),
      ref("CogBucketName"),
      ref("CogBucketPrefix"),
      ref("RelayId"),
      ref("RelayCogToken")
    ]
  }

resource "TimestampFunction",
  :Type => "AWS::Lambda::Function",
  :Properties => {
    :Code => {
      :ZipFile => File.read(File.join(File.dirname(__FILE__), "..", "lambda-timestamp.js"))
    },
    :Handler => "index.handler",
    :Role => get_att("LambdaLogRole", "Arn"),
    :Runtime => "nodejs",
    :Timeout => 3
  }

resource "LambdaLogRole",
  :Type => "AWS::IAM::Role",
  :Properties => {
    :AssumeRolePolicyDocument => {
      :Version => "2012-10-17",
      :Statement => [
        {
          :Effect => "Allow",
          :Principal => { :Service => [ "lambda.amazonaws.com" ] },
          :Action => [ "sts:AssumeRole" ]
        }
      ]
    },
    :Path => "/",
    :Policies => [
      {
        :PolicyName => "root",
        :PolicyDocument => {
          :Version => "2012-10-17",
          :Statement => [
            {
              :Effect => "Allow",
              :Action => [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ],
              :Resource => "arn:aws:logs:*:*:*"
            }
          ]
        }
      }
    ]
  }

# ---------------------------------------------------------------------------
# S3 Bucket - Used for logs and advanced configuration.
# ---------------------------------------------------------------------------

resource "CogBucket",
  :Type => "AWS::S3::Bucket",
  :Condition => "CogBucketNameEmpty"

output "CogBucket",
  :Value => fn_if("CogBucketNameExists", ref("CogBucketName"), ref("CogBucket"))

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
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => fn_if("SslEnabled", 443, 80),
    :ToPort => fn_if("SslEnabled", 443, 80),
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressTriggers",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 4001,
    :ToPort => 4001,
    :IpProtocol => 6,
    :CidrIp => "0.0.0.0/0"
  }

resource "CogElbIngressServices",
  :Type => "AWS::EC2::SecurityGroupIngress",
  :Properties => {
    :GroupId => ref("CogElbSecurityGroup"),
    :FromPort => 4002,
    :ToPort => 4002,
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
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => fn_if("SslEnabled", "443", "80"),
    :Protocol => fn_if("SslEnabled", "HTTPS", "HTTP"),
    :Certificates =>
      fn_if("SslEnabled",
        [{ :CertificateArn => ref("SslCertificateArn") }],
        ref("AWS::NoValue")),
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
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 4001,
    :Protocol => fn_if("SslEnabled", "HTTPS", "HTTP"),
    :Certificates =>
      fn_if("SslEnabled",
        [{ :CertificateArn => ref("SslCertificateArn") }],
        ref("AWS::NoValue")),
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
  :Properties => {
    :LoadBalancerArn => ref("CogElbV2"),
    :Port => 4002,
    :Protocol => fn_if("SslEnabled", "HTTPS", "HTTP"),
    :Certificates =>
      fn_if("SslEnabled",
        [{ :CertificateArn => ref("SslCertificateArn") }],
        ref("AWS::NoValue")),
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
            join("",
              "arn:aws:s3:::",
              fn_if("CogBucketNameExists",
                ref("CogBucketName"),
                ref("CogBucket")),
              ref("CogBucketPrefix")),
            join("",
              "arn:aws:s3:::",
              fn_if("CogBucketNameExists",
                ref("CogBucketName"),
                ref("CogBucket")),
              ref("CogBucketPrefix"), "*"),
          ]
        },
        {
          :Effect => "Allow",
          :Action => [ "s3:PutObject", "s3:GetObject" ],
          :Resource => [
            join("",
              "arn:aws:s3:::",
              fn_if("CogBucketNameExists",
                ref("CogBucketName"),
                ref("CogBucket")),
              ref("CogBucketPrefix"), "*")
          ]
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
    :MaxSize => 1,
    :MinSize => 0,
    :HealthCheckType => "EC2",
    :HealthCheckGracePeriod => 300,
    :LaunchConfigurationName => ref("CogAsgLaunchConfig"),
    :TargetGroupARNs => [
      ref("CogElbApiTarget"),
      ref("CogElbTriggerTarget"),
      ref("CogElbServiceTarget")
    ],
  },
  :UpdatePolicy => {
      :AutoScalingReplacingUpdate => {
        :WillReplace => "true"
      }
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
      "  - cfn-init -s ", ref("AWS::StackName"), " -r CogAsgLaunchConfig\n",
      "# Timestamp: ", get_att("Time", "Now")
    ))
  },
  :Metadata => {
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
            :command =>
              join("",
                "aws s3 cp --recursive s3://",
                fn_if("CogBucketNameExists",
                  ref("CogBucketName"),
                  ref("CogBucket")),
                ref("CogBucketPrefix"), "etc/ /opt/cog || true")
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
