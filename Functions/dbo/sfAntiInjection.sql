CREATE FUNCTION [dbo].[sfAntiInjection]
(
	@Input        NVARCHAR(MAX) -- The input to be checked
)
RETURNS BIT
WITH RETURNS NULL ON NULL INPUT
AS
-- =============================================
-- Author:          Paul Harris
-- Create date:		2012-07-11
-- Description:     Checks chars for injection risk characters. Returns 1 if input is valid.
-- Revisions: 
-- =============================================
BEGIN
       -- Declare the return variable here
       DECLARE @Result BIT = 0
       
       IF     NOT EXISTS(
                                  SELECT 1
                                  WHERE			CHARINDEX(';', @Input, 0) > 0
                                  OR            CHARINDEX('''', @Input, 0) > 0
                                  OR            CHARINDEX('--', @Input, 0) > 0
                                  OR            (CHARINDEX('/*', @Input, 0) > 0
                                  AND           CHARINDEX('*/', @Input, 0) > CHARINDEX('/*', @Input, 0))
                                  OR            CHARINDEX('xp_', @Input, 0) > 0
								  OR			CHARINDEX('master',@Input, 0) > 0
								  OR			CHARINDEX('msdb', @Input, 0) > 0
								  OR			CHARINDEX('model', @Input, 0) > 0
								  OR			CHARINDEX('tempdb', @Input, 0) > 0
                           )
       BEGIN
              SET @Result = 1
       END

       -- Return the result of the function
       RETURN @Result
       
END
GO