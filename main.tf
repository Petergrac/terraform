provider "aws"{
	region = "af-south-1"
}

resource "aws_instance" "My_Instance" {
  ami = "ami-01e13d903c268a58b"
  instance_type = "t3.micro"
  region = "af-south-1"
  subnet_id = "subnet-05242796afb1250bf"
  vpc_security_group_ids = ["sg-0d63e748ecda7c5d7"]
  tags = {
	Name="terraform-example"
  }
}