# Tycho testnet wallets load test

A load test for the Tycho testnet: it deploys N [Wallet](https://github.com/broxus/ever-wallet-contract) contracts and makes them send transfers to each other.

How it works:
1. [`wallet-deployer`](wallet-deployer) (locklift): the `WalletFactory` contract deploys `WALLETS` wallets in one go and puts `BALANCE` test tokens on each of them.
2. [nekroddos](https://github.com/broxus/nekroddos) (built from source): every wallet sends `ITERATIONS` transfers to random wallets from the set; the total rate is limited to `RPS` transactions per second.

## Quick start

```bash
git clone https://github.com/rualekseev/tycho-testnet-wallets-test.git
cd tycho-testnet-wallets-test
cp .env.example .env      # adjust the parameters if needed
./run.sh                  # or ./run.sh --docker
```

If `PHRASE` in `.env` is empty, the script generates a new seed phrase and saves it to `.env`.
Then it shows your wallet address and the amount it needs:

```
==================================================================
 Top up your wallet with at least 310.0 test tokens:
   0:a17a35b7...

 Get test tokens from the Telegram bot: https://t.me/tychonet_bot
==================================================================
Waiting for funds...
```

Top up this address with test tokens via the [@tychonet_bot](https://t.me/tychonet_bot) Telegram bot. The script waits for the funds, deploys the wallets and starts the load.

## Requirements

- `./run.sh --docker`: Docker (or Podman: `DOCKER=podman ./run.sh --docker`).
- `./run.sh`: Node.js 18+, npm, git and Rust ([rustup.rs](https://rustup.rs)). On Linux, building nekroddos also needs `pkg-config` and OpenSSL headers (`libssl-dev` / `openssl-devel`).

## Configuration (`.env`)

| Variable | Default | Description |
|---|---|---|
| `PHRASE` | generated | 12-word BIP39 seed phrase of your [Wallet](https://github.com/broxus/ever-wallet-contract) (path m/44'/396'/0'/0/0) |
| `JRPC_ENDPOINT` | `https://rpc-testnet.tychoprotocol.com/rpc` | Testnet JRPC endpoint used for deployment (and for the load if `LOAD_ENDPOINTS` is empty) |
| `LOAD_ENDPOINTS` | empty | Endpoints that receive the load, comma or space separated. A bare host/IP expands to `http://<host>:8080/rpc`, full URLs are used as is |
| `ENDPOINT_MODE` | `rr` | `rr`: one client, requests go round-robin across endpoints. `distinct`: one worker per endpoint, `RPS` and wallets are split evenly between them |
| `WALLETS` | `100` | Number of wallets to deploy and use in the load |
| `BALANCE` | `2` | Test tokens put on each wallet |
| `RPS` | `50` | Total sending rate, transactions per second |
| `ITERATIONS` | `100` | Transfers sent by each wallet (`WALLETS × ITERATIONS` in total) |
| `NEKRODDOS_REF` | `master` | nekroddos branch, tag or commit |

Required balance: `WALLETS × (BALANCE + 1) + 10` test tokens.

Example: load your own nodes, one worker per node:

```bash
LOAD_ENDPOINTS="10.0.0.1,10.0.0.2"
ENDPOINT_MODE=distinct
```

## Running again

Deployed wallets are recorded in `wallet-deployer/deployments/tycho_testnet/`. A repeated `./run.sh` goes straight to the load if `WALLETS` has not increased.
If `WALLETS` has increased, a new factory is deployed and the old record is moved to `deployments/tycho_testnet.<date>`.
To force a fresh deployment, delete `wallet-deployer/deployments/tycho_testnet/`.

Tokens left on the wallets remain yours: all of them are controlled by the key from `PHRASE`.

## Layout

```
run.sh                 entry point
.env.example           settings template
Dockerfile             image with Node.js and prebuilt nekroddos (for --docker)
wallet-deployer/       locklift project
  contracts/           WalletFactory.tsol
  build/               compiled artifacts (no rebuild needed)
  deploy/factory.ts    factory deployment
  scripts/wallet.js    wallet address from PHRASE, waiting for funds
  scripts/01_start.ts  wallets deployment
  scripts/02_stats.ts  waits until all wallets are deployed
```

> **Never commit `.env`**: it contains your seed phrase.
