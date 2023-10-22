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

# Air Block ID
const AIR::Int = 10 

function chorusToSetblock(World::Array{Int, 3})
    for (i,k,j) in Iterators.product(axes(World, 1), axes(World, 3), axes(World, 2))
        id = World[i,j,k]
        if id ≠ AIR
            # println("Block $id found at [$i, $j, $(k)]")
            println("setblock ~$i ~$j ~$k minecraft:$(blocksDict[id])")
        end
    end
end