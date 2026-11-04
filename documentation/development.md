# Development guide

## Requirements

- Node.js 24, which can run the TypeScript script directly
- npm
- For deployment only: an RPC URL for Sepolia, an Etherscan API key, and a wallet holding Sepolia ETH

## Install

```bash
git clone git@github.com:Enelsep/ft_tokenizer.git
cd ft_tokenizer/code
npm ci
```

## Build and test

Run these from `code/`:

```bash
npx hardhat build             # compile the contracts
npx hardhat test              # run all the tests
npx hardhat test --coverage   # also report coverage
npx tsc --noEmit              # typecheck the TypeScript files
```

The tests are written in Solidity and run directly in the EVM:

- [`Ponzi42.t.sol`](../code/contracts/Ponzi42.t.sol) covers the token: deployment, the maximum supply, transfers, allowances, minting and ownership.
- [`Ponzi42Multisig.t.sol`](../code/contracts/Ponzi42Multisig.t.sol) covers the multisig: its settings, the handover of the token, the transaction lifecycle, and access control.

Some are fuzz tests, which repeat a check with many random inputs.

## Project layout

Hardhat's configuration and dependencies live in `code/`, while the deployment files live in `deployment/`, as the subject requires. Two files connect them:

- `deployment/node_modules` is a symbolic link to `code/node_modules`, because Node looks for packages relative to the file importing them. It only works after `npm ci` has run in `code/`.
- `deployment/package.json` marks the folder as ES modules, which Hardhat 3 requires.

`paths.ignition` in [`hardhat.config.ts`](../code/hardhat.config.ts) points Hardhat to the deployment folder.

## Deploy your own copy

The token and multisig in the [main README](../README.md) are already live, so you don't need to deploy to use them.

### 1. Store your secrets

Run these from `code/`. Hardhat's keystore encrypts the values with a password you choose, outside the repository.

```bash
npx hardhat keystore set SEPOLIA_RPC_URL
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
npx hardhat keystore set ETHERSCAN_API_KEY
```

Use a wallet created for testing, and never your seed phrase. Never put these values in a tracked file.

### 2. Choose a deployment ID

Records of the live deployment are in `deployment/ignition/deployments/chain-11155111/`. Without a new ID, Ignition treats the token as already deployed and does nothing. Use `--deployment-id` to deploy a separate copy, and don't use `--reset`, which erases the records.

### 3. Deploy the token

The deploying account becomes the owner and receives the initial supply, which is set in [`Ponzi42.ts`](../deployment/ignition/modules/Ponzi42.ts).

```bash
npx hardhat ignition deploy ../deployment/ignition/modules/Ponzi42.ts \
  --network sepolia --build-profile production --verify --deployment-id my-copy
```

### 4. Deploy the multisig

Copy [`sepolia-multisig.json`](../deployment/ignition/parameters/sepolia-multisig.json) to a new file, and set your token's address, your signers and the required confirmations. Then run:

```bash
npx hardhat ignition deploy ../deployment/ignition/modules/Ponzi42Multisig.ts \
  --network sepolia --build-profile production --verify --deployment-id my-copy \
  --parameters <your parameters file>
```

Check the signers carefully, because they can't be changed afterwards.

### 5. Hand over ownership

1. On the token, the current owner calls `transferOwnership(<multisig address>)`.
2. On the multisig, a signer calls `submitTransaction(0x79ba5097)`, which is the encoded `acceptOwnership()`. The first transaction's ID is `0`.
3. A second signer calls `confirmTransaction(0)`.
4. A signer calls `executeTransaction(0)`.
5. On the token, check that `owner()` returns the multisig's address.

After step 4, the previous owner can no longer mint.

## Tool versions

| Tool | Version |
|---|---|
| Solidity compiler | 0.8.34, optimizer on with 200 runs |
| OpenZeppelin Contracts | 5.6 |
| Hardhat | 3.21 |
