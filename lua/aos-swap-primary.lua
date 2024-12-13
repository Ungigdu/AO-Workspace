local ao = require('.ao')
local json = require('json')

local bint = require('.bint')(1024)
local txs = require('.txs')

Variant = '0.4.0'

BalancesX = BalancesX or {}
BalancesY = BalancesY or {}
Px = Px or '1050709000000000000000'
Py = Py or '250000000000000'

Pool = Pool or {
    X = 'O0DQgVialkpP9-jGU-zgkLVDBlY_syL0bono_o9i-VM', -- meme token
    Y = 'VdHpfGgyscsxPVcqEb821mLi2JFplZtyYUSToNJzuWo', -- wAR or fwAR
    SymbolX = 'ACID',
    SymbolY = 'wAR',
    FullNameX = 'Acid Coin',
    FullNameY = 'wrapped AR',
    DecimalX = '12',
    DecimalY = '12',
    Fee = '0'
}

-- boundary check and swap log
XOut = XOut or '0' -- meme swapped out
YIn = YIn or '0' -- fwAR swapped in

MaxBuyPerTx = '5000000000000' --'5000000000000' -- 5 wAR
Goal = Goal or '888000000000000' -- 888 wAR
Finished = Finished or false -- if is true, refund all incoming swaps

-- lp token info
Name = Pool.SymbolX .. '-' .. Pool.SymbolY .. '-' .. Pool.Fee
Ticker = Name
Denomination = Pool.DecimalX

Balances = Balances or {}
TotalSupply = '262677250000000000000000000000000000' -- fixed K

-- liquidity mining
Mining = Mining or {}

-- Notes
Settle = Settle or 'rKpOUxssKxgfXQOpaCq22npHno6oRw66L3kZeoo_Ndk'
TimeoutPeriod = TimeoutPeriod or 90000
SettleVersion = SettleVersion or '0.30'
Executing = Executing or false
Notes = Notes or {}
MakeTxToNoteID = MakeTxToNoteID or {}

-- pubsub
Publisher = Publisher or '1Wt_tuwyFrtK9uVvjENLOIbHnmJs4DiYFzRxi01IyXo'

local utils = {
    add = function (a,b) 
      return tostring(bint(a) + bint(b))
    end,
    subtract = function (a,b)
      return tostring(bint(a) - bint(b))
    end,
    toBalanceValue = function (a)
      return tostring(bint(a))
    end,
    toNumber = function (a)
      return tonumber(a)
    end
}

local function getInputPrice(amountIn, reserveIn, reserveOut, Fee)
    local amountInWithFee = bint.__mul(amountIn, bint.__sub(10000, Fee))
    local numerator = bint.__mul(amountInWithFee, reserveOut)
    local denominator = bint.__add(bint.__mul(10000, reserveIn), amountInWithFee)
    return bint.udiv(numerator, denominator)
end

Handlers.add('info', 'Info', 
    function(msg)
        info = {
            X = Pool.X,
            SymbolX = Pool.SymbolX,
            DecimalX = Pool.DecimalX,
            FullNameX = Pool.FullNameX,
            
            Y = Pool.Y,
            SymbolY = Pool.SymbolY,
            DecimalY = Pool.DecimalY,
            FullNameY = Pool.FullNameY,

            Fee = Pool.Fee,
            Name = Name,
            Ticker = Ticker,
            Denomination = tostring(Denomination),
            TotalSupply = TotalSupply,
            Executing = tostring(Executing),
            Settle = Settle
        }
        if not Executing then
            info.PX = Px
            info.PY = Py    
        end
        msg.reply(info)
    end
)

Handlers.add('getAmountOut',
    function(msg) return ((msg.Action == 'GetAmountOut') or (msg.Action == 'FFP.GetAmountOut')) end, 
    function(msg)
        if msg.TokenIn ~= Pool.X and msg.TokenIn ~= Pool.Y then
            msg.reply({Error = 'err_invalid_token_in'})
            return
        end

        local amountIn = bint(msg.AmountIn)
        local tokenOut = Pool.Y
        local amountOut = getInputPrice(amountIn, bint(Px), bint(Py), bint(Pool.Fee))
        if msg.TokenIn == Pool.Y then
            tokenOut = Pool.X
            amountOut = getInputPrice(amountIn, bint(Py), bint(Px), bint(Pool.Fee))
        end
    
        msg.reply({ TokenIn = msg.TokenIn, AmountIn = msg.AmountIn, 
            TokenOut = tokenOut, AmountOut = tostring(amountOut)
        })
    end
)

Handlers.add('balance', 'Balance', 
    function(msg)
        local user = msg.From
        if msg.Tags.Recipient then
            user = msg.Tags.Recipient
        end
        if msg.Tags.Target then
            user = msg.Tags.Target
        end
        if msg.Account then
            user = msg.Account
        end

        local bx = '0'
        local by = '0'
        local bal = '0'
        if BalancesX[user] then bx = BalancesX[user] end
        if BalancesY[user] then by = BalancesY[user] end
        if Balances[user] then bal = Balances[user] end
         
        msg.reply({
            BalanceX = bx,
            BalanceY = by,
            Ticker = Ticker,
            Balance = bal,
            Account = user,
            TotalSupply = TotalSupply,
            Data = bal
        })
    end
)

Handlers.add('balances', 'Balances',
    function(msg) 
        msg.reply({ Data = json.encode(Balances) })
    end
)

Handlers.add('deposit', 
    function(msg) 
        return (msg.Action == 'Credit-Notice') and (msg['X-PS-For'] ~= 'Swap') and (msg['X-FFP-For'] ~= 'Settled') and (msg['X-FFP-For'] ~= 'Refund')
    end, 
    function(msg)
        assert(type(msg.Sender) == 'string', 'Sender is required')
        assert(type(msg.Quantity) == 'string', 'Quantity is required')
        assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')

        local qty = bint(msg.Quantity)    
        if msg.From == Pool.X then
            if not BalancesX[msg.Sender] then BalancesX[msg.Sender] = '0' end
            BalancesX[msg.Sender] = tostring(bint.__add(bint(BalancesX[msg.Sender]), qty))
            Send({
                Target = msg.Sender,
                Data = 'Deposited ' .. msg.Quantity ..  ' X token'
            })
        elseif msg.From == Pool.Y then
            if not BalancesY[msg.Sender] then BalancesY[msg.Sender] = '0' end
            BalancesY[msg.Sender] = tostring(bint.__add(bint(BalancesY[msg.Sender]), qty))
            Send({
                Target = msg.Sender,
                Data = 'Deposited ' .. msg.Quantity ..  ' Y token'
            })
        else
            Send({ 
                Target = msg.From, 
                Action = 'Transfer', 
                Recipient = msg.Sender, 
                Quantity = msg.Quantity, 
                ['X-PS-Status'] = 'Refund', 
                ['X-PS-Error'] = 'err_invalid_deposit_token'
            })
        end
    end
)

Handlers.add('withdraw', 'Withdraw', 
    function(msg)
        if (not BalancesX[msg.From] or bint.__eq(bint(0), bint(BalancesX[msg.From]))) 
            and (not BalancesY[msg.From] or bint.__eq(bint(0), bint(BalancesY[msg.From]))) then
            msg.reply({Error = 'err_insufficient_balance'})
            return
        end

        if BalancesX[msg.From] and bint.__lt(0, bint(BalancesX[msg.From])) then
            local qty = BalancesX[msg.From]
            BalancesX[msg.From] = nil
            Send({
                Target = Pool.X, 
                Action = 'Transfer', 
                Recipient = msg.From, 
                Quantity = qty, 
                ['X-PS-WithdrawID'] = msg.Id,
            })
        end

        if BalancesY[msg.From] and bint.__lt(0, bint(BalancesY[msg.From])) then
            local qty = BalancesY[msg.From]
            BalancesY[msg.From] = nil
            Send({ 
                Target = Pool.Y, 
                Action = 'Transfer', 
                Recipient = msg.From, 
                Quantity = qty, 
                ['X-PS-WithdrawID'] = msg.Id,
            })
        end
    end
)

local function validateAmount(amount)
    local ok, qty = pcall(bint, amount)
    if not ok then
        return false, 'err_invalid_amount'
    end
    if not bint.__lt(0, qty) then
        return false, 'err_negative_amount'
    end
    return true, nil
end

local function validateSwapMsg(msg) 
    if not bint.__lt(0, bint(TotalSupply)) then
        return false, 'err_pool_no_liquidity'
    end

    if msg.From ~= Pool.X and msg.From ~= Pool.Y then
        return false, 'err_invalid_token_in'
    end

    if not msg['X-PS-MinAmountOut'] then
        return false, 'err_no_min_amount_out'
    end
    local ok, _ = validateAmount(msg['X-PS-MinAmountOut'])
    if not ok then
        return false, 'err_invalid_min_amount_out'
    end
    return true, nil
end

Handlers.add('swap', function(msg) return (msg.Action == 'Credit-Notice') and (msg['X-PS-For'] == 'Swap') end, 
    function(msg)
        assert(type(msg.Sender) == 'string', 'Sender is required')
        assert(type(msg.Quantity) == 'string', 'Quantity is required')
        assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')
        
        local toRefund = false
        local err = ''
        if Executing then
            toRefund = true
            err = 'err_executing'
        else
            ok, err = validateSwapMsg(msg)
            if not ok then
                toRefund = true
            end
        end

        if Finished then
            toRefund = true
            err = 'err_finished'
        end

        if toRefund then
            Send({ 
                Target = msg.From, 
                Action = 'Transfer', 
                Recipient = msg.Sender, 
                Quantity = msg.Quantity, 
                ['X-PS-OrderId'] = msg['Pushed-For'], 
                ['X-PS-TxIn'] = msg.Id, 
                ['X-PS-TokenIn'] = msg.From, 
                ['X-PS-AmountIn'] = msg.Quantity, 
                ['X-PS-Status'] = 'Refund', 
                ['X-PS-Error'] = err
            })
            return
        end

        local user = msg.Sender
        local amountIn = bint(msg.Quantity)
        local tokenIn = msg.From
        local minAmountOut = bint(msg['X-PS-MinAmountOut'])
        if tokenIn == Pool.X then
            local reserveIn = bint(Px)
            local reserveOut = bint(Py)
            local amountOut = getInputPrice(amountIn, reserveIn, reserveOut, bint(Pool.Fee))

            -- record swap, there is no need to worry XOut will be negative because all it can be sold is less equal than issued
            XOut = tostring(bint.__sub(bint(XOut), amountIn))
            YIn = tostring(bint.__sub(bint(YIn), amountOut))
            
            if bint.__lt(minAmountOut, amountOut) or bint.__eq(minAmountOut, amountOut) then
                Px = tostring(bint.__add(amountIn, reserveIn))
                Py = tostring(bint.__sub(reserveOut, amountOut))
                Send({ 
                    Target = Pool.Y, 
                    Action = 'Transfer', 
                    Recipient = user, 
                    Quantity = tostring(amountOut), 
                    ['X-PS-OrderId'] = msg['Pushed-For'], 
                    ['X-PS-TxIn'] = msg.Id, 
                    ['X-PS-TokenIn'] = msg.From, 
                    ['X-PS-AmountIn'] = msg.Quantity, 
                    ['X-PS-Status'] = 'Swapped'})
                return
            else
                -- Refund
                Send({ 
                    Target = msg.From, 
                    Action = 'Transfer', 
                    Recipient = user, 
                    Quantity = msg.Quantity, 
                    ['X-PS-OrderId'] = msg['Pushed-For'], 
                    ['X-PS-TxIn'] = msg.Id, 
                    ['X-PS-TokenIn'] = msg.From, 
                    ['X-PS-AmountIn'] = msg.Quantity, 
                    ['X-PS-Status'] = 'Refund',
                    ['X-PS-Error'] = 'err_amount_out_too_small'
                })
                return
            end
        end

        if tokenIn == Pool.Y then

            -- add buy limit check
            if bint.__lt(bint(MaxBuyPerTx), amountIn) then
                Send({ 
                    Target = msg.From, 
                    Action = 'Transfer', 
                    Recipient = user, 
                    Quantity = msg.Quantity, 
                    ['X-PS-OrderId'] = msg['Pushed-For'], 
                    ['X-PS-TxIn'] = msg.Id, 
                    ['X-PS-TokenIn'] = msg.From, 
                    ['X-PS-AmountIn'] = msg.Quantity, 
                    ['X-PS-Status'] = 'Refund',
                    ['X-PS-Error'] = 'err_buy_limit_reached'
                })
                return
            end

            local reserveIn = bint(Py)
            local reserveOut = bint(Px)
            local amountOut = getInputPrice(amountIn, reserveIn, reserveOut, bint(Pool.Fee))

            -- deal with boundary
            local checkYIn = tostring(bint.__add(bint(YIn), amountIn))
            if bint.__lt(bint(Goal), bint(checkYIn)) then
                -- refund the part over goal
                Send({ 
                    Target = msg.From, 
                    Action = 'Transfer', 
                    Recipient = user, 
                    Quantity = tostring(bint.__sub(bint(checkYIn), bint(Goal))), 
                    ['X-PS-Status'] = 'Refund',
                    ['X-PS-Error'] = 'refund_over_goal'
                })
                -- reset amountIn & amountOut
                amountIn = bint.__sub(bint(Goal), bint(YIn))
                amountOut = getInputPrice(amountIn, reserveIn, reserveOut, bint(Pool.Fee))
                Finished = true
            end

            -- record swap
            XOut = tostring(bint.__add(bint(XOut), amountOut))
            YIn = tostring(bint.__add(bint(YIn), amountIn))

            if bint.__lt(minAmountOut, amountOut) or bint.__eq(minAmountOut, amountOut) then
                Px = tostring(bint.__sub(reserveOut, amountOut))
                Py = tostring(bint.__add(amountIn, reserveIn))
                Send({ 
                    Target = Pool.X, 
                    Action = 'Transfer', 
                    Recipient = user, 
                    Quantity = tostring(amountOut), 
                    ['X-PS-OrderId'] = msg['Pushed-For'], 
                    ['X-PS-TxIn'] = msg.Id, 
                    ['X-PS-TokenIn'] = msg.From, 
                    ['X-PS-AmountIn'] = msg.Quantity, 
                    ['X-PS-Status'] = 'Swapped'
                })
                return
            else
                -- Refund
                Send({ 
                    Target = msg.From, 
                    Action = 'Transfer', 
                    Recipient = user, 
                    Quantity = msg.Quantity, 
                    ['X-PS-OrderId'] = msg['Pushed-For'], 
                    ['X-PS-TxIn'] = msg.Id, 
                    ['X-PS-TokenIn'] = msg.From, 
                    ['X-PS-AmountIn'] = msg.Quantity, 
                    ['X-PS-Status'] = 'Refund', 
                    ['X-PS-Error'] = 'err_amount_out_too_small'
                })
                return
            end
        end
    end
)

Handlers.add('gotDebitNotice', 'Debit-Notice', 
    function(msg)
        if not msg['X-PS-OrderId'] then
            return
        end

        local user = msg.Recipient
        local tokenOut = msg.From
        local tokenIn = msg['X-PS-TokenIn']
        local amountIn = msg['X-PS-AmountIn']
        local amountOut = msg.Quantity
        local err = msg['X-PS-Error'] or ''

        local order = {
            User = user,
            OrderId = msg['X-PS-OrderId'],
            Pool = Name,
            PoolId = ao.id,
            TxIn = msg['X-PS-TxIn'],
            TxOut = msg.Id,
            TokenOut = tokenOut,
            TokenIn = tokenIn,
            AmountIn = amountIn,
            AmountOut = amountOut,
            OrderStatus = msg['X-PS-Status'],
            Error = err,
            TimeStamp = tostring(msg.Timestamp)
        }
        
        -- duplicate order will overwrite the previous one
        txs.insertTx(msg['X-PS-OrderId'], order) 

        Send({ 
            Target = ao.id, 
            Action = 'Order-Notice', 
            User = user, 
            OrderId = msg['X-PS-OrderId'], 
            Pool = Name,
            PoolId = ao.id,
            TxIn = msg['X-PS-TxIn'], 
            TxOut = msg.Id,
            TokenOut = tokenOut, 
            TokenIn = tokenIn, 
            AmountIn = amountIn, 
            AmountOut = amountOut,
            OrderStatus = msg['X-PS-Status'], 
            Error = err,
            TimeStamp = tostring(msg.Timestamp)
        })

        -- log swap
        -- Send({
        --     Target = ao.id,
        --     Action = 'SwapLog',
        --     Data = json.encode({
        --         YIn = YIn,
        --         XOut = XOut
        --     })
        -- })

        print("After swap, YIn: " ..YIn .." XOut: " ..XOut)

        local note = {
            NoteID = '',
            OrderId = msg['X-PS-OrderId'],
            IssueDate = msg.Timestamp,
            SettledDate = msg.Timestamp,
            Status = 'Settled',
            Issuer = ao.id,
            Settler = user,
            AssetID = tokenOut,
            Amount = amountOut,
            HolderAssetID = tokenIn,
            HolderAmount = amountIn,
        }
        local topic = 'Note.Settled.' .. ao.id
        Send({
            Target = Publisher,
            Action = 'Publish',
            Topic = topic,
            Data = json.encode(note)
        })
    end
)

Handlers.add('getOrder', 'GetOrder', 
    function(msg)
        assert(type(msg.OrderId) == 'string', 'OrderId is required')
        local order = txs.getTx(msg.OrderId) or ''
        msg.reply({Data = json.encode(order)})
    end
)

Handlers.add('addLiquidity', 'AddLiquidity', 
    function(msg)
        assert(false, 'this function should not be called by any one')
        assert(type(msg.MinLiquidity) == 'string', 'MinLiquidity is required')
        assert(bint.__lt(0, bint(msg.MinLiquidity)), 'MinLiquidity must be greater than 0')
        
        if Executing then
            msg.reply({Error = 'err_executing'})
            return
        end

        -- init liquidity
        if bint.__eq(bint('0'), bint(TotalSupply)) and 
            BalancesX[msg.From] and bint.__lt(0, bint(BalancesX[msg.From])) and 
            BalancesY[msg.From] and bint.__lt(0, bint(BalancesY[msg.From])) 
        then
            Px = BalancesX[msg.From]
            Py = BalancesY[msg.From]
            BalancesX[msg.From] = nil
            BalancesY[msg.From] = nil
            Balances[msg.From] = Px
            TotalSupply = Px
            msg.reply ({
                TimeStamp = tostring(msg.Timestamp),
                Action = 'LiquidityAdded-Notice',
                User = msg.From,
                Result = 'ok',
                Pool = Name,
                PoolId = ao.id,
                AddLiquidityTx = msg.Id,
                X = Pool.X,
                Y = Pool.Y,
                AmountX = Px,
                AmountY = Py,
                RefundX = '0',
                RefundY = '0',
                AmountLp = Px,
                BalanceLp = Balances[msg.From] or '0',
                TotalSupply = TotalSupply,
                Data = 'Liquidity added',

                -- Assignments = Mining,
            })

            for i, pid in ipairs(Mining) do
                Send({
                    Target = pid,
                    TimeStamp = tostring(msg.Timestamp),
                    Action = 'LiquidityAdded-Notice',
                    User = msg.From,
                    Result = 'ok',
                    Pool = Name,
                    PoolId = ao.id,
                    AddLiquidityTx = msg.Id,
                    X = Pool.X,
                    Y = Pool.Y,
                    AmountX = Px,
                    AmountY = Py,
                    RefundX = '0',
                    RefundY = '0',
                    AmountLp = Px,
                    BalanceLp = Balances[msg.From] or '0',
                    TotalSupply = TotalSupply,
                    Data = 'Liquidity added',
                })
            end

            local liquidityAddNotice = {
                User = msg.From,
                AddLiquidityTx = msg.Id,
                PoolId = ao.id,
                X = Pool.X,
                Y = Pool.Y,
                AmountX = Px,
                AmountY = Py,
                RefundX = '0',
                RefundY = '0',
                AmountLp = Px,
                BalanceLp = Balances[msg.From] or '0',
                TotalSupply = TotalSupply
            }
            local topic = 'Liquidity.Added.' .. ao.id
            Send({
                Target = Publisher,
                Action = 'Publish',
                Topic = topic,
                Data = json.encode(liquidityAddNotice)
            })

            return
        end

        if bint.__lt(0, bint(TotalSupply)) and 
            BalancesX[msg.From] and bint.__lt(0, bint(BalancesX[msg.From])) and 
            BalancesY[msg.From] and bint.__lt(0, bint(BalancesY[msg.From])) 
        then
            local totalLiquidity = bint(TotalSupply)
            local reserveX = bint(Px)
            local reserveY = bint(Py)
            local amountX = bint(BalancesX[msg.From])
            local amountY = bint.udiv(bint.__mul(amountX, reserveY), reserveX) + 1
            local liquidityMinted = bint.udiv(bint.__mul(amountX, totalLiquidity), reserveX) 
            
            if (not bint.__lt(liquidityMinted, bint(msg.MinLiquidity))) and (not bint.__lt(bint(BalancesY[msg.From]), amountY)) then
                Px = tostring(bint.__add(reserveX, amountX))
                Py = tostring(bint.__add(reserveY, amountY))
                BalancesX[msg.From] = nil
                
                local refundY = tostring(bint.__sub(bint(BalancesY[msg.From]), amountY))
                BalancesY[msg.From] = nil
                
                TotalSupply = tostring(bint.__add(totalLiquidity, liquidityMinted))
                if not Balances[msg.From] then Balances[msg.From] = '0' end
                Balances[msg.From] = tostring(bint.__add(bint(Balances[msg.From]), liquidityMinted))

                -- refund excess y token
                if bint.__lt(0, bint(refundY)) then
                    Send({ 
                        Target = Pool.Y, 
                        Action = 'Transfer', 
                        Recipient = msg.From, 
                        Quantity = refundY, 
                        ['X-PS-AddLiquidity-Refund-Id'] = msg.Id,
                        ['X-PS-Reason'] = 'AddLiquidity-Excess-Refund'
                    })
                end
                msg.reply ({
                    TimeStamp = tostring(msg.Timestamp),
                    Action = 'LiquidityAdded-Notice',
                    User = msg.From,
                    Result = 'ok',
                    Pool = Name,
                    PoolId = ao.id,
                    AddLiquidityTx = msg.Id,
                    X = Pool.X,
                    Y = Pool.Y,
                    AmountX = tostring(amountX),
                    AmountY = tostring(amountY),
                    RefundX = '0',
                    RefundY = refundY,
                    AmountLp = tostring(liquidityMinted),
                    BalanceLp = Balances[msg.From] or '0',
                    TotalSupply = TotalSupply,
                    Data = 'Liquidity added',

                    -- Assignments = Mining,
                })
                
                for i, pid in ipairs(Mining) do
                    Send({
                        Target = pid,
                        TimeStamp = tostring(msg.Timestamp),
                        Action = 'LiquidityAdded-Notice',
                        User = msg.From,
                        Result = 'ok',
                        Pool = Name,
                        PoolId = ao.id,
                        AddLiquidityTx = msg.Id,
                        X = Pool.X,
                        Y = Pool.Y,
                        AmountX = tostring(amountX),
                        AmountY = tostring(amountY),
                        RefundX = '0',
                        RefundY = refundY,
                        AmountLp = tostring(liquidityMinted),
                        BalanceLp = Balances[msg.From] or '0',
                        TotalSupply = TotalSupply,
                        Data = 'Liquidity added',
                    })
                end
                
                local liquidityAddNotice = {
                    User = msg.From,
                    AddLiquidityTx = msg.Id,
                    PoolId = ao.id,
                    X = Pool.X,
                    Y = Pool.Y,
                    AmountX = tostring(amountX),
                    AmountY = tostring(amountY),
                    RefundX = '0',
                    RefundY = refundY,
                    AmountLp = tostring(liquidityMinted),
                    BalanceLp = Balances[msg.From] or '0',
                    TotalSupply = TotalSupply
                }
                local topic = 'Liquidity.Added.' .. ao.id
                Send({
                    Target = Publisher,
                    Action = 'Publish',
                    Topic = topic,
                    Data = json.encode(liquidityAddNotice)
                })

                return
            end

            -- use amount y
            amountY = bint(BalancesY[msg.From])
            amountX = bint.udiv(bint.__mul(amountY, reserveX), reserveY) + 1
            liquidityMinted = bint.udiv(bint.__mul(amountX, totalLiquidity), reserveX)
            if (not bint.__lt(liquidityMinted, bint(msg.MinLiquidity))) and (not bint.__lt(bint(BalancesX[msg.From]), amountX)) then
                Px = tostring(bint.__add(reserveX, amountX))
                Py = tostring(bint.__add(reserveY, amountY))
                BalancesY[msg.From] = nil
                
                local refundX = tostring(bint.__sub(bint(BalancesX[msg.From]), amountX))
                BalancesX[msg.From] = nil
                
                TotalSupply = tostring(bint.__add(totalLiquidity, liquidityMinted))
                if not Balances[msg.From] then Balances[msg.From] = '0' end
                Balances[msg.From] = tostring(bint.__add(bint(Balances[msg.From]), liquidityMinted))

                -- refund excess X token
                if bint.__lt(0, bint(refundX)) then
                    Send({ 
                        Target = Pool.X, 
                        Action = 'Transfer', 
                        Recipient = msg.From, 
                        Quantity = refundX, 
                        ['X-PS-AddLiquidity-Refund-Id'] = msg.Id,
                        ['X-PS-Reason'] = 'AddLiquidity-Excess-Refund'
                    })
                end
                msg.reply ({
                    TimeStamp = tostring(msg.Timestamp),
                    Action = 'LiquidityAdded-Notice',
                    User = msg.From,
                    Result = 'ok',
                    Pool = Name,
                    PoolId = ao.id,
                    AddLiquidityTx = msg.Id,
                    X = Pool.X,
                    Y = Pool.Y,
                    AmountX = tostring(amountX),
                    AmountY = tostring(amountY),
                    RefundX = refundX,
                    RefundY = '0',
                    AmountLp = tostring(liquidityMinted),
                    BalanceLp = Balances[msg.From] or '0',
                    TotalSupply = TotalSupply,
                    Data = 'Liquidity added',

                    -- Assignments = Mining,
                })
                for i, pid in ipairs(Mining) do
                    Send({
                        Target = pid,
                        TimeStamp = tostring(msg.Timestamp),
                        Action = 'LiquidityAdded-Notice',
                        User = msg.From,
                        Result = 'ok',
                        Pool = Name,
                        PoolId = ao.id,
                        AddLiquidityTx = msg.Id,
                        X = Pool.X,
                        Y = Pool.Y,
                        AmountX = tostring(amountX),
                        AmountY = tostring(amountY),
                        RefundX = refundX,
                        RefundY = '0',
                        AmountLp = tostring(liquidityMinted),
                        BalanceLp = Balances[msg.From] or '0',
                        TotalSupply = TotalSupply,
                        Data = 'Liquidity added',
                    })
                end
                
                local liquidityAddNotice = {
                    User = msg.From,
                    AddLiquidityTx = msg.Id,
                    PoolId = ao.id,
                    X = Pool.X,
                    Y = Pool.Y,
                    AmountX = tostring(amountX),
                    AmountY = tostring(amountY),
                    RefundX = refundX,
                    RefundY = '0',
                    AmountLp = tostring(liquidityMinted),
                    BalanceLp = Balances[msg.From] or '0',
                    TotalSupply = TotalSupply
                }
                local topic = 'Liquidity.Added.' .. ao.id
                Send({
                    Target = Publisher,
                    Action = 'Publish',
                    Topic = topic,
                    Data = json.encode(liquidityAddNotice)
                })

                return
            end
        end

        local refundX = '0'
        local refundY = '0'
        if BalancesX[msg.From] and bint.__lt(0, bint(BalancesX[msg.From])) then
            refundX = BalancesX[msg.From]
            BalancesX[msg.From] = nil
            Send({
                Target = Pool.X, 
                Action = 'Transfer', 
                Recipient = msg.From, 
                Quantity = refundX, 
                ['X-PS-Reason']='AddLiquidity-Refund',
                ['X-PS-AddLiquidity-Refund-Id'] = msg.Id,
            })
        end

        if BalancesY[msg.From] and bint.__lt(0, bint(BalancesY[msg.From])) then
            refundY = BalancesY[msg.From]
            BalancesY[msg.From] = nil
            Send({ 
                Target = Pool.Y, 
                Action = 'Transfer', 
                Recipient = msg.From, 
                Quantity = refundY, 
                ['X-PS-Reason']='AddLiquidity-Refund',
                ['X-PS-AddLiquidity-Refund-Id'] = msg.Id,
            })
        end

        msg.reply ({
            TimeStamp = tostring(msg.Timestamp),
            User = msg.From,
            Action = 'LiquidityAddFailed-Notice',
            Pool = Name,
            PoolId = ao.id,
            X = Pool.X,
            Y = Pool.Y,
            AddLiquidityTx = msg.Id,
            Result = 'Refund',
            AmountX = '0',
            AmountY = '0',
            RefundX = refundX,
            RefundY = refundY,
            AmountLp = '0',
            BalanceLp = Balances[msg.From] or '0',
            TotalSupply = TotalSupply,
            Data='Liquidity not added'
        })
    end
)

Handlers.add('removeLiquidity', 'RemoveLiquidity', 
    function(msg)
        assert(false, 'this function should not be called by any one')
        assert(bint.__lt(0, bint(TotalSupply), 'Pool no liquidity'))
        assert(type(msg.Quantity) == 'string', 'Quantity is required')
        assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')
        assert(type(msg.MinX) == 'string', 'MinX is required')
        assert(bint.__lt(0, bint(msg.MinX)), 'MinX must be greater than 0')
        assert(type(msg.MinY) == 'string', 'MinY is required')
        assert(bint.__lt(0, bint(msg.MinY)), 'MinY must be greater than 0')
        
        if Executing then
            msg.reply({Error = 'err_executing'})
            return
        end

        local qty = bint(msg.Quantity)
        local minX = bint(msg.MinX)
        local minY = bint(msg.MinY)
        if Balances[msg.From] and (bint.__lt(qty, bint(Balances[msg.From])) or (bint.__eq(qty, bint(Balances[msg.From])))) then
            local totalLiquidity = bint(TotalSupply)
            local reserveX = bint(Px)
            local reserveY = bint(Py)
            local amountX = bint.udiv(bint.__mul(qty, reserveX), totalLiquidity) 
            local amountY = bint.udiv(bint.__mul(qty, reserveY), totalLiquidity)
            if bint.__lt(amountX, minX) or bint.__lt(amountY, minY) then
                msg.reply ({
                    TimeStamp = tostring(msg.Timestamp),
                    User = msg.From,
                    Action = 'LiquidityRemoveFailed-Notice',
                    Pool = Name,
                    PoolId = ao.id,
                    X = Pool.X,
                    Y = Pool.Y,
                    MinX = msg.MinX,
                    MinY = msg.MinY,
                    RemoveLiquidityTx = msg.Id,
                    Data='Liquidity not removed',
                    Error = 'err_amount_output_too_small'
                })
                return
            end
            TotalSupply = tostring(bint.__sub(totalLiquidity , qty))
            Px = tostring(bint.__sub(reserveX, amountX))
            Py = tostring(bint.__sub(reserveY, amountY))
            Balances[msg.From] = tostring(bint.__sub(bint(Balances[msg.From]), qty))
            Send({ 
                Target = Pool.X, 
                Action = 'Transfer', 
                Recipient = msg.From,
                Quantity = tostring(amountX),
                ['X-PS-RemoveLiquidity-Id'] = msg.Id, 
                ['X-PS-Reason']='RemoveLiquidity'
            })
            Send({ 
                Target = Pool.Y, 
                Action = 'Transfer', 
                Recipient = msg.From, 
                Quantity = tostring(amountY), 
                ['X-PS-RemoveLiquidity-Id'] = msg.Id,
                ['X-PS-Reason']='RemoveLiquidity'
            })
            msg.reply ({
                TimeStamp = tostring(msg.Timestamp),
                Action = 'LiquidityRemoved-Notice',
                User = msg.From,
                Result = 'ok',
                Pool = Name,
                PoolId = ao.id,
                RemoveLiquidityTx = msg.Id,
                X = Pool.X,
                Y = Pool.Y,
                AmountX = tostring(amountX),
                AmountY = tostring(amountY),
                AmountLp = msg.Quantity,
                BalanceLp = Balances[msg.From] or '0',
                TotalSupply = TotalSupply,
                Data = 'Liquidity removed',

                -- Assignments = Mining,
            })

            for i, pid in ipairs(Mining) do
                Send({
                    Target = pid,
                    TimeStamp = tostring(msg.Timestamp),
                    Action = 'LiquidityRemoved-Notice',
                    User = msg.From,
                    Result = 'ok',
                    Pool = Name,
                    PoolId = ao.id,
                    RemoveLiquidityTx = msg.Id,
                    X = Pool.X,
                    Y = Pool.Y,
                    AmountX = tostring(amountX),
                    AmountY = tostring(amountY),
                    AmountLp = msg.Quantity,
                    BalanceLp = Balances[msg.From] or '0',
                    TotalSupply = TotalSupply,
                    Data = 'Liquidity removed'
                })
            end

            local liquidityRemoveNotice = {
                User = msg.From,
                RemoveLiquidityTx = msg.Id,
                PoolId = ao.id,
                X = Pool.X,
                Y = Pool.Y,
                AmountX = tostring(amountX),
                AmountY = tostring(amountY),
                AmountLp = msg.Quantity,
                BalanceLp = Balances[msg.From] or '0',
                TotalSupply = TotalSupply
            }
            local topic = 'Liquidity.Removed.' .. ao.id
            Send({
                Target = Publisher,
                Action = 'Publish',
                Topic = topic,
                Data = json.encode(liquidityRemoveNotice)
            })

        else
            msg.reply ({
                TimeStamp = tostring(msg.Timestamp),
                User = msg.From,
                Action = 'LiquidityRemoveFailed-Notice',
                Pool = Name,
                PoolId = ao.id,
                X = Pool.X,
                Y = Pool.Y,
                MinX = msg.MinX,
                MinY = msg.MinY,
                RemoveLiquidityTx = msg.Id,
                Data='Liquidity not removed',
                Error = 'err_insufficient_balance'
            })
        end
    end
)

Handlers.add('transfer', 'Transfer', function(msg)
    assert(type(msg.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')
  
    if not Balances[msg.From] then Balances[msg.From] = '0' end
    if not Balances[msg.Recipient] then Balances[msg.Recipient] = '0' end
  
    if bint(msg.Quantity) <= bint(Balances[msg.From]) then
      Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
      Balances[msg.Recipient] = utils.add(Balances[msg.Recipient], msg.Quantity)
      
      if Balances[msg.From] == '0' then
        Balances[msg.From] = nil
      end

      if not msg.Cast then
        -- Debit-Notice message template, that is sent to the Sender of the transfer
        local debitNotice = {
          Action = 'Debit-Notice',
          Recipient = msg.Recipient,
          Quantity = msg.Quantity,
          Data = Colors.gray ..
              'You transferred ' ..
              Colors.blue .. msg.Quantity .. Colors.gray .. ' to ' .. Colors.green .. msg.Recipient .. Colors.reset
        }
        -- Credit-Notice message template, that is sent to the Recipient of the transfer
        local creditNotice = {
          Target = msg.Recipient,
          Action = 'Credit-Notice',
          Sender = msg.From,
          Quantity = msg.Quantity,
          Data = Colors.gray ..
              'You received ' ..
              Colors.blue .. msg.Quantity .. Colors.gray .. ' from ' .. Colors.green .. msg.From .. Colors.reset
        }
  
        -- Add forwarded tags to the credit and debit notice messages
        for tagName, tagValue in pairs(msg) do
          -- Tags beginning with 'X-' are forwarded
          if string.sub(tagName, 1, 2) == 'X-' then
            debitNotice[tagName] = tagValue
            creditNotice[tagName] = tagValue
          end
        end
  
        -- Send Debit-Notice and Credit-Notice
        msg.reply(debitNotice)
        Send(creditNotice)

        -- Send Transfer-Notice
        for i, pid in ipairs(Mining) do
            Send({
                Target = pid,
                Action = 'Transfer-Notice',
                Sender = msg.From,
                Recipient = msg.Recipient,
                Quantity = msg.Quantity,
                SenderBalance = Balances[msg.From] or '0',
                RecipientBalance = Balances[msg.Recipient] or '0',
                Data = 'Liquidity transfered',
            })
        end
        local liquidityTransferNotice = {
            User = msg.From,
            TransferTx = msg.Id,
            PoolId = ao.id,
            X = Pool.X,
            Y = Pool.Y,
            Sender = msg.From,
            Recipient = msg.Recipient,  
            Quantity = msg.Quantity,
            SenderBalance = Balances[msg.From] or '0',
            RecipientBalance = Balances[msg.Recipient] or '0',
        }
        local topic = 'Liquidity.Transfer.' .. ao.id
        Send({
            Target = Publisher,
            Action = 'Publish',
            Topic = topic,
            Data = json.encode(liquidityTransferNotice)
        })
        
      end
    else
      msg.reply({
        Action = 'Transfer-Error',
        ['Message-Id'] = msg.Id,
        Error = 'Insufficient Balance!'
      })
    end
end)
  
Handlers.add('totalSupply', 'Total-Supply', function(msg)
    assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')  
    msg.reply({
      Action = 'Total-Supply',
      Data = TotalSupply,
      Ticker = Ticker
    })
end)

-- liquidity mining
Handlers.add('registerMining', 'RegisterMining', 
    function(msg)
        
        local exists = false
        for i, pid in ipairs(Mining) do
            if pid == msg.From then
                exists = true
                break
            end
        end

        if not exists then
            table.insert(Mining, msg.From)
            msg.reply({ 
                Action = 'RegisteredMining',
                Data = json.encode(Balances) 
            })
        else
            msg.reply({Error = 'err_mining_pid_exists'})
        end
    end
)

Handlers.add('unregisterMining', 'UnregisterMining', 
    function(msg)
        for i, pid in ipairs(Mining) do
            if pid == msg.From then
                table.remove(Mining, i)
                break
            end
        end
        msg.reply({Action = 'UnregisteredMining'})
    end
)

local function validateOrderMsg(msg)
    local x = msg.TokenIn == Pool.X and msg.TokenOut == Pool.Y
    local y = msg.TokenIn == Pool.Y and msg.TokenOut == Pool.X
    if not x and not y then
        return false, 'err_invalid_asset'
    end
    
    if not msg.AmountIn then
        return false, 'err_no_amount_in'
    end
    local ok, err = validateAmount(msg.AmountIn)
    if not ok then
        return false, 'err_invalid_amount_in'
    end
    
    if msg.AmountOut then
        local ok, err = validateAmount(msg.AmountOut)
        if not ok then
            return false, 'err_invalid_amount_out'
        end
    end

    return true, nil
end

local function validateAmountOut(tokenIn, amountIn, tokenOut, expectedAmountOut)
    local amountOut = bint('0')
    if tokenIn == Pool.X then
        local reserveIn = bint(Px)
        local reserveOut = bint(Py)
        amountOut = getInputPrice(amountIn, reserveIn, reserveOut, bint(Pool.Fee))
    elseif tokenIn == Pool.Y then
        local reserveIn = bint(Py)
        local reserveOut = bint(Px)
        amountOut = getInputPrice(amountIn, reserveIn, reserveOut, bint(Pool.Fee))
    else
        return false
    end

    if bint.__eq(amountOut, bint('0')) then
        return false
    end
    if bint.__lt(amountOut, expectedAmountOut) then
        return false
    end
    return true
end

Handlers.add('makeOrder', 
  function(msg) return ((msg.Action == 'MakeOrder') or (msg.Action == 'FFP.MakeOrder')) end,
  function(msg)
    if Executing then
        msg.reply({Error = 'err_executing'})
        return
    end
    
    local ok, err = validateOrderMsg(msg)
    if not ok then
        msg.reply({Error = err})
        return
    end

    local amountOut = msg.AmountOut
    if amountOut then
        ok = validateAmountOut(msg.TokenIn, msg.AmountIn, msg.TokenOut, amountOut)
        if not ok then
            msg.reply({Error = 'err_invalid_amount_out'})
            return
        end
    end

    if not amountOut then
        local amountIn = bint(msg.AmountIn)
        local amountOut = tostring(getInputPrice(amountIn, bint(Px), bint(Py), bint(Pool.Fee)))
        if msg.TokenIn == Pool.Y then
            amountOut = tostring(getInputPrice(amountIn, bint(Py), bint(Px), bint(Pool.Fee)))
        end
    end

    -- 90 seconds
    local expireDate = msg.Timestamp + TimeoutPeriod

    local res = Send({
        Target = Settle,
        Action = 'CreateNote',
        AssetID = msg.TokenOut,
        Amount = amountOut,
        HolderAssetID = msg.TokenIn,
        HolderAmount = msg.AmountIn,
        IssueDate = tostring(msg.Timestamp),
        ExpireDate = tostring(expireDate),
        Version = SettleVersion
    }).receive()
    local noteID = res.NoteID
    Notes[noteID] = json.encode(res.Data)
    MakeTxToNoteID[msg.Id] = noteID

    -- remove expired notes in Notes
    for noteID, note in pairs(Notes) do
        if note.Status == 'Open' and note.ExpireDate and note.ExpireDate < msg.Timestamp then
            Notes[noteID] = nil
            MakeTxToNoteID[note.MakeTx] = nil
        end
    end 

    msg.reply({
        Action = 'OrderMade-Notice',
        NoteID = noteID,
        Data = json.encode(note)
    })
  end
)

Handlers.add('getNote', 
    function(msg) return ((msg.Action == 'GetNote') or (msg.Action == 'FFP.GetNote')) end,
    function(msg)
        assert(type(msg.MakeTx) == 'string', 'MakeTx is required')
        
        local noteID = MakeTxToNoteID[msg.MakeTx]
        if not noteID then
            msg.reply({Error = 'err_note_not_found'})
            return
        end

        local note = Notes[noteID]
        if not note then
            msg.reply({Error = 'err_note_not_found'})
            return
        end

        msg.reply({ Action = 'GetNote-Notice', NoteID=noteID, Data = json.encode(note) })
    end
)

Handlers.add('execute', 'Execute',
  function(msg)
    assert(msg.From == Settle, 'Only settle can start exectue')
    assert(type(msg.NoteID) == 'string', 'NoteID is required')
    assert(type(msg.SettleID) == 'string', 'SettleID is required')

    if Executing then
        msg.reply({Action= 'Reject', Error = 'err_executing', SettleID = msg.SettleID, NoteID = msg.NoteID})
        return
    end

    local note = Notes[msg.NoteID]
    if not note then
        msg.reply({Action= 'Reject', Error = 'err_not_found', SettleID = msg.SettleID, NoteID = msg.NoteID})
        return
    end
    if note.Status ~= 'Open' then
        msg.reply({Action= 'Reject', Error = 'err_not_open', SettleID = msg.SettleID, NoteID = msg.NoteID})
        return
    end
    if note.Issuer ~= ao.id then
        msg.reply({Action = 'Reject', Error = 'err_invalid_issuer', SettleID = msg.SettleID, NoteID = msg.NoteID})
        return
    end
    if note.ExpireDate and note.ExpireDate < msg.Timestamp then
        Notes[note.NoteID] = nil
        MakeTxToNoteID[note.MakeTx] = nil
        msg.reply({Action= 'Reject', Error = 'err_expired', SettleID = msg.SettleID, NoteID = msg.NoteID})
        return
    end
    ok = validateAmountOut(note.HolderAssetID, note.HolderAmount, note.AssetID, note.Amount)
    if not ok then
        msg.reply({Action= 'Reject', Error = 'err_invalid_amount_out', SettleID = msg.SettleID, NoteID = msg.NoteID})
        return
    end

    msg.reply({Action = 'ExecuteStarted', SettleID = msg.SettleID, NoteID = msg.NoteID})

    Executing = true
    note.Status = 'Executing'
    if note.AssetID == Pool.X then
        Px = utils.subtract(Px, note.Amount)
    else
        Py = utils.subtract(Py, note.Amount)
    end
    Send({Target = note.AssetID, Action = 'Transfer', Quantity = note.Amount, Recipient = Settle, 
      ['X-FFP-SettleID'] = msg.SettleID, 
      ['X-FFP-NoteID'] = msg.NoteID,
      ['X-FFP-For'] = 'Execute'
    })
  end
)

Handlers.add('finish',
    function(msg) return (msg.Action == 'Credit-Notice') and (msg['X-FFP-For'] == 'Settled' or msg['X-FFP-For'] == 'Refund') end,
    function(msg)
        assert(msg.Sender == Settle, 'Only settle can send settled or refund msg')
        if msg.From == Pool.X then
            Px = utils.add(Px, msg.Quantity)
        else
            Py = utils.add(Py, msg.Quantity)
        end
        local noteID = msg['X-FFP-NoteID']
        local note = Notes[noteID]
        if not note then
            print('no note found when settled: ' .. noteID)
            return 
        end

        Executing = false
        Notes[noteID] = nil
        MakeTxToNoteID[note.MakeTx] = nil

        local status = msg['X-FFP-For']
        local orderStatus = status
        if status == 'Settled' then
            orderStatus = 'Swapped'
        end

        local note2 = json.decode(Send({Target = Settle, Action = 'GetNote', NoteID = noteID}).receive().Data)
        local ts = note2.SettledDate
        if not ts then
            ts = msg.Timestamp
        end

        local order = {
            User = note2.Settler,
            OrderId = note2.NoteID,
            NoteID = note2.NoteID,
            SettleID = note2.SettleID,
            OrderType = 'Note',
            Pool = Name,
            PoolId = ao.id,
            TokenIn = msg.From,
            AmountIn = msg.Quantity,
            TokenOut = note2.AssetID,
            AmountOut = note2.Amount,
            OrderStatus = orderStatus,
            TxIn = msg.Id,
            TimeStamp = tostring(ts)
        }
        txs.insertTx(note2.NoteID, order) 

        local notice = order
        notice.Target = ao.id
        notice.Action = 'Order-Notice'
        Send(notice)
    end
)