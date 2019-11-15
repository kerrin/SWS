-------------------------------------------------------------------------------
-- database.sql
-------------------------------------------------------------------------------
-- Description:
-- 					Contains the database creation sql for the SWS core tables
--						that are required for the SWS to function
-------------------------------------------------------------------------------
-- CVS Details
-- -----------
-- $Author: kerrin $
-- $Date: 2003/08/24 21:37:22 $
-- $Revision: 1.4 $
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Table:			SEQUENCE
-------------------------------------------------------------------------------
-- Description:	Used to store the next index used for inserts of all tables
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- table						The table name that the row is the next index of
-- count						The next index to use for the table
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS SEQUENCE;
CREATE TABLE SEQUENCE
(
   table_name VARCHAR(50) NOT NULL,
	count	BIGINT NOT NULL DEFAULT 1,
	UNIQUE (table_name),
	PRIMARY KEY (table_name),
	INDEX (table_name)
);

-------------------------------------------------------------------------------
-- Table:			GENDER_CONST
-------------------------------------------------------------------------------
-- Description:	Used define the member states
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- name						The keyword
-- description				The description
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS GENDER_CONST;
CREATE TABLE GENDER_CONST
(
	ID	BIGINT NOT NULL,
	name VARCHAR(10),
	description VARCHAR(80),
	PRIMARY KEY (ID),
	KEY (name), 
	UNIQUE(name)
);

INSERT INTO GENDER_CONST (ID,name,description) VALUES (1,'UNKNOWN','No Gender');
INSERT INTO GENDER_CONST (ID,name,description) VALUES (2,'MALE','Male');
INSERT INTO GENDER_CONST (ID,name,description) VALUES (3,'FEMALE','Female');
INSERT INTO SEQUENCE (table_name,count) VALUES ('GENDER_CONST',4);

-------------------------------------------------------------------------------
-- Table:			MEMBER_STATE_CONST
-------------------------------------------------------------------------------
-- Description:	Used define the member states
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- name						The keyword
-- description				The description
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS MEMBER_STATE_CONST;
CREATE TABLE MEMBER_STATE_CONST
(
	ID	BIGINT NOT NULL,
	name VARCHAR(10),
	description VARCHAR(80),
	PRIMARY KEY (ID),
	KEY (name), 
	UNIQUE(name)
);

INSERT INTO MEMBER_STATE_CONST (ID,name,description) VALUES (1,'ADMIN','Administrator User');
INSERT INTO MEMBER_STATE_CONST (ID,name,description) VALUES (2,'ENABLED','Enabled User');
INSERT INTO MEMBER_STATE_CONST (ID,name,description) VALUES (3,'DISABLED','Disabled or Deleted User');
INSERT INTO MEMBER_STATE_CONST (ID,name,description) VALUES (4,'BARRED','Banned User');
INSERT INTO MEMBER_STATE_CONST (ID,name,description) VALUES (5,'REGISTERED','Registered User Pending Confirmation');
INSERT INTO SEQUENCE (table_name,count) VALUES ('MEMBER_STATE_CONST',6);

-------------------------------------------------------------------------------
-- Table:			MEMBER
-------------------------------------------------------------------------------
-- Description:	Used to store core details about registered users
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- username					The unique username (email address)
-- password					The encrypted password
-- screen_name				The screen name to display
-- firstname				The optional firstname
-- surname					The optional surname
-- dob						The optional date of birth (YYYY-MM-DD)
-- gender_ID				The optional gender
-- registered				The date registered
-- last_logon				The date and time of last log in
-- paid_expire				The date of paid membership expiry
-- expire					The date of registration expiry
-- state_ID					The users state
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS MEMBER;
CREATE TABLE MEMBER
(
	ID	BIGINT NOT NULL,
	username	VARCHAR(50) NOT NULL,
	password VARCHAR(50) NOT NULL,
	screen_name	VARCHAR(50) NOT NULL,
	firstname VARCHAR(50),
	surname VARCHAR(50),
	dob DATE,
	gender_ID SMALLINT,
	registered DATE,
	last_logon DATETIME DEFAULT NULL,
	paid_expire DATE DEFAULT NULL,
	expire DATE DEFAULT NULL,
	state_ID INT NOT NULL,
	PRIMARY KEY (ID),
	KEY(username),
	UNIQUE(username),
	FOREIGN KEY (gender_ID) REFERENCES GENDER_CONST(ID),
	FOREIGN KEY (state_ID) REFERENCES MEMBER_STATE_CONST(ID)
);

INSERT INTO MEMBER (ID,username,password,screen_name,firstname,surname,dob,gender_ID,registered,last_logon,paid_expire,expire,state_ID) VALUES (1,'admin@sws.com',ENCRYPT('4dm1N','SW'),'Admin','Administrator','Administrator','1975-09-02',0,'NOW()',null,null,null,1);
INSERT INTO MEMBER (ID,username,password,screen_name,firstname,surname,dob,gender_ID,registered,last_logon,paid_expire,expire,state_ID) VALUES (2,'system@sws.com',ENCRYPT('5yst4M','SW'),'System','System','System','1975-09-02',0,'NOW()',null,null,null,1);
INSERT INTO MEMBER (ID,username,password,screen_name,firstname,surname,dob,gender_ID,registered,last_logon,paid_expire,expire,state_ID) VALUES (3,'guest@sws.com',ENCRYPT('Gu35t','SW'),'Guest','Guest','Guest','1975-09-02',0,'NOW()',null,null,null,2);
INSERT INTO SEQUENCE (table_name,count) VALUES ('MEMBER',4);

-------------------------------------------------------------------------------
-- Table:			SITE
-------------------------------------------------------------------------------
-- Description:	Stores the site list and details
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- name						The site name
-- domain					The site domain
-- minimum_age				The minimum age requirement
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS SITE;
CREATE TABLE SITE
(
	ID 			BIGINT NOT NULL,
	name			VARCHAR(50) NOT NULL,
	domain		VARCHAR(80) NOT NULL,
	minimum_age	SMALLINT DEFAULT 0,
	PRIMARY KEY(ID),
	UNIQUE (name)
);

INSERT INTO SITE(ID,name,domain,minimum_age) VALUES (1,'Total Leader','totalleader.com',0);
INSERT INTO SEQUENCE (table_name,count) VALUES ('SITE',2);

-------------------------------------------------------------------------------
-- Table:			MEMBER_SITE_LINK
-------------------------------------------------------------------------------
-- Description:	List which members have access to which sites
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- member_ID				The member who has access to the site
-- site_ID					The site they have access to
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS MEMBER_SITE_LINK;
CREATE TABLE MEMBER_SITE_LINK
(
	ID 			BIGINT NOT NULL,
	member_ID 	BIGINT NOT NULL,
	site_ID 		BIGINT NOT NULL,
	PRIMARY KEY (ID),
	FOREIGN KEY (member_ID) REFERENCES MEMBER(ID),
	FOREIGN KEY (site_ID) REFERENCES SITE(ID)
);

-- INSERT INTO  (ID,member_ID,site_ID) VALUES (1,,);
INSERT INTO SEQUENCE (table_name,count) VALUES ('MEMBER_SITE_LINK',1);

-------------------------------------------------------------------------------
-- Table:			PRIVILEGE_CONST
-------------------------------------------------------------------------------
-- Description:	Store the user privileges
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- name						The keyword
-- description				The description
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS PRIVILEGE_CONST;
CREATE TABLE PRIVILEGE_CONST
(
	ID BIGINT NOT NULL,
	name VARCHAR(10) NOT NULL,
	description VARCHAR(80),
	PRIMARY KEY (ID),
	KEY (name), 
	UNIQUE(name)
);

-- INSERT INTO PRIVILEGE_CONST (ID,name,description) VALUES (1,'','');
INSERT INTO SEQUENCE (table_name,count) VALUES ('PRIVILEGE_CONST',1);

-------------------------------------------------------------------------------
-- Table:			MEMBER_PRIVILEGE_LINK
-------------------------------------------------------------------------------
-- Description:	Links the privileges to the users 
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- member_ID				The user to grant the privilege to
-- site_ID					The user to grant the privilege to
-- privilege_ID			The privilege to grant
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS MEMBER_PRIVILEGE_LINK;
CREATE TABLE MEMBER_PRIVILEGE_LINK
(
	ID BIGINT NOT NULL,
	member_ID BIGINT NOT NULL,
	privilege_ID BIGINT NOT NULL,
	site_ID BIGINT NOT NULL,
	PRIMARY KEY (ID),
	FOREIGN KEY (member_ID) REFERENCES MEMBER(ID),
	FOREIGN KEY (privilege_ID) REFERENCES PRIVILEGE_CONST(ID),
	FOREIGN KEY (site_ID) REFERENCES SITE(ID)
);

-- INSERT INTO MEMBER_PRIVILEGE_LINK (ID,member_ID,privilege_ID,site_ID) VALUES (1,,,);
INSERT INTO SEQUENCE (table_name,count) VALUES ('MEMBER_PRIVILEGE_LINK',1);

-------------------------------------------------------------------------------
-- Table:			TEST	
-------------------------------------------------------------------------------
-- Description:	Used by the test rig
-------------------------------------------------------------------------------
-- Name						Usage
-- -------------------- ------------------------------------------------------- 
-- ID							The unique identifier for the row
-- number					A number
-- string					A character string
-- date						A date
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS TEST;
CREATE TABLE TEST
(
	ID BIGINT NOT NULL,
	test_number INT NOT NULL,
	test_string VARCHAR(50) NOT NULL,
	test_date DATE,
	PRIMARY KEY (ID)
);

-- INSERT INTO MEMBER_PRIVILEGE_LINK (ID,member_ID,privilege_ID) VALUES (1,,);
INSERT INTO SEQUENCE (table_name,count) VALUES ('TEST',1);

