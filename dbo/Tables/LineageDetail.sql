CREATE TABLE [dbo].[LineageDetail] (
    [LineageDetailID]		SMALLINT IDENTITY(1,1),
    [LineageID]				SMALLINT,
    [Inserted]				XML,
    [Updated]				XML,
    [ValidFrom]				DATETIME2 (7) GENERATED ALWAYS AS ROW START NOT NULL,
    [ValidTo]				DATETIME2 (7) GENERATED ALWAYS AS ROW END   NOT NULL,
    CONSTRAINT [PK_LineageDetail_LineageDetailID] PRIMARY KEY CLUSTERED ([LineageDetailID] ASC),
    PERIOD FOR SYSTEM_TIME ([ValidFrom], [ValidTo])
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE=[dbo].[LineageDetailHistory], DATA_CONSISTENCY_CHECK=ON));
GO

ALTER TABLE [dbo].[LineageDetail] ADD CONSTRAINT FK_LineageDetail_LineageID FOREIGN KEY (LineageID)
REFERENCES [dbo].[Lineage] ([LineageID])
GO


