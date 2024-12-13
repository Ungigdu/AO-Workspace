import {
    messageToAO,
    getDataFromAO,
} from "./preload1.js";

import { readFileSync } from "node:fs";

//only this wallet can update data to the rumble process
const DefaultWallet = JSON.parse(
    readFileSync("./key/arweave-keyfile-L6c-rsg7qBxAo8LE_iG5Ms-Q7FgnHepB8nrxfnO7j3s.json").toString(),
);

const AcidTokenProcess = "O0DQgVialkpP9-jGU-zgkLVDBlY_syL0bono_o9i-VM";

async function Mint(wallet, process, quantity) {
    const t = [{ name: 'Quantity', value: quantity }];
    return await messageToAO(wallet, process, "Mint", t, {});
}

async function Transfer(wallet, process, quantity, recepient) {
    const t = [{ name: 'Quantity', value: quantity }, { name: 'Recipient', value: recepient }];
    return await messageToAO(wallet, process, "Transfer", t, {});
}

async function Swap(wallet, tokenIn, quantity, recepient) {
    const t = [{ name: 'Quantity', value: quantity }, 
               { name: 'Recipient', value: recepient }, 
               {name: 'X-PS-For', value: 'Swap'},
               {name: 'X-PS-MinAmountOut', value: '1'}
            ];
    return await messageToAO(wallet, tokenIn, "Transfer", t, {});
}

export {
    DefaultWallet,
    AcidTokenProcess,
    Mint,
    Transfer,
    Swap
}