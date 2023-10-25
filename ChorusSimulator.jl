"""
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
Records data using normal arithmetic and variables (may need to use atomics if multi-threading)

NOTE: MAKE SURE YOU'RE RUNNING THIS WITH AT LEAST 2 THREADS!
"""

"""
KNOWN ISSUES:
- Multi-threading is temperamental (when is it ever)
- Chorus flower sim on layer 22 doesn't wanna work for some reaso
""" 

include("ChorusSimulatorFuncs.jl")


# A flag to indicate when the simulation should prematurely save its data and stop
stopSimulation = false
sufficientThreads = false # true

# Check user has sufficient threads
# if Threads.nthreads() < 2
#     println("\n⚠ Warning: Program started with less than 2 threads, safe early exit will be disabled ⚠")
#     println("\nRun ▶ `julia --threads 2` to start Julia with 2 threads")
#     global sufficientThreads = false
#     sleep(3)
# end

# Welcome the user 🥰
println("\n🍇 Welcome to Chorus Simulator!🌵")
sleep(0.25)
print("Please enter how long you want to run your next simulation for (m): ")
simTime = getinput()

# Start the simulation
simTime == 1 ? minuteWord = "minute" : minuteWord = "minutes"
println("Running a simulation for $simTime $minuteWord... hold tight!")

# Read input in case of an early exit request
if sufficientThreads
    simulationThread = Threads.@spawn start(simTime) # start the simulation in a separate thread
    sleep(0.5)
    while !stopSimulation
        println("\n🔴 To safely end the simulation at any time, type 'exit'🔴")
        earlyExitInput = readline()
        if lowercase(earlyExitInput) == "exit"
            println("Stopping simulation...")
            global stopSimulation = true
            Threads.wait(simulationThread) # wait for the simulation thread to safely finish
            break
        end
    end
else
    start(simTime)
end

# Farwell the user 👋
sleep(0.25)
println("\nThanks for using Chorus Simulator, have a nice day 👋")
