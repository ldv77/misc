CREATE DATABASE pdnsadmin;
GRANT ALL PRIVILEGES ON pdnsadmin.* TO 'pdnsadminuser'@'%' IDENTIFIED BY 'mypassword';
FLUSH PRIVILEGES;
