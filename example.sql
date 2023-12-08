-- INCLUDING EXTENSION CUBE
CREATE EXTENSION IF NOT EXISTS CUBE;

-- TABLE CREATION
DROP TABLE IF EXISTS point_table;
CREATE TABLE point_table(
    id SERIAL PRIMARY KEY,
    x DOUBLE PRECISION,
    y DOUBLE PRECISION,
    z DOUBLE PRECISION,
    feature_vector DOUBLE PRECISION[],
    feature_cube CUBE
);

-- DATA INSERTION
INSERT INTO point_table(x, y, z) VALUES 
    (1, 0, 1), (2, 1, 3), (0, 1, 2), (3, 1, 0),
    (2, 3, 0), (5, 0, 2), (3, 0, 1), (2, 3, 1);

-- UPDATE feature_vector AND feature_cube ATTRIBUTES
UPDATE point_table SET feature_vector = ARRAY[x, y, z]::DOUBLE PRECISION[];
UPDATE point_table SET feature_cube = CUBE(feature_vector);

-- INDEX CREATION
CREATE INDEX point_gist ON point_table USING GIST(feature_cube);

-- QUERY EXECUTION
-- Instead of euclideandist, it could be manhattandist, cosinedist, infinitydist
-- KNN query: center = element with id = 1; k = 5; Euclidean Distance
SELECT (answer::point_table).*, distance FROM 
    select_knn('point_table', 'feature_vector', 'euclideandist',
        (SELECT feature_vector FROM point_table WHERE id = 1),
        5);

-- Range query: center = element with id = 1; radius = 2.5; Manhattan Distance
SELECT (answer::point_table).*, distance FROM 
    select_simrange('point_table', 'feature_vector', 'manhattandist',
        (SELECT feature_vector FROM point_table WHERE id = 1),
        2.5);

-- SEQUENTIAL QUERIES - Theoretical purpose
-- SimilarQL query
SELECT (answer::point_table).*, distance FROM 
    select_knn_sequential('point_table', 'feature_vector', 'euclideandist',
        (SELECT feature_vector FROM point_table WHERE id = 1),
        5, 'id', 1);

-- MIGUE-Sim sequential query
SELECT (answer::point_table).*, distance FROM 
    select_knn_sequential('point_table', 'feature_vector', 'euclideandist',
        (SELECT feature_vector FROM point_table WHERE id = 1),
        5, 'id', 2);