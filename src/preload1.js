import {
    result,
    results,
    message,
    spawn,
    monitor,
    unmonitor,
    dryrun,
    createDataItemSigner
} from "@permaweb/aoconnect";

async function messageToAO(process, action, tags, data, wallet) {
    try {
        const t = tags ? tags : [];
        const d = data ? data : {};
        t.push({ name: 'Action', value: action });
        const msg = {
          process: process,
          signer: createDataItemSigner(wallet),
          tags: t,
          data: JSON.stringify(d)
        }
        console.log("messageToAO -> msg:", msg)
        const messageId = await message(msg);
        return messageId;
    } catch (error) {
        console.log("messageToAO -> error:", error)
        return '';
    }
}

async function getDataFromAO(process, action, data) {
    let result;
    try {
      result = await dryrun({
        process,
        data: JSON.stringify(data),
        tags: [{ name: 'Action', value: action }]
      });
    } catch (error) {
      console.log('getDataFromAO --> ERR:', error)
      return '';
    }
  
    const resp = result.Messages?.length > 0 ? result.Messages[0].Data : null;
  
    if (resp) {
      return JSON.parse(resp);
    } else {
      console.error("No messages received");
      return null;
    }
}

// const RumbleProcess = "yBt50ZIij0gkWgFOVWsxyXUmu4Rz8UiqWgxG9YUsgMg";

// async function addRumbleLog(log_data) {
//     const action = "AddRumbleLog";
//     const data = {
//         ProfileId: log_data.ProfileId,
//         Timestamp: log_data.Timestamp,
//         TextLog: log_data.TextLog,
//         TotalActions: log_data.TotalActions,
//         TotalKills: log_data.TotalKills,
//         TotalMatches: log_data.TotalMatches
//     }
//     return await messageToAO(RumbleWallet, RumbleProcess, action, data);
// }

// async function queryRumbleLogs(profile_id, timestamp) {
//     const action = "GetLogs";
//     const data = { ProfileId: profile_id, Timestamp: timestamp };
//     return await getDataFromAO(RumbleProcess, action, data);
// }

// addRumbleLog({ ProfileId: "Hevin", Timestamp: "2024-01-02", TextLog: "test", TotalActions: 10, TotalKills: 5, TotalMatches: 2 }).then(console.log).catch(console.error);
// queryRumbleLogs("Hevin", "2024-01-01").then(console.log).catch(console.error);
// queryRumbleLogs("Hevin").then(console.log).catch(console.error);

export {
    messageToAO,
    getDataFromAO,
}