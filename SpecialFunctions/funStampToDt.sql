USE [XSource]
GO

ALTER FUNCTION [dbo].[StampToDt] (@stamp AS BIGINT)
RETURNS DATETIME
AS BEGIN
	DECLARE @c BIGINT
	DECLARE @msp INT
	DECLARE @dp INT
	DECLARE @sDt DATETIME

	SET @c = 86400000
	SET @sDt = '1970-01-01'

	SET @dp = @stamp / @c
	SET @msp = @stamp - @dp * @c

	RETURN DATEADD(millisecond, @msp, DATEADD(DAY, @dp, @sDt))
END


