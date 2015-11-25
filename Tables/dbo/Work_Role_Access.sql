CREATE TABLE [dbo].[Work_Role_Access]
(
	BatchID				int				NOT NULL,
	DBName				nvarchar(128)	NOT NULL,
	PrincipalID			INT				NOT NULL,
	Name				Sysname			NOT NULL,
	LoginType			nvarchar(60)	NOT NULL,
	RoleName			Sysname			NULL,
	PermissionName		Nvarchar(128)	NULL,
	[State]				Nvarchar(60)	NULL,
	Deleted				Char(3)			NOT NULL,
	UserName			nvarchar(128)	NOT NULL,
	Dt					DateTime		NOT NULL
)
