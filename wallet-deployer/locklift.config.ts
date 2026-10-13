import { lockliftChai, LockliftConfig } from "locklift";
import { FactorySource } from "./build/factorySource";
import * as dotenv from "dotenv";
import chai from "chai";
import "@broxus/locklift-deploy";
import { Deployments } from "@broxus/locklift-deploy";

dotenv.config({ path: "../.env" });

chai.use(lockliftChai);

declare module "locklift" {
  //@ts-ignore
  export interface Locklift {
    deployments: Deployments<FactorySource>;
  }
}

declare global {
  const locklift: import("locklift").Locklift<FactorySource>;
}

const PHRASE = process.env.PHRASE || "";
const JRPC_ENDPOINT = process.env.JRPC_ENDPOINT || "https://rpc-testnet.tychoprotocol.com/rpc";
// EverWallet derived from PHRASE; run.sh computes it via scripts/wallet.js.
const WALLET_ADDRESS = process.env.WALLET_ADDRESS || "0:0000000000000000000000000000000000000000000000000000000000000000";

const config: LockliftConfig = {
  compiler: {
    version: "0.64.0",
  },
  linker: {
    version: "0.15.71",
  },
  networks: {
    // Local in-memory network, required by locklift config typings.
    locklift: {
      connection: {
        id: 1001,
        // @ts-ignore
        type: "proxy",
        // @ts-ignore
        data: {},
      },
      keys: {
        amount: 1,
      },
    },
    tycho_testnet: {
      connection: {
        id: 2000,
        type: "jrpc",
        data: {
          endpoint: JRPC_ENDPOINT,
        },
      },
      // The user's own wallet acts as a giver: it pays for the factory deployment.
      giver: {
        address: WALLET_ADDRESS,
        phrase: PHRASE,
        accountId: 0,
      },
      keys: {
        phrase: PHRASE,
        amount: 1,
      },
    },
  },
  mocha: {
    timeout: 2000000,
  },
};

export default config;
