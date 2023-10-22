using Dates
using XLSX
using Plots

# Custom data type for recording block position
mutable struct BlockPos
    x::Int
    y::Int
    z::Int
end

# Dictionary to convert block ID's to block names
blocksDict = Dict(
    0 => "chorus_flower[age=0]",
    1 => "chorus_flower[age=1]",
    2 => "chorus_flower[age=2]",
    3 => "chorus_flower[age=3]",
    4 => "chorus_flower[age=4]",
    5 => "chorus_flower[age=5]",
    10 => "air",
    11 => "end_stone",
    12 => "chorus_plant[up=true,down=true]"
)

# Max chorus flower age is 5 (dead)
const MAX_AGE::Int = 5 
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
const MAX_SIM_CYCLE_MINUTES::Int = 30


# Starts the simulation and runs it for 'simMaxRunTime' minutes
function start(simMaxRunTime::Float64)
    randomTicks::Int64 = 0
    startTime = time()
    elapsedTime = time() - startTime
    chorusPlantHeatmap = fill(Float64(0), (11, WORLD_HEIGHT, 11, MAX_SIM_CYCLE_MINUTES + 1))
    chorusFlowerHeatmap = fill(Float64(0), (11, WORLD_HEIGHT, 11, MAX_SIM_CYCLE_MINUTES + 1))
    simmedChorus = 0
    while true
        # Check if the elapsed time exceeds the maximum runtime
        elapsedTime = time() - startTime
        if elapsedTime > simMaxRunTime * 60
            break
        end
        
        # Initialise world state to all air
        World = fill(AIR, (11, WORLD_HEIGHT, 11))
        # Set starting conditions to be a centred endstone block with a chorus flower on top
        World[6, 1, 6] = END_STONE
        World[6, 2, 6] = CHORUS_FLOWER_AGE_0
        aliveFlowers = 1
        timeInterval = 0
        while aliveFlowers > 0 && timeInterval ≤ MAX_SIM_CYCLE_MINUTES
            # Simulate 3 randomticks per subchunk
            for i in 1:3
                subChunkLowerPos, subChunkUpperPos = randSubChunkPos()
                # println("Ticked Coords: $subChunkLowerPos $subChunkUpperPos")
                if validPos(subChunkLowerPos, 15)
                    randomTick(World, subChunkLowerPos)
                end
                if validPos(subChunkUpperPos, 31)
                    randomTick(World, subChunkUpperPos)
                end
            end
            randomTicks += 6
            # Every in-game/simulation minute (7200 random ticks), update the heatmap and increment one time interval
            if rem(randomTicks, 6*20*60) == 0
                aliveFlowers = updateHeatmaps(World, chorusFlowerHeatmap, chorusPlantHeatmap, timeInterval, simmedChorus)
                timeInterval += 1
            end
            # sleep(0.005)
        end
        simmedChorus += 1
    end
    
    # Display runtime
    elapsedTime == 1 ? minuteWord = "minute" : minuteWord = "minutes"
    println("Maximum runtime reached after $(elapsedTime/60) $minuteWord. Exiting the simulation.")
    sleep(0.5)

    # Output simulation some general simulation statistics
    simmedChorus == 1 ? flowerWord = "flower" : flowerWord = "flowers"
    println("Simulated $simmedChorus chorus $flowerWord over $randomTicks randomticks ($(randomTicks/(6*20*60)) hours)")

    # Save heatmap data to an excel file
    println("Saving heatmaps...")
    saveHeatmap(chorusFlowerHeatmap, "Chorus Flower Heatmap")
    saveHeatmap(chorusPlantHeatmap, "Chorus Plant Heatmap")
    println("Heatmaps saved successfully")
    
    # Export heatmap data as a set of pngs
    println("Exporting Heatmaps...")
    exportHeatmap(chorusFlowerHeatmap, "Chorus Flower Heatmap")
    exportHeatmap(chorusPlantHeatmap, "Chorus Plant Heatmap")
    println("Heatmaps exported successfully")

end

# Simulates the effects of a single random tick on a chorus flower
function randomTick(World::Array{Int, 3}, pos::BlockPos)
    # If the block isn't a chorus flower then exit
    id::Int = getBlockId(World, pos)
    # println("Current id: $id")
    if !(id in CHORUS_FLOWERS)
        return
    end
    # println("Chorus Flower of age $id found at position $pos")

    age = getAge(id)
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
    else
        dieChorus(World, pos)
    end
end

# Returns BlockPos value of above block
function blockUp(blockPos::BlockPos, amount::Int=1)
    return BlockPos(blockPos.x, blockPos.y + amount, blockPos.z)
end

# Returns BlockPos value of below block
function blockDown(blockPos::BlockPos, amount::Int=1)
    return BlockPos(blockPos.x, blockPos.y - amount, blockPos.z)
end

# Returns the age of the block given an Id, returns an error code of -1 if not a chorus flower
function getAge(blockId::Int)
    if blockId in CHORUS_FLOWERS
        # println("Valid BlockID: $blockId")
        return blockId # As the block ID of chorus flowers in this sim is also conveniantly its age
    else
        println("Invalid BlockID: $blockId")
        return -1
    end
end

# Retrieves the block type at 'BlockPos'
function getBlockId(World::Array{Int, 3}, pos::BlockPos)
    return World[pos.x + 1, pos.y + 1, pos.z + 1] # + 1 as Julia is 1-indexed 🤨
end

# Sets or places a block of 'blockId' at 'BlockPos'
function setBlockId(World::Array{Int, 3}, pos::BlockPos, blockId::Int)
    World[pos.x + 1, pos.y + 1, pos.z + 1] = blockId
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
    return !(pos.x + 1 > 11 || pos.y + 1 > min(maxHeight, WORLD_HEIGHT) || pos.z + 1 > 11)
end

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
    # Grow function to grow plants until it gets to another flower
    # println("grew chorus vertically")
    growChorus(World, blockUp(pos), age)
end

# Attempt to grow a chorus flower horizontally after being randomticked
function tryHorizontalGrowth(World::Array{Int, 3}, pos::BlockPos, endstn2To5Down::Bool)
    # Note: this can be ZERO, meaning the chorus flower can just die on the spot if there's more than 1 chorus plant below it e.g.
    directionPicks::Int = rand(0:3)
    # If there's endstone 2 to 5 blocks below the chorus flower, increment directionPicks
    if endstn2To5Down
        directionPicks += 1
    end
    grewAdjacent::Bool = false
    # Runs 'directionPicks' amount of times to try and grow at different directions horizontally adjacent to the chorus flower
    # Means it could branch off into up to min(directionPicks, 4) directions
    for l in 1:directionPicks
        # Random is the seed for the given random tick 
        # Essentially this just gives a 1/4 chance for either horizontal direction to be chosen
        direction::Int = rand(1:4)
        adjBlockPos = offsetBlock(pos, direction)
        age::Int = getAge(getBlockId(World, pos))
        # To grow, adjacent block, all sides horizontal to it (exc chorus flower side) and the block below that has to be air
        if (getBlockId(World, adjBlockPos) == AIR &&
            getBlockId(World, blockDown(adjBlockPos)) == AIR ||
            isSurroundedByAir(World, adjBlockPos, 5 - direction)) # Maps direction to its opposite using: x ↦ 5 - x
            # println("grew chorus adjacent at pos $adjBlockPos on $l")
            growChorus(World, adjBlockPos, age + 1) # Only if the chorus flower moves to the side, does it's age increase
            grewAdjacent = true
        end
    end
    if grewAdjacent
        setBlockId(World, pos, CHORUS_PLANT)
    else
        dieChorus(World, pos)
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

# Returns a blockpos of an offset block of a given direction
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

# Updates the 4D chorus plant heatmap at the given minute interval
function updateHeatmaps(World::Array{Int, 3}, chorusFlowerHeatmap::Array{Float64, 4}, chorusPlantHeatmap::Array{Float64, 4}, minute::Int, simmedChorus::Int)
    # Optimisation step to track alive flowers and skip to the next chorus if the current one is already dead
    aliveFlowers = 0
    for (i,j,k) in Iterators.product(axes(World, 1), axes(World, 2), axes(World, 3))
        blockId = World[i, j, k]
        if blockId in CHORUS_FLOWERS && blockId != MAX_AGE
            aliveFlowers += 1
        end
        if blockId in CHORUS_FLOWERS
            chorusFlowerHeatmap[i, j, k, minute + 1] = (1 + chorusFlowerHeatmap[i, j, k, minute + 1]) / (simmedChorus + 1)
        elseif blockId == CHORUS_PLANT
            chorusPlantHeatmap[i, j, k, minute + 1] = (1 + chorusPlantHeatmap[i, j, k, minute + 1]) / (simmedChorus + 1)
        end
    end
    return aliveFlowers
end

# Write heatmap data to an excel file
function saveHeatmap(heatmap::Array{Float64, 4}, name::String)
    try
        # Create a new Excel file
        XLSX.openxlsx("$(name).xlsx", mode="w") do xf
            for minute in 0:(30)
                # Create a new sheet for each time interval
                !XLSX.hassheet(xf, "$minute") && XLSX.addsheet!(xf, "$minute")
                sheet = xf[minute + 2]
                minuteSlice = view(heatmap, :, :, :, minute + 1)
                for (x,y,z) in Iterators.product(axes(minuteSlice, 1), axes(minuteSlice, 2), axes(minuteSlice, 3))
                    col = x - 1 + (11 * (z - 1))
                    row = 23 - y
                    val = heatmap[x, y, z, minute + 1]
                    # println("Wrote value: $val to row: $row, col: $col ($x, $y, $z)")
                    sheet[row + 1, col + 1] = heatmap[x, y, z, minute + 1]
                end
            end
        end
    catch error
        println("Error: $error")
    end
end

# Export heatmaps as a set of PNG files
function exportHeatmap(heatmapData::Array{Float64, 4}, name::String)
    for minute in 0:30
        # Convert the heatmap to 2D to be able to plotted
        flattenedHeatmap = heatmapTo2D(heatmapData, minute)
        try
            gr()
            png(
                heatmap(
                    1:size(flattenedHeatmap, 1),
                    1:size(flattenedHeatmap, 2),
                    flattenedHeatmap,
                    c = cgrad([:white, :orange, :purple]),
                    xlabel = "z slice",
                    ylabel = "height",
                    title = name * "minute_$minute"),
                "heatmaps\\$name (minute $minute)") 
        catch error
            println("Error: $error")
        end
    end
end

# Flattens a slice of a 4D heatmap to be 2D so it can be plotted on a 2D heatmap
function heatmapTo2D(heatmapData::Array{Float64, 4}, minute::Int)
    # Extract slice of the heatmap at a certain minute interval
    heatmapSlice = view(heatmapData, :, :, :, minute + 1)
    flattenedHeatmap = fill(Float64(0), (WORLD_HEIGHT, size(heatmapSlice, 1)^2))
    for (x,y,z) in Iterators.product(axes(heatmapSlice, 1), axes(heatmapSlice, 2), axes(heatmapSlice, 3))
        col = x - 1 + (11 * (z - 1))
        row = y - 1
        flattenedHeatmap[row + 1, col + 1] = heatmapSlice[x, y, z]
    end
    return flattenedHeatmap
end