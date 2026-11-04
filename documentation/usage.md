# Using the token

This guide is for anyone holding or sending PONZ. Minting and the multisig's own funds are covered in the [multisig guide](multisig.md).

## What you need

1. **A wallet that supports Sepolia**, such as Phantom in testnet mode or MetaMask. Never use a wallet that holds real funds for testing.
2. **A little Sepolia ETH** to pay for gas, which you can get from a Sepolia faucet. It has no monetary value.
3. **Some PONZ**, sent to you by a holder. There is no sale. Reading balances needs neither ETH nor PONZ.

## Add PONZ to your wallet

Switch your wallet to Sepolia, choose to add a custom token, and paste the token address:

```
0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9
```

The wallet should fill in the ticker `PONZ` and 18 decimals. If it shows anything else, check the address.

## Read and write through Etherscan

- [**Read Contract**](https://sepolia.etherscan.io/address/0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9#readContract) needs no wallet and costs nothing.
- [**Write Contract**](https://sepolia.etherscan.io/address/0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9#writeContract) needs you to connect your wallet with **Connect to Web3**, and each action costs gas.

## Amounts use base units

Contracts count in the smallest unit of the token. With 18 decimals, 1 PONZ is 1 followed by 18 zeros. Wallets convert this for you, but Etherscan's forms do not.

| PONZ | Value to enter on Etherscan |
|---|---|
| 1 | `1000000000000000000` |
| 42 | `42000000000000000000` |
| 0.5 | `500000000000000000` |

## Available functions

### Reading

| Function | Returns |
|---|---|
| `name()`, `symbol()`, `decimals()` | `42ponzi`, `PONZ`, `18` |
| `totalSupply()` | Tokens that exist now, in base units |
| `cap()` or `MAX_SUPPLY()` | The maximum supply, in base units |
| `balanceOf(account)` | The balance of `account` |
| `allowance(owner, spender)` | What `spender` may still spend from `owner` |
| `owner()` | The address allowed to mint, currently the multisig |
| `pendingOwner()` | The address proposed as next owner, or the zero address if there is none |

### Writing

| Function | Effect | Who can call it |
|---|---|---|
| `transfer(to, value)` | Sends your tokens to `to` | Anyone holding tokens |
| `approve(spender, value)` | Lets `spender` spend up to `value` of your tokens | Anyone |
| `transferFrom(from, to, value)` | Spends tokens that `from` approved for you | An approved spender |
| `mint(recipient, amount)` | Creates new tokens, up to the maximum | The owner only |
| `transferOwnership(newOwner)` | Proposes a new owner | The owner only |
| `acceptOwnership()` | Completes the ownership change | The proposed owner only |
| `renounceOwnership()` | Removes the owner, which disables minting forever | The owner only |

## Example: let someone spend your tokens

Suppose Alice wants Bob to be able to spend up to 10 PONZ of hers.

1. Alice calls `approve(<Bob's address>, 10000000000000000000)`.
2. Bob calls `transferFrom(<Alice's address>, <recipient>, 4000000000000000000)`, which sends 4 PONZ.
3. `allowance(<Alice's address>, <Bob's address>)` now returns the remaining 6 PONZ, in base units.

To cancel what is left, Alice calls `approve(<Bob's address>, 0)`.

## Common errors

Before you send a transaction that would fail, your wallet or Etherscan will usually warn you that it expects a failure.

| Error | Meaning |
|---|---|
| `ERC20InsufficientBalance` | You are sending more than you hold. |
| `ERC20InsufficientAllowance` | The spender is spending more than was approved. |
| `ERC20InvalidReceiver` | The recipient is the zero address. |
| `ERC20ExceededCap` | The mint would pass 42,000,000 PONZ. |
| `OwnableUnauthorizedAccount` | Your account is not allowed to call this function. |
