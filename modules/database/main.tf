resource "aws_db_instance" "database" {
  allocated_storage      = 5
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  identifier             = "${var.namespace}-db-instance"
  name                   = "test"
  username               = "final_user"
  password               = "12345678"
  skip_final_snapshot    = true
  db_subnet_group_name   = var.vpc.database_subnet_group
  vpc_security_group_ids = [var.sg.db]
}
