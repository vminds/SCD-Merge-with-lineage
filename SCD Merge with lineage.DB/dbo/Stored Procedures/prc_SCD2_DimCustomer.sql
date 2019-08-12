CREATE PROCEDURE dbo.prc_SCD2_DimCustomer
    @ForceUpdate TINYINT = 0,
    @SSISPackage VARCHAR(100) = '',
    @SSISExecutionID BIGINT = 0
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

BEGIN TRAN

DECLARE @LoadStart DATETIME2(7) = GETDATE()
DECLARE @LoadEnd DATETIME2(7) = NULL
DECLARE @tblOutput TABLE ([Action] VARCHAR(50), BK VARCHAR(255), [Key] BIGINT)
DECLARE @Success INT = 1
DECLARE @cntInserted BIGINT = 0
DECLARE @cntUpdated BIGINT = 0
DECLARE @xmlUpdated XML = NULL
DECLARE @xmlInserted XML = NULL

CREATE TABLE #DimCustomer ([Action] VARCHAR(10), [Key] INT, BK VARCHAR(10) NOT NULL, [Name] NVARCHAR(100) NULL, CreditLimit DECIMAL(18, 2) NULL, isOnCreditHold VARCHAR(3) NULL,
							PaymentDays INT NULL, PhoneNumber VARCHAR(20) NULL, Website VARCHAR(255) NULL, PostalCode VARCHAR(10) NULL,
							LastUpdated DATETIME2(7) NOT NULL, ValidFrom DATETIME2(7) NOT NULL, ValidTo DATETIME2(7) NOT NULL, IsRowCurrent BIT NOT NULL)

-- when using the SCD2 approach, an insert into a temporary table is required due to "INSERT statement cannot be on either side of a (primary key, foreign key)" limitation.
-- in this exact example it works without the temp table, as there is no FK constraint. But typically you will have on fact tables.
INSERT INTO #DimCustomer ([Action], [Key], BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode, LastUpdated, ValidFrom, ValidTo, IsRowCurrent)
	SELECT [Action], [Key], BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode, GETDATE(), GETDATE(),'9999-12-31',1
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
				IsRowCurrent	= 0
				,LastUpdated    = GETDATE()
				,ValidTo        = GETDATE()
			WHEN NOT MATCHED BY TARGET
			THEN INSERT (BK ,[Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode, LastUpdated, ValidFrom, ValidTo, IsRowCurrent)
				  VALUES (S.BK, S.[Name], S.CreditLimit, S.isOnCreditHold, S.PaymentDays, S.PhoneNumber, S.Website, S.PostalCode, GETDATE(), GETDATE(),'9999-12-31',1)
			WHEN NOT MATCHED BY SOURCE AND T.IsRowCurrent = 1
			THEN UPDATE SET
				IsRowCurrent	= 0
				,LastUpdated	= GETDATE()
				,ValidTo		= GETDATE()
	   OUTPUT $action AS [Action]
			,Inserted.CustomerKey AS [Key]
            ,S.*
		) AS MergeOutput


-- now insert the updated record as a new record into the actual table
INSERT INTO dbo.DimCustomer (BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode,
								LastUpdated, ValidFrom, ValidTo, IsRowCurrent)
	SELECT BK, [Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode,
								LastUpdated, ValidFrom, ValidTo, IsRowCurrent
	FROM #DimCustomer
	WHERE [Action] = 'UPDATE'


COMMIT TRAN

IF @@ERROR<>0 SET @Success=@@ERROR


-- persist lineage
SET @LoadEnd = GETDATE()
SET @cntInserted = ISNULL((SELECT COUNT(*) FROM #DimCustomer WHERE [Action]='INSERT'),0)
SET @cntUpdated = ISNULL((SELECT COUNT(*) FROM #DimCustomer WHERE [Action]='UPDATE'),0)
SET @xmlInserted = (SELECT BK, [Key] FROM #DimCustomer WHERE [Action]='INSERT' FOR XML PATH('DimCustomer'))
SET @xmlUpdated = (SELECT BK, [Key] FROM #DimCustomer WHERE [Action]='UPDATE' FOR XML PATH('DimCustomer'))

EXEC [dbo].[prc_UpdateLineage]
	@parTableName = 'DimCustomer',
	@parPackageName = @SSISPackage,
	@parLoadStart = @LoadStart,
	@parLoadEnd = @LoadEnd,
	@parSuccess = @Success,
	@parRecordsInserted = @cntInserted,
	@parRecordsUpdated = @cntUpdated,
	@parSSISExecutionID = @SSISExecutionID,
	@parXmlInserted = @xmlInserted,
	@parXmlUpdated = @xmlUpdated
	

END



