CREATE TABLE [dbo].[Lineage] (
    [LineageID]				SMALLINT IDENTITY(1,1),
    [SchemaName]			VARCHAR (10) NOT NULL,
    [TableName]				VARCHAR (100) NOT NULL,
    [PackageName]			VARCHAR (100) NOT NULL,
    [LoadStart]				DATETIME2 (7) NOT NULL,
    [LoadEnd]				DATETIME2 (7) NOT NULL,
    [Success]				BIT NOT NULL,
    [RecordsInserted]		BIGINT NOT NULL,
    [RecordsUpdated]		BIGINT NOT NULL,
    [SSISExecutionID]		BIGINT NOT NULL,
    [ValidFrom]				DATETIME2 (7) GENERATED ALWAYS AS ROW START NOT NULL,
    [ValidTo]				DATETIME2 (7) GENERATED ALWAYS AS ROW END   NOT NULL,
    CONSTRAINT [PK_Lineage_LineageID] PRIMARY KEY CLUSTERED ([LineageID] ASC),
    PERIOD FOR SYSTEM_TIME ([ValidFrom], [ValidTo])
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE=[dbo].[LineageHistory], DATA_CONSISTENCY_CHECK=ON));
GO


