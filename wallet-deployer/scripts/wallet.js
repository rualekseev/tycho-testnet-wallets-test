// Helper for run.sh: works before locklift starts, because locklift needs a funded giver.
//
//   node scripts/wallet.js address          -> prints EverWallet address derived from PHRASE
//   node scripts/wallet.js wait <ever>      -> waits until that wallet has at least <ever> on balance
//
// Env: PHRASE (12 words), JRPC_ENDPOINT.
const { deriveBip39Phrase, makeBip39Path } = require("everscale-crypto");
const { EverWalletAccount, EverscaleStandaloneClient } = require("everscale-standalone-client/nodejs");
const { ProviderRpcClient } = require("everscale-inpage-provider");

const NANO = 1_000_000_000n;

async function walletAddress() {
  const phrase = process.env.PHRASE;
  if (!phrase) throw new Error("PHRASE is not set");
  // Same derivation as locklift signer "0" and nekoton Bip39 labs_old(0) used by nekroddos.
  const { publicKey } = deriveBip39Phrase(phrase, makeBip39Path(0));
  return EverWalletAccount.computeAddress({ publicKey });
}

async function balanceOf(address) {
  const provider = new ProviderRpcClient({
    fallback: () =>
      EverscaleStandaloneClient.create({
        connection: { id: 2000, type: "jrpc", data: { endpoint: process.env.JRPC_ENDPOINT } },
      }),
    forceUseFallback: true,
  });
  const { state } = await provider.getFullContractState({ address });
  return state ? BigInt(state.balance) : 0n;
}

const fmt = nano => `${nano / NANO}.${(nano % NANO).toString().padStart(9, "0").replace(/0+$/, "") || "0"}`;

async function main() {
  const [cmd, arg] = process.argv.slice(2);
  const address = await walletAddress();

  if (cmd === "address") {
    console.log(address.toString());
    return;
  }

  if (cmd === "wait") {
    const required = BigInt(Math.ceil(Number(arg) * 1e9));
    let shown = false;
    for (;;) {
      const balance = await balanceOf(address);
      if (balance >= required) {
        if (shown) process.stdout.write("\n");
        console.log(`Wallet ${address} balance: ${fmt(balance)} (required ${fmt(required)})`);
        return;
      }
      if (!shown) {
        console.log("");
        console.log("==================================================================");
        console.log(` Top up your wallet with at least ${fmt(required - balance)} test tokens:`);
        console.log(`   ${address}`);
        console.log("");
        console.log(" Get test tokens from the Telegram bot: https://t.me/tychonet_bot");
        console.log("==================================================================");
        console.log("Waiting for funds...");
        shown = true;
      }
      process.stdout.write(`\r  balance: ${fmt(balance)} / ${fmt(required)}   `);
      await new Promise(r => setTimeout(r, 5000));
    }
  }

  throw new Error(`Unknown command: ${cmd}`);
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error(e.message || e);
    process.exit(1);
  });
