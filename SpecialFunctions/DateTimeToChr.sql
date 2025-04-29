USE [XSource]
GO

CREATE FUNCTION [dbo].[DatetimeToCh] (@d AS DATETIME)
RETURNS VARCHAR (MAX)
AS BEGIN
	RETURN DATENAME(YY, @d) + '-' + CAST(MONTH(@d) AS varchar) + '-' + DATENAME(DAY, @d) + ' ' + DATENAME(HOUR, @d) + ':' + DATENAME(MINUTE, @d)
END


