# MIGUE-Sim
MIGUE-Sim is a system to quickly execute exat Range and kNN similarity queries in Postgres. The queries are expressed following a straightforward, SQL-compatible representation seamlessly integrated into the language, whereas the system executes each query using just the native resources of Postgres.

MIGUE-Sim uses the Postgre's [Cube](https://www.postgresql.org/docs/current/cube.html) native extension to perform kNN faster, using the GIST R-Tree index available.

## Extra experiments

We performed experiments in addition to those shown in the article. We used the "Infinity" distance and the "Manhattan" distance, and compared the execution time of our system and our main competitor - [SimilarQL](https://dl.acm.org/doi/10.1145/3297280.3299736).

The results are shown in the following table:

![Extra results](https://github.com/igoralberte/miguesim/assets/3456521/d9f48d38-f91d-4d22-8fd1-d8e2e588e076)

## How to use MIGUE-Sim
  1. Install Postgres and create a database
  2. Execute 
