CREATE PROCEDURE [dbo].[RecordFreeSpace]
AS

	SET NOCOUNT ON

		DECLARE 
			@CurrentDB sysname,
			@SQL NVARCHAR(MAX);

		DECLARE DBCursor CURSOR FORWARD_ONLY STATIC READ_ONLY
		FOR SELECT name FROM sys.databases WHERE state_desc = 'ONLINE';

		OPEN DBCursor;

		FETCH NEXT FROM DBCursor INTO @CurrentDB;

		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			SET @SQL = N'
			USE ' + QUOTENAME(@CurrentDB) + '
			INSERT INTO DBA.dbo.FreeSpaceAudit
			SELECT
				CAST(CURRENT_TIMESTAMP AS DATE),      
				DB_NAME() AS DatabaseName,      
				a.file_id,
				[FILE_SIZE_MB] = convert(decimal(12,2),round(a.size/128.000,2)),
				[SPACE_USED_MB] = convert(decimal(12,2),round(fileproperty(a.name,''SpaceUsed'')/128.000,2)),
				[FREE_SPACE_MB] = convert(decimal(12,2),round((a.size-fileproperty(a.name,''SpaceUsed''))/128.000,2)) ,
				PercentageFull = CONVERT(DECIMAL(12,2),((convert(decimal(12,2),round(fileproperty(a.name,''SpaceUsed'')/128.000,2)))/(convert(decimal(12,2),round(a.size/128.000,2))) * 100)),
				LogicalName = a.NAME,
				a.physical_name
			FROM sys.database_files a
			WHERE a.type_desc <> ''LOG'';';

			EXEC [master].[sys].[sp_executesql] @SQL;
	
			FETCH NEXT FROM DBCursor INTO @CurrentDB;
		END

		CLOSE DBCursor;
		DEALLOCATE DBCursor;

RETURN 0
