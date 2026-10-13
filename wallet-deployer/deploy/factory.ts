export const EverWalletCode =
  'te6ccgEBBgEA/AABFP8A9KQT9LzyyAsBAgEgBQIC5vJx1wEBwADyeoMI1xjtRNCDB9cB1ws/yPgozxYjzxbJ+QADcdcBAcMAmoMH1wFRE7ry4GTegEDXAYAg1wGAINcBVBZ1+RDyqPgju/J5Zr74I4EHCKCBA+ioUiC8sfJ0AiCCEEzuZGy64w8ByMv/yz/J7VQEAwA+ghAWnj4Ruo4R+AACkyDXSpd41wHUAvsA6NGTMvI84gCYMALXTND6QIMG1wFx1wF41wHXTPgAcIAQBKoCFLHIywVQBc8WUAP6AstpItAhzzEh10mghAm5mDNwAcsAWM8WlzBxAcsAEsziyQH7AAAE0jA=';

const NONCE = +(process.env["NONCE"] || "0");


export default async () => {

    const signer = await locklift.keystore.getSigner('0');

    const factory  = await locklift.deployments.deploy({
        deployConfig: {
            contract: "walletFactory",
            publicKey: signer!.publicKey,
            initParams: { _nonce: NONCE },
            constructorParams: { _everWalletCode:  EverWalletCode},
            value: locklift.utils.toNano(5)
        },
        deploymentName: "factory",
        enableLogs: true,
    });

    console.log(factory.tx?.transaction.id);

};

export const tag = "factory";