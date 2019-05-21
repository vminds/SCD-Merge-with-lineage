CREATE TABLE dbo.DimCustomer (
    CustomerKey INT NOT NULL IDENTITY,
    BK VARCHAR(10) NOT NULL,
    [Name] NVARCHAR(100) NULL,
	CreditLimit DECIMAL(18,2) NULL,
	isOnCreditHold VARCHAR(3) NULL,
	PaymentDays INT NULL,
	PhoneNumber	VARCHAR(20) NULL,
	Website VARCHAR(255) NULL,
	PostalCode VARCHAR(10) NULL,
    LastUpdated DATETIME2(7) NOT NULL,
    ValidFrom DATETIME2(7) NOT NULL,
    ValidTo DATETIME2(7) NOT NULL,
    IsRowCurrent BIT NOT NULL
    PRIMARY KEY CLUSTERED (CustomerKey)
    );
GO




