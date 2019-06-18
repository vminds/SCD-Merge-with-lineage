CREATE VIEW dbo.vw_CustomerStaging
AS

SELECT 
	CS.CustomerID AS BK
	,CS.CustomerName AS [Name]
	,CS.CreditLimit AS CreditLimit
	,CASE CS.isOnCreditHold WHEN 0 THEN 'NO' ELSE 'YES' END isOnCreditHold
	,CS.PaymentDays AS PaymentDays
	,CS.PhoneNumber AS PhoneNumber
	,CS.WebsiteURL AS Website
	,CS.PostalPostalCode AS PostalCode
FROM [dbo].[CustomerStaging] CS

GO

