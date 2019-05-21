CREATE PROCEDURE dbo.prc_SCD1_DimCustomer
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
		T.[Name] = S.[Name]
		, T.CreditLimit = S.CreditLimit
		, T.isOnCreditHold = S.isOnCreditHold
		, T.PaymentDays = S.PaymentDays
		, T.PhoneNumber = S.PhoneNumber
		, T.Website = S.Website
		, T.PostalCode = S.PostalCode
		, T.LastUpdated = GETDATE()
    WHEN NOT MATCHED BY TARGET
    THEN INSERT (BK ,[Name], CreditLimit, isOnCreditHold, PaymentDays, PhoneNumber, Website, PostalCode, LastUpdated, ValidFrom, ValidTo, IsRowCurrent)
		  VALUES (S.BK, S.[Name], S.CreditLimit, S.isOnCreditHold, S.PaymentDays, S.PhoneNumber, S.Website, S.PostalCode, GETDATE(), GETDATE(),'9999-12-31',1)
    OUTPUT $action, Inserted.BK, Inserted.CustomerKey
    INTO @tblOutput([Action], BK, [Key]);

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

