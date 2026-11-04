# Demonstration

This walkthrough shows the token working during an evaluation. It uses the live contracts on Sepolia, through Etherscan.

## Before you start

- Open the token's [Read](https://sepolia.etherscan.io/address/0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9#readContract) and [Write](https://sepolia.etherscan.io/address/0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9#writeContract) tabs.
- Open the multisig's [Read](https://sepolia.etherscan.io/address/0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF#readContract) and [Write](https://sepolia.etherscan.io/address/0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF#writeContract) tabs.
- Make sure your wallet has access to at least two signer accounts, with some Sepolia ETH on each.
- Run `npm ci` in `code/`, so that the encoding script works.

Steps 4 and 6 expect failures. Your wallet or Etherscan will normally warn you before sending, and that warning is the result to show. You don't need to force the transaction through, which would spend gas on a failure.

## 1. Show the deployed token

On the token's Read tab, check these values:

| Function | Expected |
|---|---|
| `name()` | `42ponzi` |
| `symbol()` | `PONZ` |
| `decimals()` | `18` |
| `cap()` | `42000000000000000000000000` |
| `owner()` | The multisig's address |

Then show that the source code is verified on the Contract tab, and that the signers are correct with `getSigners()` on the multisig.

## 2. Send tokens

From signer 1, which holds PONZ of its own, call `transfer(<another account>, 1000000000000000000)`. Then read `balanceOf` for both accounts to show the 1 PONZ has moved.

## 3. Approve a spender

1. From signer 1, call `approve(<signer 2>, 2000000000000000000)`, which allows 2 PONZ.
2. From signer 2, call `transferFrom(<signer 1>, <signer 2>, 1000000000000000000)`, which spends 1 PONZ.
3. Read `allowance(<signer 1>, <signer 2>)`, which now returns the remaining 1 PONZ.

## 4. Show that one key can't mint

From signer 1, call `mint(<signer 1>, 1000000000000000000)` directly on the token. It fails with `OwnableUnauthorizedAccount`, because only the multisig is the owner, even though this account deployed the token.

## 5. Mint through the multisig

1. Encode the call from the repository root:

   ```bash
   node deployment/scripts/encode-token-call.ts mint <recipient> 42
   ```

2. Read `getTransactionCount()` on the multisig, which gives the new transaction's ID.
3. From signer 1, call `submitTransaction(<data>)`.
4. Still from signer 1, try `executeTransaction(<id>)`. It fails with `NotEnoughConfirmations`, because one signer isn't enough.
5. From signer 2, call `confirmTransaction(<id>)`.
6. From either signer, call `executeTransaction(<id>)`.
7. Read `balanceOf(<recipient>)` and `totalSupply()` on the token. Both have grown by 42 PONZ.

## 6. Show that the maximum holds

1. Encode a mint that can't fit, since tokens already exist:

   ```bash
   node deployment/scripts/encode-token-call.ts mint <recipient> 42000000
   ```

2. From signer 1, submit it, then confirm it from signer 2.
3. Try to execute it. It fails with `ERC20ExceededCap`, even with enough confirmations.
4. Read `transactions(<id>)`, which shows it wasn't executed.
5. Clean up by calling `revokeConfirmation(<id>)` from both signers.

## 7. Spend the multisig's own tokens (optional)

Encode a transfer with the script, then follow the same submit, confirm and execute steps:

```bash
node deployment/scripts/encode-token-call.ts transfer <recipient> 100
```

## Run the tests

From `code/`, this shows every rule being checked locally, without spending gas:

```bash
npx hardhat test --coverage
```
