-- since for some reason we believe we have to remove all the users from the database on an export we need to add them back
-- on an import (oh yeah, this makes alot of sense) but codemonkey do what he is told
-- NOTE: if we have other users that can create database objects over time we need ot add them here too
CREATE USER 'sstacha'@'%' IDENTIFIED BY 'password';
CREATE USER 'jboden'@'%' IDENTIFIED BY 'password';
CREATE USER 'jtoony'@'%' IDENTIFIED BY 'password';
CREATE USER 'imorrison'@'%' IDENTIFIED BY 'password';
CREATE USER 'bfountain'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'sstacha'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'jboden'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'jtoony'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'imorrison'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'bfountain'@'%';