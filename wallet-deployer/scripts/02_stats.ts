import { walletFactoryAbi } from "../build/factorySource";

const WALLETS = +(process.env["WALLETS"] || "10");

async function main() {
  await locklift.deployments.load();

  const factory = await locklift.deployments.getContract<walletFactoryAbi>("factory");

  while (true) {
    const deployed = await factory.methods.get_deployed().call();

    if (parseInt(deployed.deployed) >= WALLETS) {
      console.log();
      console.log(`SUCCESS: ${deployed.deployed} wallets deployed`);
      break;
    }
    process.stdout.write(`\r  deployed: ${deployed.deployed} / ${WALLETS}   `);
    await new Promise(f => setTimeout(f, 1000));
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
