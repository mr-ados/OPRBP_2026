/*
    UFC_OPRBP - 03b_fix_existing_schema_constraints.sql

    Run this only if you already executed 01_create_schema.sql before the
    CK_Fighter_weight fix. It updates the existing check constraint so the
    historical open weight fighter Emmanuel Yarborough (349.27 kg in dataset)
    can be inserted.
*/
USE UFC_OPRBP;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_Fighter_weight'
      AND parent_object_id = OBJECT_ID(N'ufc.Fighter')
)
BEGIN
    ALTER TABLE ufc.Fighter DROP CONSTRAINT CK_Fighter_weight;
END;
GO

ALTER TABLE ufc.Fighter WITH CHECK
ADD CONSTRAINT CK_Fighter_weight
CHECK (weight_kg IS NULL OR weight_kg BETWEEN 35 AND 400);
GO

SELECT name, definition
FROM sys.check_constraints
WHERE name = N'CK_Fighter_weight'
  AND parent_object_id = OBJECT_ID(N'ufc.Fighter');
GO
