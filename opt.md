## Operations to launch bonding curve

current: 6

1. aos load meme 
2. aos load fwAR (in test)
3. aos load amm
4. mint meme 1000000829080000000000
    Send({ Target = ao.id, Action = "Mint", Quantity = "1000000829080000000000"}).receive().Data
5. send meme to pool 1000000829080000000000
    Send({ Target = ao.id, Action = "Transfer", Recipient = "", Quantity = "1000000829080000000000"}).receive().Data
6. check balance
    Send({ Target = ao.id, Action = "Balance", Recipient = ""}).receive().Data
7. mint fwAR 888000000000000
    Send({ Target = ao.id, Action = "Mint", Quantity = "888000000000000"}).receive().Data