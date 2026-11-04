# Multisig guide

`Ponzi42Multisig` owns the token, so minting and every other owner action must go through it. It also holds 4,000,000 PONZ, which can only move with the agreement of two signers.

| Setting | Value |
|---|---|
| Contract | [`0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF`](https://sepolia.etherscan.io/address/0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF) |
| Controls | The token at `0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9`, and nothing else |
| Confirmations required | 2 of 3 |
| Signer 1 (also the deployer) | `0x0A781cca2691b57a86b6d36eB83e366d36F15e84` |
| Signer 2 | `0x69cA0EbA47d3F3a39550C3D88Dd6465DF8e0c15e` |
| Signer 3 | `0x82e4b00F88310937905C316CFCC8E435F32B5990` |

## How a transaction works

```
 submitTransaction(data)         a signer proposes a call to the token
          |                      this counts as their confirmation (1 of 2)
          v
 confirmTransaction(id)          a different signer agrees (2 of 2)
          |
          v
 executeTransaction(id)          any signer sends the call to the token
```

- A signer can only confirm a transaction once, so one signer can never reach 2 alone.
- `revokeConfirmation(id)` withdraws a confirmation at any time before execution.
- An executed transaction can never run again.
- If the token rejects the call, for example because a mint passes the maximum, the execution fails and the transaction stays pending.
- Pending transactions never expire. To cancel one, signers revoke until fewer than 2 confirmations remain.

## Step by step

### 1. Encode the call

The multisig receives the token call as encoded data, which this script produces. Install the dependencies once with `npm ci` in `code/`, then run it from the repository root:

```bash
# Mint 42 PONZ to a recipient
node deployment/scripts/encode-token-call.ts mint <recipient> 42

# Send 100 PONZ from the multisig's own balance
node deployment/scripts/encode-token-call.ts transfer <recipient> 100
```

Amounts are in PONZ, not base units. The script prints the data and nothing else: it uses no private key and sends nothing to the network.

```
Call:        mint(0x0A781cca2691b57a86b6d36eB83e366d36F15e84, 42 PONZ)
Base units:  42000000000000000000
Data:        0x40c10f190000000000000000000000000a781cca2691b57a86b6d36eb83e366d36f15e8400000000000000000000000000000000000000000000000246ddf97976680000
```

### 2. Note the transaction ID

On the multisig's [Read Contract](https://sepolia.etherscan.io/address/0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF#readContract) tab, `getTransactionCount()` gives the ID your transaction will get. Check the event logs if two signers might submit at the same time.

### 3. Submit, confirm and execute

Use the [Write Contract](https://sepolia.etherscan.io/address/0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF#writeContract) tab, reconnecting your wallet with the right account for each step.

| Step | Account | Call |
|---|---|---|
| Submit | First signer | `submitTransaction(<data>)` |
| Confirm | A second signer | `confirmTransaction(<id>)` |
| Execute | Either of them, or the third signer | `executeTransaction(<id>)` |

### 4. Check before you confirm

Signers approve raw data, so check it before confirming. Read `transactions(<id>)`, run the script yourself with the recipient and amount you expect, and compare. The two `data` values must match exactly.

## Reading the multisig's state

| Function | Returns |
|---|---|
| `getSigners()` | All signers |
| `requiredConfirmations()` | The confirmations needed (2) |
| `token()` | The token this wallet controls |
| `getTransactionCount()` | The number of transactions submitted |
| `transactions(id)` | The data, the confirmation count, and whether it was executed |
| `hasConfirmed(id, signer)` | Whether that signer currently confirms it |
| `isSigner(account)` | Whether `account` is a signer |

## Replacing a signer

Signers are fixed at deployment. To replace one, including after a lost or stolen key:

1. Deploy a new multisig with the new signers, as described in the [development guide](development.md#deploy-your-own-copy).
2. Have the current signers execute `transferOwnership(<new multisig>)` on the token through the current multisig. The script doesn't encode this call, so you need to encode it separately.
3. Have the new signers execute `acceptOwnership()` through the new multisig, using the data `0x79ba5097`.
4. Have the old signers transfer the old multisig's PONZ to the new one.

## Errors

| Error | Meaning |
|---|---|
| `CallerIsNotSigner` | Your connected account is not a signer. |
| `NotEnoughConfirmations` | The transaction has fewer than 2 confirmations. |
| `AlreadyConfirmed` | You have already confirmed this transaction. |
| `NotConfirmed` | You have no confirmation to revoke. |
| `TransactionAlreadyExecuted` | This transaction has already run. |
| `TransactionNotFound` | No transaction has this ID. |

## On-chain record

How the live setup was created, in order:

| Step | Account | Transaction |
|---|---|---|
| Deploy the token | Signer 1 | [`0xff4d...0dbe`](https://sepolia.etherscan.io/tx/0xff4d7e66d09c40c1909f2bcae523390d6404485ba02d85db5e452b8935800dbe) |
| Deploy the multisig | Signer 1 | [`0x08e0...80c3`](https://sepolia.etherscan.io/tx/0x08e00b0459ed2c00f30eed3314da0fdf23d341fa1381eadeb99d86c48b0180c3) |
| Propose the multisig as token owner | Signer 1 | [`0x592b...e724`](https://sepolia.etherscan.io/tx/0x592b469347873cf922ff6d9f71216f73eb77a22d67f3093f5836ad608179e724) |
| Submit `acceptOwnership` (ID 0) | Signer 1 | [`0x8a04...e9ae`](https://sepolia.etherscan.io/tx/0x8a046fa3a28dc6da50a1a5ef48625bdd2727df9dbeff9ba023ee39e8d719e9ae) |
| Confirm it | Signer 2 | [`0x3393...a2ea`](https://sepolia.etherscan.io/tx/0x3393667b427d1e95c4f1543e5f03efae1fcc4a05f783b642ad5c200a601aa2ea) |
| Execute it, making the multisig the owner | Signer 2 | [`0xbe93...3259`](https://sepolia.etherscan.io/tx/0xbe93431565e2c60388b7cea8edb10adccc69ff370e3bbee3c43b204c45933259) |
| Move 4,000,000 PONZ to the multisig | Signer 1 | [`0x1569...c05e`](https://sepolia.etherscan.io/tx/0x1569861cbe6ce60e10abf02b180d01b8258b223d34dcfe5bd06b991d9bccc05e) |
