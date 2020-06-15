 
 provider "aws" {
   region = "ap-south-1"
   profile = "userprofile"
 }

 resource "aws_security_group" "myweb-sg" {
   name        = "mysecurity"
   description = "Allow tcp inbound traffic"
   vpc_id      = "vpc-1a6e7272"

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
   ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   }

   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
   }

   tags = {
    Name = "web-sg"
   }
 }

 resource "aws_instance" "web-ins" {
   ami           = "ami-0447a12f28fddb066"
   instance_type = "t2.micro"
   key_name 	= "web-key1"
   security_groups = [ "mysecurity" ]  
   tags = {
     Name = "web-os"
   }
 }

 resource "aws_ebs_volume" "myebs-vol" {
   availability_zone = aws_instance.web-ins.availability_zone
   size              = 1

   tags = {
    Name = "ebs-vol"
   }
 }

   resource "aws_volume_attachment" "ebs_att" {
     device_name	 = "/dev/sdg"
     volume_id  	 = aws_ebs_volume.myebs-vol.id
     instance_id 	 = aws_instance.web-ins.id
     force_detach 	 = true
   }

  resource "null_resource" "null1" {

    depends_on = [
                  aws_volume_attachment.ebs_att , 
                  aws_instance.web-ins   
    ]
  
    connection {
    type     	= "ssh"
    user     	= "ec2-user"
    private_key = file("C:/Users/SHUBHAM SANKHLA/Desktop/web-key1.pem")
    host    	= aws_instance.web-ins.public_ip 
   } 

   provisioner "remote-exec" {
      inline = [  
                  "sudo su - root << EOR", 
                  "yum install httpd php git -y" ,
                  "systemctl restart httpd",
                  "systemctl enable httpd",
                  "rm -rf /var/www/html/*",                
                  "fdisk /dev/xvdg << EOF",
                  "n",
                  "p",
                  "1",
                  " ",
                  " ",
                  "w",
                  "EOF", 
                  "mkfs.ext4 /dev/xvdg",
                  "mount /dev/xvdg /var/www/html/",
                  "mkdir /root/data",
                  "git clone https://github.com/shubham1224/cloud-task1.git  /root/data/",
                  "mv /root/data/*.php  /var/www/html/",
                  "EOR"        
                                        	
       ] 
   }

 }

  resource "aws_s3_bucket" "web-bucket" {

	  bucket = "mybucket6388"	
          acl    = "private"


   provisioner "local-exec" {
           
         command = "mkdir E:\\cloud-task1"
    }
 
   provisioner "local-exec" {
           
         command = "git clone https://github.com/shubham1224/cloud-task1.git  E:/cloud-task1"
    }


  }

 resource "aws_s3_bucket_object" "myobject" {
 
   bucket = "mybucket6388" 
   key    = "hybridcloud.jpg"
   source = "E:/cloud-task1/hybridcloud.jpg"
   acl  	 = "private"

 }


  locals {
    s3_origin_id = "mybucket6388-origin"
  }

 resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
   comment = "Some comment"
 }

 resource "aws_cloudfront_distribution" "s3_distribution" {
   origin {
     domain_name =  aws_s3_bucket.web-bucket.bucket_regional_domain_name
     origin_id   =  local.s3_origin_id
 
    s3_origin_config {
       origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }

   enabled             = true
   is_ipv6_enabled     = true
   comment             = "Nothing to Say"

   default_cache_behavior {
     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
     cached_methods   = ["GET", "HEAD"]
     target_origin_id = local.s3_origin_id
 
     forwarded_values {
       query_string = false

       cookies {
         forward = "none"
       }
     }

     viewer_protocol_policy = "allow-all"
     min_ttl                = 0
     default_ttl            = 3600
     max_ttl                = 86400
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

 data "aws_iam_policy_document" "s3_policy" {
   statement {
     actions   = ["s3:GetObject"]
     resources = ["${aws_s3_bucket.web-bucket.arn}/*"]
 
     principals {
      type        = "AWS"
       identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
     }
   }
 }

 resource "aws_s3_bucket_policy" "bkt-policy" {
   bucket = "${aws_s3_bucket.web-bucket.id}"
   policy = "${data.aws_iam_policy_document.s3_policy.json}"
 }

 resource "null_resource" "null2" {
   
   depends_on = [
     aws_s3_bucket_policy.bkt-policy
   ]
 
   connection {
     type     	= "ssh"
     user     	= "ec2-user"
     private_key = file("C:/Users/SHUBHAM SANKHLA/Desktop/web-key1.pem")
     host    	 = "${aws_instance.web-ins.public_ip}" 
   } 

   provisioner "remote-exec" {
      inline = [
                "sudo su - root << EOF", 
 "echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.myobject.id}' width='1000' height='700'></img>\"  
                                 >> /var/www/html/index.php  " ,                
                "EOF" 
              
      ] 
   }
 
   provisioner "local-exec" {
     
        command = "echo ${aws_instance.web-ins.public_ip} >> myinspublicip.txt" 
             
   }

 }




