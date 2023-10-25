#=
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
=#

include("ChorusSimulatorFuncs.jl")


# A flag to indicate when the simulation should prematurely save its data and stop
stopSimulation = false

# Welcome the user 🥰
println("\n🍇 Welcome to Chorus Simulator!🌵")
sleep(0.25)
print("Please enter how long you want to run your next simulation for (m): ")
simTime = getinput()

# Start the simulation
simTime == 1 ? minuteWord = "minute" : minuteWord = "minutes"
println("Running a simulation for $simTime $minuteWord... hold tight!")
simulationThread = Threads.@spawn start(simTime) # start the simulation in a separate thread

# Read input in case of an early exit request
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

# Farwell the user 👋
sleep(0.25)
println("\nThanks for using Chorus Simulator, have a nice day 👋")
