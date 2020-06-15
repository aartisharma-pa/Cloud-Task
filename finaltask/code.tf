provider "aws" {
  region     = "ap-south-1"
  profile    = "patask"
}

resource "aws_security_group" "securitygrp" {
  name        = "securitygrp"
  description = "create a security group & allow port number 80"
  vpc_id      = "vpc-eb938e83"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "task" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      =  "MyKey1"
  security_groups = ["securitygrp"]

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Arti/Downloads/MyKey1.pem")
    host     = aws_instance.task.public_ip
  }
   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
       "sudo systemctl enable httpd"	
    ]
  }

  tags = {
    Name = "taskos"
  }
}

output "outip" {
	value = aws_instance.task.public_ip
}

resource "null_resource" "nulllocal" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.task.public_ip} > publicip.txt"
    
  }
}

resource "aws_ebs_volume" "ebsvol" {
  availability_zone = aws_instance.task.availability_zone
  size              = 1

  tags = {
    Name = "taskvol"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebsvol.id
  instance_id = aws_instance.task.id
  force_detach = true
}

resource "null_resource" "nulllocal1" {

depends_on = [
   aws_volume_attachment.ebs_att
  ]

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Arti/Downloads/MyKey1.pem")
    host     = aws_instance.task.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh /var/www/html",
       "sudo rm -rf /var/www/html/*",
       "sudo git clone https://github.com/aartisharma-pa/Cloud-Task.git /var/www/html/"
    ]
  }
}



resource "aws_s3_bucket" "s3bucket" {
    
 depends_on = [
   aws_volume_attachment.ebs_att
  ]

  bucket = "bucket0410"
  acl    = "public-read"

 provisioner "local-exec" {
     command = "git clone https://github.com/aartisharma-pa/Cloud-Task.git C:/Users/Arti/Desktop/terra/finaltask/Git"
      }
}


resource "aws_s3_bucket_object" "s3object" {
  bucket = aws_s3_bucket.s3bucket.bucket
  key    = "img.jpg"
  source = "C:/Users/Arti/Desktop/terra/finaltask/Git/img.jpg"
  content_type = "image/jpg"
  acl = "public-read"
 }

resource "aws_cloudfront_distribution" "cloudfront" {

	origin {
		domain_name = aws_s3_bucket.s3bucket.bucket_regional_domain_name
		origin_id   = "aws_s3_bucket.s3bucket.bucket.s3_origin_id"


		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}

	enabled = true

	default_cache_behavior {
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = "aws_s3_bucket.s3bucket.bucket.s3_origin_id"

		forwarded_values {
			query_string = false

			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
	}

	restrictions {
		geo_restriction {

			restriction_type = "none"
		}
	}

	viewer_certificate {
		cloudfront_default_certificate = true
	}
}


resource "null_resource" "finalnull"  {


depends_on = [
      aws_cloudfront_distribution.cloudfront,
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.task.public_ip}"
  	}
}