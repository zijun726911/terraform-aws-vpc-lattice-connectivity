# https://registry.terraform.io/modules/aws-ia/amazon-vpc-lattice-module/aws/latest
module "lattice_resources" {
  source  = "aws-ia/amazon-vpc-lattice-module/aws"
  version = "0.0.2"

  service_network = {
    name      = "my-sn${var.name_suffix}"
    auth_type = "NONE"
  }

  vpc_associations = {
    my-snva-with-client = {
      vpc_id = module.client_vpc.vpc_id
    }
  }

  services = {
    # this `aws-ia/amazon-vpc-lattice-module/aws` module is able to automatically create snsas https://github.com/aws-ia/terraform-aws-amazon-vpc-lattice-module/blob/main/main.tf#L60
    my_lattice_svc = {
      name      = "my-lattice-svc${var.name_suffix}"
      listeners = {
        # HTTP listener
        http_listener = {
          name                         = "my-listener${var.name_suffix}"
          port                         = 9090
          protocol                     = "HTTP"
          default_action_fixedresponse = { status_code = 404 }
          rules                        = {
            rule1 = {
              priority   = 20
              path_match = {
                prefix = "/my-app"
              }
              action_forward = {
                target_groups = {
                  my_ip_tg = { weight = 100 }
                }
              }
            }
          }
        }
      }
    }
  }
  target_groups = {
    my_ip_tg = {
      name   = "my-ip-tg${var.name_suffix}"
      type   = "IP"
      config = {
        port             = 8080
        protocol         = "HTTPS"
        vpc_identifier   = module.target_vpc.vpc_id
        ip_address_type  = "IPV4"
      }
      health_check = {
        enabled = true
      }
      targets = {
        t1 = {
          id   = module.target_instance.private_ip
          port = 8080
        }
      }
    }
  }
}


module "client_vpc" {
  source                        = "terraform-aws-modules/vpc/aws"
  version                       = "5.4.0"
  name                          = "my-client-vpc${var.name_suffix}"
  cidr                          = "10.0.0.0/16"
  azs                           = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets                = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  manage_default_security_group = true
  default_security_group_egress = [
    {
      from_port   = 0,
      to_port     = 0,
      protocol    = "-1",
      cidr_blocks = "0.0.0.0/0",
      description = "Allow all outbound traffic, SSM needs this"
    }
  ]
}

module "target_vpc" {
  source                         = "terraform-aws-modules/vpc/aws"
  version                        = "5.4.0"
  name                           = "my-target-vpc${var.name_suffix}"
  cidr                           = "10.0.0.0/16"
  azs                            = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets                 = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  manage_default_security_group  = true
  default_security_group_ingress = [
    {
      from_port   = 8080
      to_port     = 8080
      cidr_blocks = "0.0.0.0/0"
      protocol    = "tcp"
    }

  ]
  default_security_group_egress = [
    {
      from_port   = 0,
      to_port     = 0,
      protocol    = "-1",
      cidr_blocks = "0.0.0.0/0",
      description = "Allow all outbound traffic, SSM needs this"
    }
  ]

}

module "client_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  name                        = "client-instance${var.name_suffix}"
  instance_type               = "t3.micro"
  monitoring                  = true
  associate_public_ip_address = true
  subnet_id                   = module.client_vpc.public_subnets[0]
  metadata_options            = {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
}

# Use this command to generate certificate and private key: openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt -days 365 -nodes -subj "/CN=my-server.com"
module "target_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  name                        = "target-instance${var.name_suffix}"
  instance_type               = "t3.micro"
  monitoring                  = true
  associate_public_ip_address = true
  subnet_id                   = module.target_vpc.public_subnets[0]
  metadata_options            = {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  user_data            = <<-EOF
#!/bin/bash
pip3 install Flask
mkdir /root/echo-server
cat > echo_server.py << SCRIPT_END
from flask import Flask, request
app = Flask(__name__)

cert_str = """
-----BEGIN CERTIFICATE-----
<substitute to server.crt content>
-----END CERTIFICATE-----
"""
key_str = """
-----BEGIN PRIVATE KEY-----
<substitute to server.key content>
-----END PRIVATE KEY-----
"""

@app.route('/', defaults={'path': ''}, methods=['GET', 'POST'])
@app.route('/<path:path>', methods=['GET', 'POST'])
def echo(path):
    headers = dict(request.headers)
    body = request.get_data(as_text=True)
    request_url = request.url
    response = (f"Request URL: {request_url}\n"
                f"Request Headers: {headers}\n"
                f"Request Body: {body}")
    return response

if __name__ == '__main__':
    with open('cert.pem', 'w') as f:
        f.write(cert_str)
    with open('key.pem', 'w') as f:
        f.write(key_str)
    app.run(host='0.0.0.0', port=8080, ssl_context=('cert.pem', 'key.pem'))
SCRIPT_END
sudo nohup python3 echo_server.py > /dev/null 2>&1 &
EOF
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-instance-profile${var.name_suffix}"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm-role${var.name_suffix}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}