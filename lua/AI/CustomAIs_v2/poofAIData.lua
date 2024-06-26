AI = {
    Name = 'AI: PoofAI',
    Version = '1',
    AIList = {
        {
            key = 'poofai',
            name = '<LOC M28_0001>AI: Poof',
            rating = 100,
            ratingCheatMultiplier = 0.0,
            ratingBuildMultiplier = 0.0,
            ratingOmniBonus = 0,
            ratingMapMultiplier = {
                [256] = 1,   -- 5x5
                [512] = 0.9,   -- 10x10
                [1024] = 0.7,  -- 20x20
                [2048] = 0.25, -- 40x40
                [4096] = 0.2,  -- 80x80
            }
        },
    },
    CheatAIList = {
        {
            key = 'poofaicheat',
            name = '<LOC M28_0003>AIx: Poof',
            rating = 100,
            ratingCheatMultiplier = 300.0, --This is multiplied to the value, so 1.0 will give this amount
            ratingBuildMultiplier = 300.0,
            ratingNegativeThreshold = 200,
            ratingOmniBonus = 100,
            ratingMapMultiplier = {
                [256] = 1,   -- 5x5
                [512] = 0.9,   -- 10x10
                [1024] = 0.7,  -- 20x20
                [2048] = 0.25, -- 40x40
                [4096] = 0.2,  -- 80x80
            }
        },
    },
}