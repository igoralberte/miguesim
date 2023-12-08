--==================================================================================================
------ Distance Functions over ARRAYS ------ =======================================================
--==================================================================================================
DROP FUNCTION IF EXISTS ManhattanDist(A ANYARRAY, B ANYARRAY);
DROP FUNCTION IF EXISTS EuclideanDist(A ANYARRAY, B ANYARRAY);
DROP FUNCTION IF EXISTS InfinityDist(A ANYARRAY, B ANYARRAY);
DROP FUNCTION IF EXISTS CosineDist(A ANYARRAY, B ANYARRAY);

-- Manhattan ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ManhattanDist(A ANYARRAY, B ANYARRAY) RETURNS DOUBLE PRECISION 
    AS $$
        DECLARE
            Dim INT;
            Tot DOUBLE PRECISION:=0.0;
        BEGIN
            Dim:=LEAST(Array_Length(A,1), Array_Length(B,1));
            FOR i IN 1..Dim LOOP
                Tot:=Tot+ABS(A[i]-B[i]);
            END LOOP;
            RETURN Tot;
        END;
$$  LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT;


-- Euclidean ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION EuclideanDist(A ANYARRAY, B ANYARRAY) RETURNS DOUBLE PRECISION 
    AS $$
        DECLARE
            Dim INT;
            Tot DOUBLE PRECISION:=0.0;
        BEGIN
            Dim:=LEAST(Array_Length(A,1), Array_Length(B,1));
            FOR i IN 1..Dim LOOP
                Tot:=Tot+(A[i]-B[i])^2;
            END LOOP;
            RETURN SQRT(Tot);
        END;
$$  LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT;


-- Infinity ----------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION InfinityDist(A ANYARRAY, B ANYARRAY) RETURNS DOUBLE PRECISION 
    AS $$
        DECLARE
            Dim INT;
            Tot DOUBLE PRECISION:=0.0;
        BEGIN
            Dim:=LEAST(Array_Length(A,1), Array_Length(B,1));
            FOR i IN 1..Dim LOOP
                Tot:=GREATEST(Tot,ABS(A[i]-B[i]));
            END LOOP;
            RETURN Tot;
        END;
$$  LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT;


-- Cosine ------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION CosineDist(A ANYARRAY, B ANYARRAY) RETURNS DOUBLE PRECISION 
    AS $$
        DECLARE
            Dim INT;
            Tot DOUBLE PRECISION:=0.0;
            TotA DOUBLE PRECISION:=0.0;    TotB DOUBLE PRECISION:=0.0;
        BEGIN
            Dim:=LEAST(Array_Length(A,1), Array_Length(B,1));
            FOR i IN 1..Dim LOOP
                Tot:=Tot+A[i]*B[i];
                TotA:=TotA+A[i]^2;
                TotB:=TotB+B[i]^2;
            END LOOP;
            IF TotA*TotB=0 THEN RETURN 1;
              ELSE RETURN 1-Tot/(SQRT(TotA)*SQRT(TotB));
              END IF;
        END;
$$  LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT;
