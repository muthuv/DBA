/*=============================================================================
	This StorProc drops all users from the DB and adds users from Work Table

	StorProc to drop all users from newly deployed DB 
	map user accounts from WorkTable to the new DB
	After successful move all rows from WorkTable to HistoryTable and truncate WorkTable
--=============================================================================*/

CREATE PROCEDURE [dbo].[CleanupAndReMap]
	@DestDB Sysname
AS
-- Check whether SystemDBs are being modified and AntiInjection check..
	IF dba.dbo.sfAntiInjection (@DestDB) = 0
	
BEGIN 
	PRINT CHAR(13) + CHAR(9) + 'System databases are not allowed!';
	RETURN 1;
END
ELSE
BEGIN
	SET NOCOUNT ON

	DECLARE @User			Sysname;
	DECLARE @i				smallint;
	DECLARE @DropCommand	NVARCHAR(MAX)
	DECLARE @sql			NVARCHAR(MAX)
	DECLARE @Role			Sysname
	DECLARE @Permission		Nvarchar(128)
	DECLARE @State			Nvarchar(60)
	DECLARE @sql1			Nvarchar(MAX)
	DECLARE @sql2			Nvarchar(MAX)

-- Checking if any users exist for @DestDB if not terminating
	IF EXISTS (SELECT * FROM dbo.Work_Role_Access WHERE DBName = @DestDB)
		BEGIN
-- Getting the list of all users in the database 
			IF OBJECT_ID('tempdb..##tab') IS NOT NULL
				DROP TABLE ##tab;
			CREATE TABLE ##tab (Name Sysname NOT NULL);

			SET @sql = 'INSERT INTO ##tab (Name)
			SELECT dp.name 
			FROM		' + @DestDB + '.sys.database_role_members as drm
			JOIN		' + @DestDB + '.sys.database_principals AS dp ON dp.principal_id = drm.member_principal_id
			WHERE		dp.principal_id > 1
			UNION 
			SELECT dp.name AS [Name]
			FROM		' + @DestDB + '.sys.database_principals AS dp
			JOIN		' + @DestDB + '.sys.database_permissions AS dper ON dp.principal_id = dper.grantee_principal_id
			WHERE dp.name NOT IN (''public'', ''guest'', ''dbo'') AND dper.major_id > -1'
			EXEC sp_executesql @sql
			SELECT TOP 1 @User = Name FROM ##tab

--Drops all users from the database
			WHILE @User IS NOT NULL
				BEGIN TRY
					SET @DropCommand = 'USE ' +@DestDB+ '; DROP USER [' + @User +'];'
					--PRINT @DropCommand																--Test
					EXEC sys.sp_executesql @DropCommand
					DELETE FROM ##tab WHERE @User = Name
					SET @User = NULL
					SELECT TOP 1 @User = Name FROM ##tab
				END TRY
				BEGIN CATCH
					Print 'Error: '+ CAST(ERROR_NUMBER() AS varchar(20))  + '; ' + CAST(ERROR_MESSAGE() AS VARCHAR(MAX))
					DELETE FROM ##tab WHERE @User = Name
					SET @User = NULL
					SELECT TOP 1 @User = Name FROM ##tab
				END CATCH

-- Loading Users from WorkTable and creating users in the DestDB
-- Creating new table ##tab1 but it is probably not needed as it is all in the same StoreProc
			IF OBJECT_ID('tempdb..##tab1') IS NOT NULL
				DROP table ##tab1
			CREATE TABLE ##tab1 (ID int identity, Name SysName, RoleName Sysname NULL, PermissionName Nvarchar(128) NULL, [State] Nvarchar(60) NULL)
		
			INSERT INTO ##tab1 (Name, RoleName, PermissionName, [State])
				SELECT Name, RoleName, PermissionName, [State] FROM dbo.Work_Role_Access
				WHERE DBName = @DestDB
				AND Deleted = 'No';

			PRINT 'Database: ' + @DestDB + '. Permissions to apply: ' + CAST(@@ROWCOUNT AS NVARCHAR(MAX))
			SELECT TOP 1 @User = Name FROM ##tab1 ORDER BY ID
			WHILE @User IS NOT NULL
				
				BEGIN TRY
					SET @sql1 = 'USE ' + @DestDB + '; CREATE USER [' + @User + '] FOR LOGIN [' + @User +'];'
					EXEC sp_executesql @sql1

					SELECT TOP 1 @i = ID FROM ##tab1 WHERE NAME = @User
					WHILE @i IS NOT NULL
					BEGIN
						SELECT	@sql2 = CASE 
											WHEN RoleName IS NOT NULL  THEN 'USE ' + @DestDB + '; ALTER ROLE ' + [RoleName] + ' ADD MEMBER [' + [Name] +'];'
											WHEN PermissionName IS NOT NULL THEN 'USE ' + @DestDB + '; ' + [State]  + ' ' + [PermissionName] + ' TO [' + [Name] + '];'
										END
						FROM	##tab1 
						WHERE	Name = @User 
						AND		ID = @i;
					
						EXEC sp_executeSQL @sql2
						DELETE FROM ##tab1 WHERE Name = @User AND ID = @i
						SET @i = NULL
						SELECT TOP 1 @i = ID FROM ##tab1 WHERE Name = @User
					END

					SET @User = NULL;
					SELECT @User = Name  FROM ##tab1
				END TRY
				BEGIN CATCH
					Print 'Error: '+ CAST(ERROR_NUMBER() AS varchar(20))  + '; ' + CAST(ERROR_MESSAGE() AS VARCHAR(MAX))
					Print 'Error for user: ' + CAST(@user AS VARCHAR(MAX))
					DELETE FROM ##tab1 WHERE Name = @User
					SET @User = NULL
					SELECT TOP 1 @User = Name FROM ##tab1 ORDER BY ID
				END CATCH
			
-- If you want work table to be wiped everytime user accounts get applied
				DECLARE @BatchID INT = (SELECT COALESCE(MAX(BatchID),0) FROM dbo.HistoryRole_Access	WHERE DBName = @DestDB) 
		
				DELETE FROM dbo.Work_Role_Access
					OUTPUT @BatchID+1  --increasing batch ID 
						, deleted.DBName, deleted.PrincipalID, deleted.Name, deleted.LoginType, deleted.RoleName, deleted.PermissionName, deleted.[State], deleted.Deleted, SUSER_NAME() ,deleted.Dt
					INTO dbo.HistoryRole_Access
					WHERE DBName = @DestDB
	
				PRINT 'Worked Table emptied out. Records Removed: ' + CAST(@@ROWCOUNT AS NVARCHAR(MAX))
				
				IF OBJECT_ID('tempdb..##tab', N'U') IS NOT NULL
					DROP TABLE ##tab
				IF OBJECT_ID('tempdb..##tab1',N'U') IS NOT NULL
					DROP TABLE ##tab1
			END
		ELSE
			BEGIN
				Print 'Error: There is no records in the Work table for database: ' + @DestDB  +'. Please run the stored procedure dbo.InsIntoWrkTab'
			END
END

RETURN 0
