--==================================================================================================
------ Definition of execution parameters   ---------------- =======================================
--==================================================================================================
DROP TABLE  IF EXISTS SimilarQL_Settings;
CREATE TABLE SimilarQL_Settings(
    Param  TEXT PRIMARY KEY,
    Value  TEXT);
INSERT INTO SimilarQL_Settings VALUES ('similarql_d_trace', 'false');
INSERT INTO SimilarQL_Settings VALUES ('similarql_GCD_Unit', 'k');        -- k=Km, m=Miles, n=Nautical Miles, y=Yards, everything else=meters (case insensitive)
INSERT INTO SimilarQL_Settings VALUES ('similarql_p_norm', '2.0');
INSERT INTO SimilarQL_Settings VALUES ('similarql_FDGPowPow', '2.0');
INSERT INTO SimilarQL_Settings VALUES ('similarql_FDGQuantile', '0.25');  -- First quantile (25%)

DROP FUNCTION IF EXISTS    SimilarQL_SetParam (P TEXT, V TEXT);
CREATE OR REPLACE FUNCTION SimilarQL_SetParam (P TEXT, V TEXT) RETURNS INTEGER AS $$ BEGIN
    UPDATE SimilarQL_Settings SET Value=V WHERE Lower(Param)=Lower(P);
    RETURN 0;
END; $$ LANGUAGE 'plpgsql';

DROP FUNCTION IF EXISTS    SimilarQL_ShowParam (P TEXT);
CREATE OR REPLACE FUNCTION SimilarQL_ShowParam (P TEXT) RETURNS TEXT AS $$
DECLARE V TEXT;
BEGIN
    SELECT Value INTO V FROM SimilarQL_Settings WHERE Lower(Param)=Lower(P);
    RETURN V;
END; $$ LANGUAGE 'plpgsql';

--==================================================================================================
------ SELECT KNN Function ------ ==================================================================
-- Select_KNN (Relation, Atr, DF, Center, K, seq_scan) 						  --
--==================================================================================================

-- The feature vector must be an ARRAY and be named as feature_Vector
-- The table must have a feature vector as a CUBE attribute called feature_cube

-- Relation: relation's name
-- Atr: name of the complex attribute (type of the attribute: DOUBLE PRECISION[])
-- DF: distance function name. Available: euclideandist, manhattandist, infinitydist
-- Center: DOUBLE PRECISION vector which represents the query center
-- k: number of neighbors
-- seq_scan: if TRUE, forces the sequential access
-- Center: array that represents the query center (feature_vector)
DROP FUNCTION IF EXISTS Select_KNN (Relation VARCHAR, Atr VARCHAR, DF VARCHAR, Center ANYELEMENT, K INTEGER, seq_scan BOOL);

CREATE OR REPLACE FUNCTION Select_KNN (Relation VARCHAR, Atr VARCHAR, DF VARCHAR, Center ANYELEMENT, K INTEGER DEFAULT 1, seq_scan BOOL DEFAULT FALSE)
    RETURNS TABLE (ANSWER VARCHAR, Distance DOUBLE PRECISION) AS $$
DECLARE
    Var_r RECORD; Var_Cmd TEXT;  CC VARCHAR; DFT VARCHAR; F VARCHAR;
    ParamV TEXT; r_tree_exists INTEGER; Var_Cmd_analysis TEXT;
BEGIN
	
    IF DF IS NULL OR Center IS NULL THEN RETURN; END IF;
	r_tree_exists = 0; 
    CC:='REL.'||Atr;
    SELECT Value INTO ParamV FROM SimilarQL_Settings WHERE Param='similarql_d_trace';
    IF K<1 THEN K:=1; END IF;
    F:='LIMIT '||K;    
	
	DFT:=DF||'($1, '||CC;
	
	--TESTS IF EXISTS AN R-TREE OVER THE ATTRIBUTE CUBE OF THE RELATION
	EXECUTE 'select 1 where exists (select 
					t.relname as table_name,
					i.relname as index_name,
					a.attname as column_name
					from
						pg_class t,
						pg_class i,
						pg_index ix,
						pg_attribute a
					where
						t.oid = ix.indrelid
						and i.oid = ix.indexrelid
						and a.attrelid = t.oid
						and a.attnum = ANY(ix.indkey)
						and t.relkind = $1
						and t.relname = $2
						and a.attname = $3
					order by
						t.relname,
						i.relname
					)' USING 'r', Relation, 'feature_cube' INTO r_tree_exists;
	RAISE NOTICE 'Existe R-tree? %', r_tree_exists;
	
	--If the R-Tree exists, then the query should be executed with feature_cube attribute and distance function
	IF r_tree_exists = 1 AND array_length(Center, 1) <= 100 AND seq_scan = FALSE AND 
		(lower(DF) = 'euclideandist' OR lower(DF) = 'manhattandist' OR lower(DF) = 'infinitydist') THEN 
		IF lower(DF) = 'euclideandist' THEN -- <->
				Var_Cmd:= 'SELECT (REL)::VARCHAR Ch, (cube($1) <-> REL.feature_cube)::DOUBLE PRECISION Dist
					FROM '||Relation||' REL ORDER BY Dist ' || F;
			ELSEIF lower(DF) = 'manhattandist' THEN -- <#>
				Var_Cmd:= 'SELECT (REL)::VARCHAR Ch, (cube($1) <#> REL.feature_cube)::DOUBLE PRECISION Dist
					FROM '||Relation||' REL ORDER BY Dist ' || F;
			ELSEIF lower(DF) = 'infinitydist' THEN -- <=>
				Var_Cmd:= 'SELECT (REL)::VARCHAR Ch, (cube($1) <=> REL.feature_cube)::DOUBLE PRECISION Dist
					FROM '||Relation||' REL ORDER BY Dist ' || F;
		END IF;
	
	--If there are no R-trees available, the sequential query is used over the feature_vector attribute with ORDER BY and LIMIT clause
		ELSE 
			Var_Cmd:= 'SELECT (REL)::VARCHAR Ch, ' || DFT || ')::DOUBLE PRECISION Dist
				FROM '||Relation||' REL ORDER BY Dist ' || F;
	END IF;    
	
	RAISE NOTICE 'Comando: %', var_cmd;
    IF ParamV='true' THEN RAISE NOTICE E'Select_KNN Center:= %. Statement:%', Center, Var_Cmd; END IF;
	
	--Var_Cmd_analysis := ''
	
    FOR Var_r IN EXECUTE Var_Cmd USING Center LOOP
            ANSWER:=Var_r.Ch;
            Distance:=Var_r.Dist;
            RETURN NEXT;
        END LOOP;
END; $$ LANGUAGE 'plpgsql' VOLATILE;



--==================================================================================================
------ SELECT RANGE ---------------- ===============================================================
--==================================================================================================

-- Relation: relation's name
-- Atr: name of the complex attribute (type of the attribute: DOUBLE PRECISION[])
-- DF: distance function name. Available: euclideandist, manhattandist, infinitydist
-- Center: DOUBLE PRECISION vector which represents the query center
-- radius: query radius
DROP FUNCTION IF EXISTS Select_SimRange (Relation VARCHAR, Atr VARCHAR, DF VARCHAR, Center ANYELEMENT, Radius NUMERIC);

-- SELECT RANGE  -----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION Select_SimRange (Relation VARCHAR, Atr VARCHAR, DF VARCHAR, Center ANYELEMENT, Radius NUMERIC DEFAULT -1.0)
    RETURNS TABLE (ANSWER VARCHAR, Distance DOUBLE PRECISION) AS $$
DECLARE
    Var_r RECORD; Var_Cmd TEXT; Direction TEXT;  F VARCHAR; ParamV TEXT;  DFT VARCHAR;
BEGIN
     
    IF Radius<0 THEN Radius:=0; END IF;
    
    SELECT Value INTO ParamV FROM SimilarQL_Settings WHERE Param='similarql_d_trace';
    DFT:=DF||'($1, REL.'|| Atr ||')';
    Direction:='<=$2';
    Var_Cmd:='SELECT (REL)::VARCHAR Ch, '||DFT||'::DOUBLE PRECISION Dist
        FROM '||Relation||' REL
        WHERE '||DFT||Direction;
		
    IF ParamV='true' THEN RAISE NOTICE E'Select_SimRange Center:= %, Radius:= %. Statement:\n%', Center, Radius, Var_Cmd; END IF;
    FOR Var_r IN EXECUTE Var_Cmd USING Center, Radius LOOP
        ANSWER:=Var_r.Ch;
        Distance:=Var_r.Dist;
        RETURN NEXT;
        END LOOP;
END; $$ LANGUAGE 'plpgsql' VOLATILE;