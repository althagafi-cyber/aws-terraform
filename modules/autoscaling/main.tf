module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "service"

  # Launch configuration
  lc_name = "althagafi-lc"

  image_id        = "ami-0e2ff28bfb72a4e45"
  instance_type   = "t2.micro"
  security_groups = [var.sg.webserver]
  iam_instance_profile = "ro_ec2"

  associate_public_ip_address = true

  user_data = <<-EOF
                #!/bin/bash

                #ssh enable
                useradd althagafi; echo -e "As12==\nAs12==" | passwd althagafi
                usermod -aG wheel althagafi
                mkdir -p /home/althagafi/.ssh
                aws s3 cp s3://cs641-pk/althagafi-abdulmohsen.pub /home/althagafi/.ssh/authorized_keys
                chown -R althagafi:althagafi /home/althagafi/.ssh
                chmod 755 /home/althagafi/.ssh
                chmod 644 /home/althagafi/.ssh/authorized_keys

                #webserver start
                yum update -y
                yum install -y httpd24 php56 php56-mysqlnd
                service httpd start
                chkconfig httpd on
                groupadd www
                usermod -a -G www althagafi
                chgrp -R www /var/www
                chown -R althagafi:althagafi /var/www
                chmod 2775 /var/www
                find /var/www -type d -exec chmod 2775 {} \;
                find /var/www -type f -exec chmod 0664 {} \;
                mkdir /var/www/inc
                aws s3 cp s3://cs641-pk/dbinfo.inc /var/www/inc/
                aws s3 cp s3://cs641-pk/main.php /var/www/html/
                EOF


  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "8"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size = "8"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name                  = "${var.namespace}-asg"
  vpc_zone_identifier       = var.vpc.private_subnets
  health_check_type         = "EC2"
  min_size                  = 2
  max_size                  = 5
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  target_group_arns = module.alb.target_group_arns

  tags = [
    {
      key                 = "Name"
      value               = "althagafi-webserver"
      propagate_at_launch = true
    },

  ]

}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "${var.namespace}-alb"

  load_balancer_type = "application"

  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]



  target_groups = [
    {
      name_prefix      = "tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 10
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200-399"
    }
  }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Name = "althagafi-TG"
  }
}
