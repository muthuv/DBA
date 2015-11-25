
/*================================================================================================
	 StorProc to insert DB Roles from the selected database or the HistoryTable to WorkTable 
	 - to be run before dropping the database
================================================================================================*/

CREATE PROCEDURE [dbo].[InsIntoWrkTab]
	@SourceDB sysname
,	@HistTab bit = NULL 
,	@HistoryBatch int = NULL
AS
-- Check whether SystemDBs are being modified and AntiInjection check..
	IF dbo.sfAntiInjection (@SourceDB) = 0

BEGIN 
	PRINT CHAR(13) + CHAR(9) + 'System databases are not allowed!';
	RETURN 1;
END
ELSE
BEGIN
    SET NOCOUNT ON;
	DECLARE @INS			NVARCHAR(MAX)
	DECLARE @TSQLParamDef	NVARCHAR(500) = N'@BatchIDval INT, @SourceDBval sysname'
	DECLARE @BatchID		INT = CASE WHEN @HistoryBatch IS NOT NULL THEN @HistoryBatch
									ELSE (SELECT COALESCE(MAX(BatchID),0) FROM dbo.HistoryRole_Access	WHERE DBName = @SourceDB) 
									END
 
	-- checking if values exist in the History table, if yes delete Work table content and populate with History table records
	Print 'Database: ' + @SourceDB
	IF (@HistTab IS NOT NULL)
		BEGIN 
			IF Exists (SELECT * FROM dbo.HistoryRole_Access WHERE DBName = @SourceDB)
				BEGIN
					PRINT 'Deleting Old Records And Populating Work Table From the History Table'
					DELETE FROM dbo.Work_Role_Access WHERE DBName = @SourceDB;
					PRINT 'Old Records Deleted: ' + CAST(@@ROWCOUNT AS VARCHAR(MAX))
					INSERT dbo.Work_Role_Access (BatchID, DBName, PrincipalID, Name, LoginType, RoleName, PermissionName, [State], Deleted, UserName, Dt)
					SELECT 	BatchID , DBname, PrincipalID, Name, LoginType, RoleName, PermissionName, [State], Deleted, UserName, Dt
						FROM dbo.HistoryRole_Access
						WHERE DBName = @SourceDB AND BatchID = @BatchID
					PRINT 'New Records Inserted: ' + CAST(@@ROWCOUNT AS VARCHAR(MAX))
				END
				-- if records don't exists nothing happens
			ELSE
				Print 'Error: There is no records for the database: ' + @SourceDB  +'. Please re-run the stored procedure without the second parameter as 1.';
		END
	ELSE 
		BEGIN
			-- Checking if any values exist for the queried database and if not populating the Work table
			IF NOT EXISTS(SELECT * FROM dbo.Work_Role_Access WHERE DBName = @SourceDB)
				BEGIN
					-- Load all users with roles
					PRINT 'No Records In Work Table, populating it from ' + @SourceDB 
					SET @INS = N'INSERT INTO dbo.[Work_Role_Access]
					
						SELECT		@BatchIDval
						,			@SourceDBval				AS [DBName]
						,			dp.principal_id				AS [Principal_id]
						,			dp.name						AS [Name]
						,			dp.type_desc				AS [LoginType]
						,			dp1.name					AS [ROLE]
						,			[PermisionName] = NULL
						,			[State] = Null
						,			[Deleted] = CASE 
													WHEN sp.sid IS NULL THEN ''Yes''
													ELSE ''No''
												END
						,			SUSER_SNAME()
						,			CURRENT_TIMESTAMP			AS [Date]
						FROM		'+@SourceDB +'.sys.database_role_members AS drm
						JOIN		'+@SourceDB +'.sys.database_principals AS dp		ON dp.principal_id = drm.member_principal_id
						JOIN		'+@SourceDB +'.sys.database_principals AS dp1		ON dp1.principal_id = drm.role_principal_id
						LEFT JOIN	'+@SourceDB +'.sys.server_principals AS sp			ON sp.[sid] = dp.[sid]							-- showing only Users with mapped Logins
						WHERE dp.principal_id > 1																						-- dbo user
					
						UNION

						SELECT		@BatchIDval
						,			@SourceDBval				AS [DBName]
						,			pri.principal_id			AS [Principal_id]
						,			pri.name					AS [Name]
						,			pri.type_desc				AS [LoginType]
						,			[Role] = NULL
						,			per.permission_name			AS [PermisionName]
						,			per.state_desc				AS [State]
						,			[Deleted] = CASE 
													WHEN sp.sid IS NULL THEN ''Yes''
													ELSE ''No''
												END
						,			SUSER_SNAME()
						,			CURRENT_TIMESTAMP			AS [Date]
						FROM		'+@SourceDB +'.sys.database_principals		AS pri
						JOIN		'+@SourceDB +'.sys.database_permissions		AS per	ON per.grantee_principal_id = pri.principal_id
						LEFT JOIN	'+@SourceDB +'.sys.objects					AS o	ON o.[object_id] = per.major_id
						LEFT JOIN	'+@SourceDB +'.sys.schemas					AS s	ON s.schema_id = o.schema_id
						LEFT JOIN	'+@SourceDB +'.sys.server_principals		AS sp	ON sp.[sid] = pri.[sid]							-- showing only Users with mapped Logins
						WHERE pri.[name] NOT IN (''public'',''guest'',''dbo'')
						AND per.major_id > -1'

					EXEC sp_executeSQL @INS, @TSQLParamDef,
						@BatchIDval = @BatchID,
						@SourceDBval = @SourceDB
					Print 'New Records Inserted: ' + CAST(@@ROWCOUNT AS VARCHAR(MAX))
					--PRINT @INS																	--Testing
				END
			ELSE
				BEGIN
					Print 'There are already records in the Work Table for ' + @SourceDB  +' database. - Deleting them and populating the table from ' + @SourceDB + ' again'
					--Deleting the values for the queried database and populating Work table 
					DELETE FROM dbo.Work_Role_Access WHERE DBName = @SourceDB;
					Print 'Old Records Deleted: ' + CAST(@@ROWCOUNT AS VARCHAR(MAX))
					SET @INS = N'INSERT INTO dbo.[Work_Role_Access]

						SELECT		@BatchIDval
						,			@SourceDBval				AS [DBName]
						,			dp.principal_id				AS [Principal_id]
						,			dp.name						AS [Name]
						,			dp.type_desc				AS [LoginType]
						,			dp1.name					AS [ROLE]
						,			[PermisionName] = NULL
						,			[State] = Null
						,			[Deleted] = CASE 
													WHEN sp.sid IS NULL THEN ''Yes''
													ELSE ''No''
												END
						,			SUSER_SNAME()
						,			CURRENT_TIMESTAMP			AS [Date]
						FROM		'+@SourceDB +'.sys.database_role_members AS drm
						JOIN		'+@SourceDB +'.sys.database_principals AS dp		ON dp.principal_id = drm.member_principal_id
						JOIN		'+@SourceDB +'.sys.database_principals AS dp1		ON dp1.principal_id = drm.role_principal_id
						LEFT JOIN	'+@SourceDB +'.sys.server_principals AS sp			ON sp.[sid] = dp.[sid]							-- showing only Users with mapped Logins
						WHERE dp.principal_id > 1																						-- dbo user
					
						UNION

						SELECT		@BatchIDval
						,			@SourceDBval				AS [DBName]
						,			pri.principal_id			AS [Principal_id]
						,			pri.name					AS [Name]
						,			pri.type_desc				AS [LoginType]
						,			[Role] = NULL
						,			per.permission_name			AS [PermisionName]
						,			per.state_desc				AS [State]
						,			[Deleted] = CASE 
													WHEN sp.sid IS NULL THEN ''Yes''
													ELSE ''No''
												END
						,			SUSER_SNAME()
						,			CURRENT_TIMESTAMP			AS [Date]
						FROM		'+@SourceDB +'.sys.database_principals		AS pri
						JOIN		'+@SourceDB +'.sys.database_permissions		AS per	ON per.grantee_principal_id = pri.principal_id
						LEFT JOIN	'+@SourceDB +'.sys.objects					AS o	ON o.[object_id] = per.major_id
						LEFT JOIN	'+@SourceDB +'.sys.schemas					AS s	ON s.schema_id = o.schema_id
						LEFT JOIN	'+@SourceDB +'.sys.server_principals		AS sp	ON sp.[sid] = pri.[sid]							-- showing only Users with mapped Loginsr
						WHERE pri.[name] NOT IN (''public'',''guest'',''dbo'')
						AND per.major_id > -1'

					EXEC sp_executeSQL @INS, @TSQLParamDef,
						@BatchIDval = @BatchID,
						@SourceDBval = @SourceDB
					Print 'New Records Inserted: ' + CAST(@@ROWCOUNT AS VARCHAR(MAX))
				--PRINT @INS																	--Testing							
				END
			END
	Print CHAR(13)
END

RETURN 0
