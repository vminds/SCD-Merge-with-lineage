CREATE PROCEDURE [dbo].[prc_UpdateLineage]
	@parTableName VARCHAR(100) = NULL,
	@parPackageName VARCHAR(100) = '',
	@parLoadStart DATETIME2(7) = NULL,
	@parLoadEnd DATETIME2(7) = NULL,
	@parSuccess BIT = 0,
	@parRecordsInserted BIGINT = NULL,
	@parRecordsUpdated BIGINT = NULL,
	@parXmlInserted XML NULL,
	@parXmlUpdated XML NULL,
	@parSSISExecutionID BIGINT = 0
	
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @TableName VARCHAR(100) = NULL
DECLARE @SchemaName VARCHAR(10) = NULL
DECLARE @tblOutput TABLE ([Action] VARCHAR(50), LineageID SMALLINT)
DECLARE @tbl VARCHAR(100) = (SELECT COALESCE(@parTableName, @parPackageName))


SET @TableName = UPPER((
    SELECT TOP 1 t.[name]
    FROM [sys].[tables] t
    WHERE t.[name] = @tbl
    AND t.[type]='U'
    ))

IF @TableName IS NULL
BEGIN
    PRINT N'Cannot find SQL table based on PackageName param, ensure they do equal';
    THROW 51000, N'Cannot find SQL table based on PackageName param, ensure they do equal', 1;
    RETURN -1;
END

SET @SchemaName = UPPER((
    SELECT TOP 1 s.[name]
    FROM [sys].[tables] t
    INNER JOIN [sys].[schemas] s ON s.[schema_id]=t.[schema_id]
    WHERE t.[name] = @tbl
    AND t.[type]='U'
    ))

-- main lineage table
MERGE dbo.Lineage AS T
USING (SELECT @SchemaName AS SchemaName
		  ,@TableName AS TableName
		  ,@parLoadStart AS LoadStart
		  ,@parLoadEnd AS LoadEnd
		  ,@parSuccess AS Success
		  ,@parRecordsInserted AS RecordsInserted
		  ,@parRecordsUpdated AS RecordsUpdated
		  ,@parSSISExecutionID AS SSISExecutionID
		  ,@parPackageName AS PackageName
	    ) AS S
ON T.SchemaName=S.SchemaName AND T.TableName=S.TableName AND T.PackageName=S.PackageName
WHEN NOT MATCHED BY TARGET THEN
INSERT (SchemaName, TableName, PackageName, LoadStart, LoadEnd, Success, RecordsInserted, RecordsUpdated, SSISExecutionID)
    VALUES (S.SchemaName, S.TableName, S.PackageName, S.LoadStart, S.LoadEnd, S.Success, S.RecordsInserted, S.RecordsUpdated, S.SSISExecutionID)
WHEN MATCHED THEN UPDATE 
    SET SchemaName=S.SchemaName, TableName=S.TableName, PackageName=S.PackageName, LoadStart=S.LoadStart, LoadEnd=S.LoadEnd
		  , Success=S.Success, RecordsInserted=S.RecordsInserted, RecordsUpdated=S.RecordsUpdated, SSISExecutionID=S.SSISExecutionID
OUTPUT $action, inserted.LineageID
INTO @tblOutput ([Action], LineageID);


-- lineage details
MERGE [dbo].[LineageDetail] AS T
USING (SELECT (SELECT TOP 1 LineageID FROM @tblOutput) AS LineageID
		  , @parXmlInserted AS xmlInserted
		  , @parXmlUpdated AS xmlUpdated
	   ) AS S
ON T.LineageID=S.LineageID
WHEN NOT MATCHED BY TARGET THEN
INSERT (LineageId, Inserted, Updated)
    VALUES (S.LineageId, S.xmlInserted, S.xmlUpdated)
WHEN MATCHED THEN
    UPDATE SET LineageId=S.LineageId, Inserted=S.xmlInserted, Updated=S.xmlUpdated;

END

