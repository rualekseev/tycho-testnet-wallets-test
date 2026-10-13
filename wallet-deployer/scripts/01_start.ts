import { Address } from "locklift";
import { walletFactoryAbi } from "../build/factorySource";

const WALLETS = +(process.env["WALLETS"] || "10");
const BALANCE = +(process.env["BALANCE"] || "5");

async function main() {
  await locklift.deployments.load();

  const pubKey = await locklift.keystore.getSigner("0").then(s => s!.publicKey);

  // The user's own EverWallet (same key as signer "0"). It is registered as the giver,
  // so locklift already knows how to sign messages from it.
  const owner = new Address(process.env["WALLET_ADDRESS"]!);

  const factory = await locklift.deployments.getContract<walletFactoryAbi>("factory");

  const tx = await factory.methods
    .batchEverWalletDeploy({
      _index: 0,
      _balance: locklift.utils.toNano(BALANCE),
      _publicKey: "0x" + pubKey,
      _count: WALLETS,
    })
    .send({
      from: owner,
      amount: locklift.utils.toNano(WALLETS * BALANCE + WALLETS),
    });

  console.log("tx", tx.id.hash);
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
