# Setup VPC Lattice end to end connectivity to connect two VPCs
```
terraform init
terraform plan
terraform apply
```
terraform apply Outputs:
```
Outputs:


client_instance_id_prod = "<client-instance-id>"
lattice_service_dns_name_prod = "<lattice-service-dns-prefix>.vpc-lattice-svcs.us-west-2.on.aws"
target_instance_id_prod = "<target-instance-id>"
```

# Test network connectivity

Go to the aws console, use Session Manager to connect to client instance, and run the following commands:
```
curl http://<lattice-service-dns-prefix>.vpc-lattice-svcs.us-west-2.on.aws:9090/my-app

```

you should get response from the target instance in the target VPC:
```

Request URL: https://<lattice-service-dns-prefix>.vpc-lattice-svcs.us-west-2.on.aws:9090/my-app
Request Headers: {'Host': '<lattice-service-dns-prefix>.vpc-lattice-svcs.us-west-2.on.aws:9090', 'User-Agent': 'curl/8.3.0', 'Accept': '*/*', 'X-Forwarded-For': '<client-instance-ip>', 'X-Amzn-Lattice-Network': 'SourceVpcArn=arn:<source-vpc-arn>', 'X-Amzn-Lattice-Target': 'ServiceArn=<lattice-service-arn>; ServiceNetworkArn=<lattice-service-network-arn>; TargetGroupArn=<target-group-arn>', 'X-Amzn-Source-Vpc': '<source-vpc-id>'}
Request Body: 
```
