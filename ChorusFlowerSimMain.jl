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

include("ChorusFlowerSimFuncs.jl")

# Get user input to determine simulation runtime
function getinput()
    simTime = 0
    while true
        try
            simTime = parse(Float64, readline())
            break
        catch
            println("Invalid input, please enter a number")
        end
    end
    return simTime
end


# Welcome the user 🥰
println("Welcome to Chorus Simulator")
sleep(0.25)
print("Please enter how long you want to run your next simulation for (m): ")
simTime = getinput()

# Start the simulation
simTime == 1 ? minuteWord = "minute" : minuteWord = "minutes"
println("Running a simulation for $simTime $minuteWord... hold tight!")
start(simTime)
sleep(0.25)

# Farwell the user 👋
println("Thanks for using Chorus Simulator, have a nice day 👋")
