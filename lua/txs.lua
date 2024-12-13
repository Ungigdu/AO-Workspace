module = {}

local maxTxsCount = 5000

-- txid -> index
local txOrder = {} 
local txRecord = {}

local function getTx(txid)
    return txRecord[txid]
end
module.getTx = getTx

local function insertTx(txid, tx)
    -- if getTx(txid) then
    --     return false
    -- end

    if #txOrder >= maxTxsCount then
        local txid = table.remove(txOrder, 1)
        txRecord[txid] = nil
    end
    table.insert(txOrder, txid)
    txRecord[txid] = tx
    return true
end
module.insertTx = insertTx

local function getTxs()
    local txs = {}
    for i, txid in ipairs(txOrder) do
        print(i, txid)
        table.insert(txs, txRecord[txid])
    end
    return txs
end
module.getTxs = getTxs

return module