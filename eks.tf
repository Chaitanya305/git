terraform {
    required_providers{
        aws ={
            source = "hashicorp/aws"
            version = "5.38.0"
        }
    }
}


provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "eks_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
      Name ="eks_vpc"
    }
}

resource "aws_subnet" "private_sub" {
    vpc_id = aws_vpc.eks_vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name = "private_sub-1a"
        #"kubernetes.io/role/internal-elb" = "1"   >> if LB required in private subnet too
        #"kubernetes.io/cluster/my-cluster" = "shared"  >> Version 2.1.1 or earlier of the AWS Load Balancer Controller requires this tag.
    }
    depends_on = [ aws_vpc.eks_vpc ]
}

resource "aws_subnet" "public_sub" {
    vpc_id = aws_vpc.eks_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = "true"
    tags = {
        Name = "public_sub_1b"
        "kubernetes.io/role/elb" = "1"
        "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"  # Version 2.1.1 or earlier of the AWS Load Balancer Controller requires this tag. now it is optional
    }
    depends_on = [ aws_vpc.eks_vpc ]
}

resource "aws_subnet" "public_sub-2" {
    vpc_id = aws_vpc.eks_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1c"
    map_public_ip_on_launch = "true"
    tags = {
        Name = "public_sub_1c"
        "kubernetes.io/role/elb" = "1"
        "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"  # Version 2.1.1 or earlier of the AWS Load Balancer Controller requires this tag. now it is optional
    }
    depends_on = [ aws_vpc.eks_vpc ]
}

resource "aws_internet_gateway" "IGW" {
    vpc_id = aws_vpc.eks_vpc.id
    tags = {
        Name = "eks-IGW"
    }
}  

/*  if you create nodes in private sub then needed to acces it publically for this nat required. 
resource "aws_eip" "eks-eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eks-eip.id 
  subnet_id = aws_subnet.public_sub.id
  tags = {
    Name = "eks-nat"
  }
}
*/

resource "aws_route_table" "pub_rtable" {
    vpc_id = aws_vpc.eks_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id =  aws_internet_gateway.IGW.id
    }
    tags = {
      Name = "pub_rtable-1b"
    }
}


resource "aws_route_table_association" "r_table_associate" {
    route_table_id = aws_route_table.pub_rtable.id
    subnet_id = aws_subnet.public_sub.id
    depends_on = [ aws_route_table.pub_rtable, aws_subnet.public_sub ]
}


resource "aws_iam_role" "eks_acces_role" {
    name = "eks_role"
    description = "this role is to acces other aws services form eks"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
                Service = "eks.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        },
    ]

    })
}


resource "aws_iam_role" "node_group_acces_role" {
    name = "node_gp_role"
    description = "this role is to acces other aws services form woeker nodes in node group."
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        },
    ]

    })
}


resource "aws_iam_policy_attachment" "eks_policy_attach" {
  name = "eks-policy-attach"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  roles = [aws_iam_role.eks_acces_role.name]
}


resource "aws_iam_policy_attachment" "node_gp-worker-node-policy"{
  name = "node_gp-worker-node-policy"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"   # to connet ec2 to EKS cluster
  roles = [aws_iam_role.node_group_acces_role.name]
}

resource "aws_iam_policy_attachment" "node_gp_CNI_policy_attach" {
  name = "node_gp_CNI_policy_attac"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"   # the permissions it requires to modify the IP address configuration on your EKS worker nodes.
  roles = [aws_iam_role.node_group_acces_role.name]
}

variable "eks_cluster_name" {
    type = string
    default = "eks-demo-cluster"
}


resource "aws_eks_cluster" "eks-cluster" {
  name = var.eks_cluster_name
  role_arn = aws_iam_role.eks_acces_role.arn
  vpc_config {
    subnet_ids = [aws_subnet.public_sub.id, aws_subnet.private_sub.id]
  }
  depends_on = [ aws_iam_policy_attachment.eks_policy_attach, aws_iam_role.eks_acces_role, aws_vpc.eks_vpc ]
}


resource "aws_eks_node_group" "eks-ng" {
  node_group_name = "pub-node-gp"
  cluster_name = aws_eks_cluster.eks-cluster.name
  node_role_arn = aws_iam_role.node_group_acces_role.arn
  subnet_ids = [aws_subnet.public_sub.id, aws_subnet.public_sub-2.id]
  scaling_config {
    desired_size = 1
    min_size = 1
    max_size = 2
  }
  instance_types = ["t3.micro"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 20
  remote_access {
    ec2_ssh_key = "EKS-KEY-PAIR"
  }
  depends_on = [ aws_eks_cluster.eks-cluster, aws_iam_role.node_group_acces_role ]
}
