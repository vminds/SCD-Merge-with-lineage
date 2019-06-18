CREATE PROCEDURE dbo.prc_SCD2_DimCustomer
    @ForceUpdate TINYINT = 0,
    @SSISPackage VARCHAR(100) = '',
    @SSISExecutionID BIGINT = 0
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

BEGIN TRAN

DECLARE @LoadStart DATETIME2 = GETDATE()
DECLARE @LoadEnd DATETIME2 = NULL
DECLARE @cntInserted BIGINT = 0
DECLARE @cntUpdated BIGINT = 0
DECLARE @Success INT = 1
DECLARE @LineageID SMALLINT
DECLARE @tblOutput TABLE ([Action] VARCHAR(50), BK VARCHAR(255), [Key] BIGINT)
DECLARE @xmlUpdated XML = NULL
DECLARE @xmlInserted XML = NULL


CREATE TABLE #DimCustomer (BK VARCHAR(10) NOT NULL, [Name] NVARCHAR(100) NULL, CreditLimit DECIMAL(18, 2) NULL, isOnCreditHold VARCHAR(3) NULL,
							PaymentDays INT NULL, PhoneNumber VARCHAR(20) NULL, Website VARCHAR(255) NULL, PostalCode VARCHAR(10) NULL,
							LastUpdated DATETIME2(7) NOT NULL, ValidFrom DATETIME2(7) NOT NULL, ValidTo DATETIME2(7) NOT NULL, IsRowCurrent BIT NOT NULL)

-- when using this approach, an insert into a temporary table is required due to "INSERT statement cannot be on either side of a (primary key, foreign key)" limitation.
-- in this example it would work with the temp table, as there is no FK constraint. But typically you will have on fact tables.
INSERT INTO #DimCustomer (BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode, LastUpdated, ValidFrom, ValidTo, IsRowCurrent)
	SELECT BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode, GETDATE(), GETDATE(),'9999-12-31',1
	FROM (
			MERGE dbo.DimCustomer AS T
			USING dbo.vw_CustomerStaging AS S
			ON T.BK=S.BK
			WHEN MATCHED AND
				(T.[Name] <> S.[Name]
					OR T.CreditLimit <> S.CreditLimit
					OR T.isOnCreditHold <> S.isOnCreditHold
					OR T.PaymentDays <> S.PaymentDays
					OR T.PhoneNumber <> S.PhoneNumber
					OR T.Website <> S.Website
					OR T.PostalCode <> S.PostalCode
				) OR @ForceUpdate = 1
			THEN UPDATE SET
				IsRowCurrent     = 0
				,LastUpdated      = GETDATE()
				,ValidTo          = GETDATE()
			WHEN NOT MATCHED BY TARGET
			THEN INSERT (BK ,[Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode, LastUpdated, ValidFrom, ValidTo, IsRowCurrent)
				  VALUES (S.BK, S.[Name], S.CreditLimit, S.isOnCreditHold, S.PaymentDays, S.PhoneNumber, S.Website, S.PostalCode, GETDATE(), GETDATE(),'9999-12-31',1)
			WHEN NOT MATCHED BY SOURCE AND T.IsRowCurrent = 1
			THEN UPDATE SET
				IsRowCurrent = 0
				,LastUpdated  = GETDATE()
				,ValidTo      = GETDATE()
	   OUTPUT $action AS Action
            ,S.*
		) AS MergeOutput
	WHERE MergeOutput.Action = 'UPDATE'

-- now insert into the actual table
INSERT INTO dbo.DimCustomer (BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode,
								LastUpdated, ValidFrom, ValidTo, IsRowCurrent)
	SELECT BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode,
								LastUpdated, ValidFrom, ValidTo, IsRowCurrent
	FROM #DimCustomer

DROP TABLE #DimCustomer

COMMIT TRAN

IF @@ERROR<>0 SET @Success=@@ERROR


SET @LoadEnd = GETDATE()
SET @cntInserted = ISNULL((SELECT COUNT(*) FROM @tblOutput WHERE [Action]='INSERT'),0)
SET @cntUpdated = ISNULL((SELECT COUNT(*) FROM @tblOutput WHERE [Action]='UPDATE'),0)
SET @xmlInserted = (SELECT BK, [Key] FROM @tblOutput WHERE [Action]='INSERT' FOR XML PATH('DimCustomer'))
SET @xmlUpdated = (SELECT BK, [Key] FROM @tblOutput WHERE [Action]='UPDATE' FOR XML PATH('DimCustomer'))


EXEC [dbo].[prc_UpdateLineage]
	@parPackageName = @SSISPackage,
	@parLoadStart = @LoadStart,
	@parLoadEnd = @LoadEnd,
	@parSuccess = @Success,
	@parRecordsInserted = @cntInserted,
	@parRecordsUpdated = @cntUpdated,
	@parSSISExecutionID = @SSISExecutionID,
	@parTableName = 'DimCustomer',
	@parLineageID = @LineageID OUTPUT;


MERGE [dbo].[LineageDetail] AS T
USING (SELECT @LineageID AS LineageID
		  , @xmlInserted AS xmlInserted
		  , @xmlUpdated AS xmlUpdated
	   ) AS S
ON T.LineageID=S.LineageID
WHEN NOT MATCHED BY TARGET THEN
INSERT (LineageId, Inserted, Updated)
    VALUES (S.LineageId, S.xmlInserted, S.xmlUpdated)
WHEN MATCHED THEN
    UPDATE SET LineageId=S.LineageId, Inserted=S.xmlInserted, Updated=S.xmlUpdated;


END



