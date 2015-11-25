CREATE TABLE [dbo].[FreeSpaceAudit]
(
	[DateRecorded]			[date]				NOT NULL,
	[DatabaseName]			[sysname]			NOT NULL,
	[FileID]				[int]				NOT NULL,
	[FileSizeMB]			[decimal](12, 2)	NOT NULL,
	[SpaceUsedMB]			[decimal](12, 2)	NOT NULL,
	[FreeSpaceMB]			[decimal](12, 2)	NOT NULL,
	[PercentageFull]		[decimal](12, 2)	NOT NULL,
	[LogicalFileName]		[sysname]			NOT NULL,
	[Filename]				[nvarchar](1000)	NOT NULL
	CONSTRAINT [PK_FreeSpaceAudit] PRIMARY KEY CLUSTERED 
	(	
		[DatabaseName] ASC
	,	[FileID] ASC
	,	[DateRecorded] ASC
	)
)
