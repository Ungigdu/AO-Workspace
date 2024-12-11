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

async function Mint(process, quantity, wallet) {
    const t = [{ name: 'Quantity', value: quantity }];
    return await messageToAO(process, "Mint", t, {}, wallet);
}

export {
    DefaultWallet,
    AcidTokenProcess,
    Mint
}