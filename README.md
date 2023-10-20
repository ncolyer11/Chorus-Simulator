# Chorus-Simulator
Written by ncolyer

A program that simulates and charts chorus flower growth
It records:
- Amount and position of chorus flowers and plants in minute intervals
- Average height, length, and width a fully grown chorus flower grows to

Will be optimised later using multi-threading to simulate batches of flowers at a time
Works by generating a small section of the world using a 3d array that just stores which
block is where
It then simulates random ticks using a random call for each x, y, and z value
Replicates chorus flower growth code from deobfuscated java game code
Records data using normal arithmetic and variables (may need to use atomics if multi- threading)
