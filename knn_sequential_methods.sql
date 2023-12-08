DROP FUNCTION IF EXISTS Select_KNN_Sequential;

-- REALIZA CONSULTA KNN UTILIZANDO ACESSO SEQUENCIAL DE DUAS FORMAS DIFERENTES
-- Relation: relation's name
-- Atr: name of the complex attribute (type of the attribute: DOUBLE PRECISION[])
-- DF: distance function name. Available: euclideandist, manhattandist, infinitydist
-- Center: DOUBLE PRECISION vector which represents the query center
-- k: number of neighbors
-- ID_p: name of the identification attribute of the relation. Default: 'id'
-- query_mode: specifies which query writing the user wishes; 1 = with RANK; 2 = without RANK
-- RETORNO: table (Answer, Distance, k_order)
--- Answer: is a tuple of the queried relation concatenated
--- Distance: distance of the object represented by Answer and the center
--- k_order: order of the Answer element retrieved
CREATE OR REPLACE FUNCTION Select_KNN_Sequential (Relation VARCHAR, Atr VARCHAR, DF VARCHAR, Center DOUBLE PRECISION[], 
        K INTEGER DEFAULT 1, ID_p VARCHAR DEFAULT 'id', query_mode INTEGER DEFAULT 1)
    RETURNS TABLE (ANSWER VARCHAR, Distance DOUBLE PRECISION, kOrd INTEGER) AS $$ 
    --, KOrder INTEGER) AS 
DECLARE
    Var_r RECORD; Var_Cmd TEXT;  Var_Func TEXT; Direction TEXT; Var_Distinct TEXT;  
    UnT VARCHAR; CC VARCHAR; DFT VARCHAR; F VARCHAR;
    R1 RegType;   ParamV TEXT;
    var_idx_name TEXT; var_idx_table TEXT; var_idx_attrib_complex TEXT; var_distance_function TEXT;
BEGIN
    IF DF IS NULL OR Center IS NULL THEN RETURN; END IF;
    
    CC:='REL.'||Atr;
    
    SELECT Value INTO ParamV FROM SimilarQL_Settings WHERE Param='similarql_d_trace';

    IF ParamV='true' THEN 
        RAISE NOTICE 'Query mode: %', query_mode; 
    END IF;
        
    Direction:='::FLOAT ASC';
    
    DFT:=DF||'($1, '||CC;

    --Var_Cmd:='SELECT * FROM (SELECT ';  
    

    IF query_mode = 1 THEN -- Query knn with RANK - SimilarQL
        --ORIGINAL VERSION
        Var_Cmd:='SELECT * FROM (SELECT (REL)::VARCHAR Ch, ' || DFT || ')::DOUBLE PRECISION Dist,
            RANK() OVER (ORDER BY '||DFT||')'||Direction ||')::INTEGER AS kOrd FROM '||Relation||' REL) AS ids_distances
            WHERE kOrd <= ' || K;
        
    ELSIF query_mode = 2 THEN -- Query knn without RANK - MIGUE-Sim
        --VERSION WITHOUT KORDER -- Korder = 0 for all tuples
        Var_Cmd:= 'SELECT (REL)::VARCHAR Ch, ' || DFT || ')::DOUBLE PRECISION Dist,
			0::INTEGER AS kOrd FROM '||Relation||' REL ORDER BY Dist LIMIT ' || K;
    END IF;
        

    IF ParamV='true' THEN RAISE NOTICE E'Select_KNN k:= %. Statement:%', K, Var_Cmd; END IF;
    FOR Var_r IN EXECUTE Var_Cmd USING Center LOOP
            ANSWER:=Var_r.Ch;
            Distance:=Var_r.Dist;
            KOrd:=Var_r.kOrd;
            RETURN NEXT;
        END LOOP;

END; $$ LANGUAGE 'plpgsql' VOLATILE;