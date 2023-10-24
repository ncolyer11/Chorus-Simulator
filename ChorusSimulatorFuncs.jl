using Dates
using Plots
using Statistics
using XLSX

# Custom data type for recording block position
mutable struct BlockPos
    x::Int
    y::Int
    z::Int
end

# Max chorus flower age is 5 (dead)
const MAX_AGE::Int = 5
# Cutting off 2 edges as they can only gen 1 flower really late
const CHORUS_RADII::Int = 4
const CHORUS_WIDTH::Int = 9
# Block ID's
const CHORUS_FLOWER_AGE_0 = 0 
const CHORUS_FLOWER_AGE_1::Int = 1
const CHORUS_FLOWER_AGE_2::Int = 2
const CHORUS_FLOWER_AGE_3::Int = 3
const CHORUS_FLOWER_AGE_4::Int = 4
const CHORUS_FLOWER_AGE_5::Int = 5
const CHORUS_FLOWERS::Array{Int, 1} = collect(0:5)
const AIR::Int = 10 
const END_STONE::Int = 11 
const CHORUS_PLANT::Int = 12 
# Simulation world height
const WORLD_HEIGHT::Int = 23
# Max runtime (chosen as ~95% of chorus are fully grown by then)
const MAX_SIM_CYCLE_MINUTES::Int = 30


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

# Starts the simulation and runs it for 'simMaxRunTime' minutes
function start(simMaxRunTime::Float64)
    randomTicks::Int64 = 0
    chorusFlowerHeatmap = fill(Float64(0), (CHORUS_WIDTH, WORLD_HEIGHT, CHORUS_WIDTH, MAX_SIM_CYCLE_MINUTES + 1))
    chorusPlantHeatmap = fill(Float64(0), (CHORUS_WIDTH, WORLD_HEIGHT, CHORUS_WIDTH, MAX_SIM_CYCLE_MINUTES + 1))
    simmedChorus = 0
    avgTimeIntervalsForGrowth = 0.0
    startTime = time_ns()
    elapsedTime = time_ns() - startTime
    lastMinute::Int64 = 0
    while true
        # Check if the elapsed time exceeds the maximum runtime
        elapsedTime = time_ns() - startTime
        currentMinute = floor(elapsedTime / 60e9)
        if elapsedTime > simMaxRunTime * 60e9 # converting m to ns
            break
        elseif currentMinute != lastMinute
            lastMinute = currentMinute
            remainingTime = simMaxRunTime - currentMinute
            remainingTime == 1 ? minuteWord = "minute" : minuteWord = "minutes"
            println(" - Simulated $simmedChorus chorus so far with $remainingTime $minuteWord remaining")
        end
        # Initialise world state to all air
        World = fill(AIR, (CHORUS_WIDTH, WORLD_HEIGHT, CHORUS_WIDTH))
        # Set starting conditions to be a centred endstone block with a chorus flower on top
        World[CHORUS_RADII + 1, 1, CHORUS_RADII + 1] = END_STONE
        World[CHORUS_RADII + 1, 2, CHORUS_RADII + 1] = CHORUS_FLOWER_AGE_0
        aliveFlowers = 1
        timeInterval = 0
        while aliveFlowers > 0 && timeInterval ≤ MAX_SIM_CYCLE_MINUTES
            # Simulate 3 randomticks per subchunk
            for i in 1:3
                subChunkLowerPos, subChunkUpperPos = randSubChunkPos()
                # If the block isn't a chorus flower then exit
                lowerId = getBlockId(World, subChunkLowerPos)
                upperId = getBlockId(World, subChunkUpperPos)
                if validPos(subChunkLowerPos, 15) && lowerId ≤ CHORUS_FLOWER_AGE_4
                    randomTick(World, subChunkLowerPos)
                end
                if validPos(subChunkUpperPos, 31) && upperId ≤ CHORUS_FLOWER_AGE_4
                    randomTick(World, subChunkUpperPos)
                end
            end
            randomTicks += 6
            # Every in-game/simulation minute (7200 random ticks), update the heatmap and increment one time interval
            if rem(randomTicks, 7200) == 0
                aliveFlowers = updateHeatmaps(World, chorusFlowerHeatmap, chorusPlantHeatmap, timeInterval, simmedChorus)
                timeInterval += 1
            end
        end
        simmedChorus += 1
        # Track average growth time
        if avgTimeIntervalsForGrowth == 0
            avgTimeIntervalsForGrowth = timeInterval
        else
            avgTimeIntervalsForGrowth = (simmedChorus * avgTimeIntervalsForGrowth + timeInterval) / (simmedChorus + 1)
        end
        # Quick-sim remaining time intervals (system has reached stability now that all chorus flowers are dead)
        for remainingTimeIntervals in (timeInterval + 1):MAX_SIM_CYCLE_MINUTES
            updateHeatmaps(World, chorusFlowerHeatmap, chorusPlantHeatmap, remainingTimeIntervals, simmedChorus)
        end
    end
    
    # Display runtime
    elapsedTime == 1 ? minuteWord = "minute" : minuteWord = "minutes"
    println("\nMaximum runtime reached after $(elapsedTime/60e9) $minuteWord. Exiting the simulation.")
    sleep(0.5)
    
    # Output some general simulation statistics
    simmedChorus == 1 ? flowerWord = "flower" : flowerWord = "flowers"
    println("Simulated $simmedChorus chorus $flowerWord over $randomTicks randomticks ($(round(randomTicks/432e3)) hours)")
    println("Average chorus flower took $avgTimeIntervalsForGrowth minutes to fully grow")

    # Save heatmap data to an excel file
    finish(chorusFlowerHeatmap, chorusPlantHeatmap)
end

### SIMULATION WORLD RELATED FUNCTIONS ###
# Simulates the effects of a single random tick on a chorus flower
function randomTick(World::Array{Int, 3}, pos::BlockPos)
    age = getAge(getBlockId(World, pos))
    aboveBlock = blockUp(pos)
    # If the above block isn't within height limit or isn't air or age is ≥ 5 exit
    if aboveBlock.y + 1 > WORLD_HEIGHT || getBlockId(World, aboveBlock) ≠ AIR || age ≥ MAX_AGE
        return
    end
    # Check conditions to be able to grow vertically: canGrow
    # Also record any endstone 2 to 5 blocks below the chorus flower: endstn2To5Down
    canGrowAbove::Bool, endstn2To5Down::Bool = checkVerticalGrowth(World, pos)
    # If valid growth conditions and is sufficiently surrounded by air, grow vertically
    if canGrowAbove && isSurroundedByAir(World, aboveBlock, 0) && getBlockId(World, blockUp(pos, 2)) == AIR
        tryVerticalGrowth(World, pos)
    # Otherwise if age is less than 4 try grow to horizontally in 1-4 horizontal directions
    elseif age < 4
        tryHorizontalGrowth(World, pos, endstn2To5Down)
    # Otherwise wither away 😦
    else
        dieChorus(World, pos)
    end
end

# Returns 2 randomly chosen coords for each subchunk a chorus sits in (min 2)
function randSubChunkPos()
    return (
        BlockPos(rand(0:15), rand(0:15), rand(0:15)),
        BlockPos(rand(0:15), rand(15:31), rand(0:15))
    )
end

# Checks to see if random sub-chunk coords are within a chorus plant's bounding box
function validPos(pos::BlockPos, maxHeight::Int)
    # If pos has a taxi distance within 4 of the centre and height is low enough return true
    return abs(pos.x - CHORUS_RADII) + abs(pos.z - CHORUS_RADII) ≤ CHORUS_RADII && pos.y + 1 ≤ min(maxHeight, WORLD_HEIGHT)
    #= Old algorithm that checked within the entire rectangular bounding box,
    Rather than the taxicab cylinder of radii 4:
    return !(pos.x + 1 > CHORUS_WIDTH || pos.y + 1 > min(maxHeight, WORLD_HEIGHT) || pos.z + 1 > CHORUS_WIDTH) =#
end

### DATA LOGGING RELATED FUNCTIONS ###
# Updates the 4D chorus plant and flower heatmaps at the given minute interval
function updateHeatmaps(World::Array{Int, 3}, chorusFlowerHeatmap::Array{Float64, 4}, chorusPlantHeatmap::Array{Float64, 4}, minute::Int, simmedChorus::Int)
    # Optimisation step to track alive flowers and skip to the next chorus if the current one is already dead
    aliveFlowers = 0
    for (i,j,k) in Iterators.product(axes(World, 1), axes(World, 2), axes(World, 3))
        blockId = World[i, j, k]
        if blockId in CHORUS_FLOWERS && blockId != MAX_AGE
            aliveFlowers += 1
        end
        # Calculate cumulative average
        isFlower = 0
        if blockId in CHORUS_FLOWERS
            isFlower = 1
        end
        prevFlowerAvg = chorusFlowerHeatmap[i, j, k, minute + 1]
        chorusFlowerHeatmap[i, j, k, minute + 1] = (simmedChorus * prevFlowerAvg + isFlower) / (simmedChorus + 1)
        
        isFruit = 0
        if blockId == CHORUS_PLANT
            isFruit = 1
        end
        prevPlantAvg = chorusPlantHeatmap[i, j, k, minute + 1]
        chorusPlantHeatmap[i, j, k, minute + 1] = (simmedChorus * prevPlantAvg + isFruit) / (simmedChorus + 1)
    end
    return aliveFlowers
end

# Write heatmap data to an excel file
function saveHeatmap(heatmap::Array{Float64, 4}, name::String)
    try
        # Create a new Excel file
        XLSX.openxlsx("$(name).xlsx", mode="w") do xf
            for minute in 0:(MAX_SIM_CYCLE_MINUTES)
                # Create a new sheet for each time interval
                !XLSX.hassheet(xf, "$(minute + 1)") && XLSX.addsheet!(xf, "$(minute + 1)")
                sheet = xf[minute + 2]
                minuteSlice = view(heatmap, :, :, :, minute + 1)
                for (x,y,z) in Iterators.product(axes(minuteSlice, 1), axes(minuteSlice, 2), axes(minuteSlice, 3))
                    col = x + (CHORUS_WIDTH * (z - 1))
                    row = WORLD_HEIGHT + 1 - y
                    sheet[row, col] = heatmap[x, y, z, minute + 1]
                end
            end
        end
    catch error
        println("Error: $error")
        return false
    end
    return true
end

# Export heatmaps as a set of PNG files
# Currently 'heatmap()' is bugged on Julia so Python and
# MatPlotLib are currently being used in a separate file for the heatmaps
function exportHeatmap(heatmapData::Array{Float64, 4}, name::String)
    for minute in 0:MAX_SIM_CYCLE_MINUTES
        # Convert the heatmap to 2D to be able to be plotted
        flattenedHeatmap = heatmapTo2D(heatmapData, minute)
        try
            gr(dpi=420, size=(2560 / 5, 1440 / 5))
            png(
                heatmap(
                    1:size(flattenedHeatmap, 1),
                    1:size(flattenedHeatmap, 2),
                    flattenedHeatmap,
                    aspect_ratio=:equal,
                    clims=(0, 1),
                    xlims=(0, CHORUS_WIDTH^2 - 1),
                    ylims=(0, WORLD_HEIGHT - 1),
                    c = cgrad([:white, :orange, :purple], [0, 0.001, 0.1]),
                    xlabel = "z slices (9 x wide)",
                    ylabel = "y layer",
                    title = "$(name): minute $minute"),
                "media\\heatmaps\\$name (minute $minute)") 
        catch error
            println("Error: $error")
            return false
        end
    end
    return true
end

# Flattens a slice of a 4D heatmap to be 2D so it can be plotted on a 2D heatmap
function heatmapTo2D(heatmapData::Array{Float64, 4}, minute::Int)
    # Extract slice of the heatmap at a certain minute interval
    heatmapSlice = view(heatmapData, :, :, :, minute + 1)
    flattenedHeatmap = fill(Float64(0), (size(heatmapSlice, 1)^2, WORLD_HEIGHT))
    for (x,y,z) in Iterators.product(axes(heatmapSlice, 1), axes(heatmapSlice, 2), axes(heatmapSlice, 3))
        col = x + (CHORUS_WIDTH * (z - 1))
        row = y
        flattenedHeatmap[col, row] = heatmapSlice[x, y, z]
    end
    return flattenedHeatmap
end

# Take advantage of the 45 deg symmetry property
# of a chorus by averaging across its 8 quadrants
# Speeds up simulation time by effectively 6.33...x
function optimiseOctants(heatmap::Array{Float64, 4})
    for minute in 1:(MAX_SIM_CYCLE_MINUTES + 1)
        height::Int = size(heatmap, 2)
        width::Int = size(heatmap, 1)
        radii::Int = (width + 1) / 2
        for (x,y,z) in Iterators.product(1:radii, 1:radii, 1:height)
            gridX = x - radii
            gridY = y - radii
            # Skip centred block as no values to average with
            if gridX == 0 && gridY == 0
                continue
            # Otherwise average across octants
            else
                octants = [(x, y) for x in [gridX, -gridX] for y in [gridY, -gridY]]
                values = [heatmap[x + radii, z, y + radii, minute] for (x, y) in octants]
                avgValue = mean(values)
                for (x, y) in octants
                    coords = [(-x, y), (x, -y), (-x, -y), (y, x), (-y, x), (y, -x), (-y, -x)]
                    for (dx, dy) in coords
                        heatmap[dx + radii, z, dy + radii, minute] = avgValue
                    end
                end
            end # there's a birds nest in here somewhere
        end 
    end # i can feel it
end

# Finish the simulation by saving and exporting the data
function finish(chorusFlowerHeatmap::Array{Float64, 4}, chorusPlantHeatmap::Array{Float64, 4})
    println("Optimising heatmaps...")
    optimiseOctants(chorusFlowerHeatmap)
    optimiseOctants(chorusPlantHeatmap)
    println("Heatmaps optimised")

    println("Saving heatmaps...")
    check1 = saveHeatmap(chorusFlowerHeatmap, "Chorus Flower Heatmap")
    check2 = saveHeatmap(chorusPlantHeatmap, "Chorus Plant Heatmap")
    if check1 && check2 
        println("Heatmaps saved successfully")
    else
        println("Error saving heatmaps")
    end
    
    # Export heatmap data as a set of pngs
    # Currently 'heatmap()' is bugged on Julia so Python and
    # MatPlotLib are being utilised in a separate file instead
    #=println("Exporting heatmaps (Julia Plots)...")
    check1 = exportHeatmap(chorusFlowerHeatmap, "Chorus Flower Heatmap")
    check2 = exportHeatmap(chorusPlantHeatmap, "Chorus Plant Heatmap")
    if check1 && check2 
        println("Heatmaps internally exported successfully")
    else
        println("Error internally exporting heatmaps")
    end=#
    # Run Python-MatPlotLib alternate version of exporting the heatmaps
    println("Exporting heatmaps (Python MatPlotLib)...")
    try
        run(`Python ExcelTo2DHeatmaps.py`, wait=true)
        println("Heatmaps externally exported successfully")
    catch error
        println("Error externally exporting heatmaps: $error")
    end
end

### CHORUS GROWTH RELATED FUNCTIONS ###
# Checks to see if the chorus can grow vertically
function checkVerticalGrowth(World::Array{Int, 3}, pos::BlockPos)
    canGrowAbove::Bool = false
    endstn2To5Down::Bool = false
    belowBlockPos = blockDown(pos)
    if getBlockId(World, belowBlockPos) == END_STONE
        canGrowAbove = true
    elseif getBlockId(World, belowBlockPos) == CHORUS_PLANT
        # Keep track of how many chorus plants are below the given chorus flower
        chorusPlantsBelow = 1
        for i in 1:4
            # Looks at 5 (first below is checked in above if else) blocks below to see if any are chorus plants
            belowBlockId = getBlockId(World, blockDown(belowBlockPos, chorusPlantsBelow))
            if belowBlockId == CHORUS_PLANT
                chorusPlantsBelow += 1
                continue
            end
            # If endstone is found not on the first block below the chorus flower,
            # but on any of the 4 blocks beneath it, set endstn2To5Down to true
            if belowBlockId == END_STONE
                endstn2To5Down = true
            end
            break
        end
        # If no chorus plants were found below then chorusPlantsBelow is still 1 and set canGrow to true
        # If there were 0-4 chorus plants beneath the flower, then there's a (5-j)/5 or (4-j)/4 chance of setting canGrow to true
        if chorusPlantsBelow < 2 || chorusPlantsBelow ≤ rand(0:(endstn2To5Down ? 4 : 3)) # bounds are inclusive, unlike java random.nextInt
            canGrowAbove = true
        end
    # If there's air below the chorus flower set canGrow to true
    elseif getBlockId(World, belowBlockPos) == AIR
        canGrowAbove = true
    end
    # Return growth conditions
    return canGrowAbove, endstn2To5Down
end

# Attempt to grow a chorus flower vertically after being randomticked
function tryVerticalGrowth(World::Array{Int, 3}, pos::BlockPos)
    # Save age of current chorus flower
    age::Int = getAge(getBlockId(World, pos))
    # Replace chorus flower with a plant
    setBlockId(World, pos, CHORUS_PLANT)
    # Grow chorus flower above
    growChorus(World, blockUp(pos), age)
end

# Attempt to grow a chorus flower horizontally after being randomticked
function tryHorizontalGrowth(World::Array{Int, 3}, pos::BlockPos, endstn2To5Down::Bool)
    # Note: this can be ZERO, meaning the chorus flower can just die on the spot if there's > 1 chorus plant below it
    directionPicks::Int = rand(0:3)
    # If there's endstone 2 to 5 blocks below the chorus flower, increment directionPicks
    if endstn2To5Down
        directionPicks += 1
    end
    grewAdjacent::Bool = false
    # Runs 'directionPicks' amount of times to try and grow at different directions horizontally adjacent to the chorus flower
    # Means it could branch off into up to min(directionPicks, 4) directions
    for l in 1:directionPicks
        # Pick either of the 4 horizontal directions
        direction::Int = rand(1:4)
        adjBlockPos = offsetBlock(pos, direction)
        age::Int = getAge(getBlockId(World, pos))
        # To grow to the adjacent block, all sides horizontal to it (exc chorus flower side) and the block below that has to be air
        if (getBlockId(World, adjBlockPos) == AIR &&
            getBlockId(World, blockDown(adjBlockPos)) == AIR &&
            isSurroundedByAir(World, adjBlockPos, 5 - direction)) # Maps direction to its opposite using: x ↦ 5 - x
            growChorus(World, adjBlockPos, age + 1) # Only if the chorus flower grows to the side, does it's age increase
            grewAdjacent = true
        end
    end
    if grewAdjacent
        setBlockId(World, pos, CHORUS_PLANT)
    # Chorus flower can die if it is unable to grow vertically
    # And fails it's first horizontal growth attempt cycle
    else
        dieChorus(World, pos)
    end
end

# Retrieves the block type at 'BlockPos'
function getBlockId(World::Array{Int, 3}, pos::BlockPos)
    # If block is out of the world then treat it as air
    if (pos.y + 1 > WORLD_HEIGHT || pos.x + 1 > CHORUS_WIDTH || 
        pos.z + 1 > CHORUS_WIDTH || pos.x + 1 == 0 || pos.z + 1 == 0)
        return AIR
    else
        return World[pos.x + 1, pos.y + 1, pos.z + 1] # + 1 as Julia is 1-indexed 🤨
    end
end

# Sets or places a block of 'blockId' at 'BlockPos'
function setBlockId(World::Array{Int, 3}, pos::BlockPos, blockId::Int)
    World[pos.x + 1, pos.y + 1, pos.z + 1] = blockId
end

# Returns BlockPos value of above block
function blockUp(blockPos::BlockPos, amount::Int=1)
    return BlockPos(blockPos.x, blockPos.y + amount, blockPos.z)
end

# Returns BlockPos value of below block
function blockDown(blockPos::BlockPos, amount::Int=1)
    return BlockPos(blockPos.x, blockPos.y - amount, blockPos.z)
end

# Returns a blockpos of an offset block of a given direction, returns an error code of -1 if direction is invalid
function offsetBlock(pos::BlockPos, direction::Int)
    if direction == 1
        return BlockPos(pos.x + 1, pos.y, pos.z)
    elseif direction == 2
        return BlockPos(pos.x, pos.y, pos.z + 1)
    elseif direction == 3
        return BlockPos(pos.x, pos.y, pos.z - 1)
    elseif direction == 4
        return BlockPos(pos.x - 1, pos.y, pos.z)
    else
        println("Error: Invalid Direction")
        return -1
    end
end

# Returns the age of the block given an Id, returns an error code of -1 if not a chorus flower
function getAge(blockId::Int)
    if blockId in CHORUS_FLOWERS
        return blockId # As the block ID of chorus flowers in this sim is also conveniantly its age
    else
        println("Invalid BlockID: $blockId")
        return -1
    end
end

# Grows a chorus flower at 'blockPos' to age 'age'
function growChorus(World::Array{Int, 3}, pos::BlockPos, age::Int)
    setBlockId(World, pos, CHORUS_FLOWERS[age + 1])
end

# Grows a chorus flower at 'blockPos' to age 5 (dead)
function dieChorus(World::Array{Int, 3}, pos::BlockPos)
    setBlockId(World, pos, CHORUS_FLOWER_AGE_5)
end

# Direction 0 means there's no exception direction
# Checks surrounding horizontal blocks are all air
function isSurroundedByAir(World::Array{Int, 3}, pos::BlockPos, exceptDirection::Int)::Bool
    for direction in 1:4
        if direction == exceptDirection || getBlockId(World, offsetBlock(pos, direction)) == AIR
            continue
        end
        return false
    end
    return true
end
