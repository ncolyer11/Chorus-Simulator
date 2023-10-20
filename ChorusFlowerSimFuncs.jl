using Dates

# Custom data type for recording block position
mutable struct BlockPos
    x::Int
    y::Int
    z::Int
end

# Max chorus flower age is 5 (dead)
const MAX_AGE::Int = 5 
# Block ID's
const CHORUS_FLOWER_AGE_0::Int = 0 
const CHORUS_FLOWER_AGE_1::Int = 1
const CHORUS_FLOWER_AGE_2::Int = 2
const CHORUS_FLOWER_AGE_3::Int = 3
const CHORUS_FLOWER_AGE_4::Int = 4
const CHORUS_FLOWER_AGE_5::Int = 5
const AIR::Int = 10 
const END_STONE::Int = 11 
const CHORUS_PLANT::Int = 12 
# Simulation world height
const WORLD_HEIGHT = 23

# Starts the simulation and runs it for 'simTime' minutes
function start(simMaxRunTime::Float64)
    # Initialise world state to all air
    World = fill(AIR, (11, WORLD_HEIGHT, 11))
    # Set starting conditions to be a centred endstone block with a chorus flower on top
    World[6, 1, 6] = CHORUS_FLOWER_AGE_0
    World[6, 2, 6] = END_STONE

    startTime = time()
    while true
        # Check if the elapsed time exceeds the maximum runtime
        if time() - startTime > simMaxRunTime * 60
            println("Maximum runtime reached. Exiting the simulation.")
            break
        end
        # Simulate 3 randomticks per subchunk
        for i in 1:3
            subChunkLowerPos, subChunkUpperPos = randSubChunkPos()
            if validPos(subChunkLowerPos, 15) == true
                randomTick(World, subChunkLowerPos)
            end
            if validPos(subChunkUpperPos, 31) == true
                randomTick(World, subChunkUpperPos)
            end
        end
    end      
end

# Simulates the effects of a single random tick on a chorus flower
function randomTick(World::Array{Int, 3}, pos::BlockPos)
    # If block isn't a chorus flower then exit
    if getBlockId(World, pos) > 5
        return
    end
    aboveBlock = blockUp(pos)
    age = getAge(getBlockId(World, pos))
    # If above block isn't within height limit or isn't air or age is ≥ 5 exit
    if aboveBlock.y + 1 > WORLD_HEIGHT || getBlockId(World, aboveBlock) ≠ AIR || age ≥ MAX_AGE
        return
    end
    # Check conditions to be able to grow vertically: canGrow
    # Also record any endstone 2 to 5 blocks below the chorus flower: endstn2To5Down
    canGrowAbove::Bool, endstn2To5Down::Bool = checkVerticalGrowth(World, pos)

    # If valid growth conditions and is sufficiently surrounded by air, grow vertically
    if canGrowAbove && isSurroundedByAir(aboveBlock) && getBlockId(blockUp(pos, 2)) == AIR
        tryVerticalGrowth()
    # Otherwise if age is less than 4 try grow to horizontally in 1-4 horizontal directions
    elseif age < 4
        tryHoriztonalGrowth()
    else
        dieChorus(World, pos)
    end
end

# Returns BlockPos value of above block
function blockUp(blockPos::BlockPos, amount::Int=1)
    upBlockPos = BlockPos(blockPos.x, blockPos.y + amount, blockPos.z)
    return upBlockPos
end

# Returns BlockPos value of below block
function blockDown(blockPos::BlockPos, amount::Int=1)
    downBlockPos = BlockPos(blockPos.x, blockPos.y - amount, blockPos.z)
    return downBlockPos
end

# Returns the age of the block given an Id, returns an error code of -1 if not a chorus flower
function getAge(blockId::Int)
    if 0 ≤ blockId ≤ MAX_AGE
        return blockId
    else
        # println("Invalid BlockID")
        print("Invalid BlockID ")
        return -1
    end
end

#=
Information on block id:
- 0-5: Chorus flower age 0-5
- 10:  Air
- 11:  Endstone
- 12:  Chorus plant
=#
# Retrieves the block type at 'BlockPos'
function getBlockId(World::Array{Int, 3}, pos::BlockPos)
    return World[pos.x + 1, pos.y + 1, pos.z + 1] # + 1 as Julia is 1-indexed 🤨
end

# Returns a 2 randomly chosen coords for each subchunk a chorus sits in (min 2)
function randSubChunkPos()
    return (
        BlockPos(rand(0:15), rand(0:15), rand(0:15)),
        BlockPos(rand(0:15), rand(15:31), rand(0:15))
    )
end

# Checks to see if random sub-chunk coords are within a chorus plants bounding box
function validPos(pos::BlockPos, maxHeight::Int)
    if pos.x + 1 > 11 || pos.y + 1 > min(maxHeight, WORLD_HEIGHT) || pos.z + 1 > 11
        return false
    else
        return true
    end
end

# Checks to see if the chorus can grow vertically
function checkVerticalGrowth(World::Array{Int, 3}, pos::BlockPos)
    canGrowAbove::Bool = false
    endstn2To5Down::Bool = false
    belowBlock = blockDown(pos)
    if getBlockId(World, belowBlock) == ENDSTONE
        canGrowAbove = true
    elseif getBlockId(World, belowBlock) == CHORUS_PLANT
        # Keep track of how many chorus plants are below the given chorus flower
        chorusPlantsBelow = 1
        for i in 1:4
            # Looks at 5 (first below is checked in above if else) blocks below to see if any are chorus plants
            belowBlockType = getBlockId(World, blockDown(belowBlock + chorusPlantsBelow))
            if belowBlockType == CHORUS_PLANT
                chorusPlantsBelow += 1
                continue
            end
            # If endstone is found not first block below chorus flower, but any of the 4 beneath it, set endstn2To5Down to true
            if belowBlockType == END_STONE
                endstn2To5Down = true
            end
            break
        end
        # If no chorus plants were found below then chorusPlantsBelow is still 1 and set canGrow to true
        # If there were 0-4 chorus plants beneath the flower, then there's a (5-j)/5 or (4-j)/4 chance of setting canGrow to true
        if chorusPlantsBelow < 2 || chorusPlantsBelow ≤ rand(0:(endstn2To5Down ? 5 : 4))
            canGrowAbove = true
        end
    # If there's air below chorus flower set canGrow to true
    elseif getBlockId(World, belowBlock) == AIR
        canGrowAbove = true
    end
    # Return growth conditions
    return canGrowAbove, endstn2To5Down
end