# Security model

## Who can do what

| Action | Any holder | One signer | Two signers, through the multisig |
|---|---|---|---|
| Send or approve their own PONZ | Yes | Yes | Yes, for the multisig's PONZ |
| Mint up to the maximum | No | No | Yes |
| Change the token's owner | No | No | Yes |
| Renounce ownership, ending all minting | No | No | Yes |
| Propose or confirm a multisig transaction | No | Yes | Yes |
| Move someone else's tokens without their approval | No | No | No |
| Mint beyond 42,000,000 PONZ | No | No | No |
| Freeze an account or pause transfers | No | No | No |
| Upgrade or change the contract code | No | No | No |

## How each risk is handled

| Risk | Protection |
|---|---|
| One stolen or misused key mints tokens | The multisig owns the token. Execution needs 2 different signers, and the constructor rejects any setting below 2. |
| Ownership is sent to a mistyped address | `Ownable2Step`: the proposed owner must accept, so an address nobody controls can never take over. |
| The supply grows without limit | `ERC20Capped` enforces the maximum on every mint, and no function can change it. |
| One signer counts twice | Each signer can only confirm a transaction once. |
| A transaction runs twice | It is marked as executed before the token is called, and executed transactions are refused. |
| The multisig is used to call another contract | It can only ever call the token set at deployment. |
| ETH gets stuck in the contracts | Neither contract can receive ETH. |
| A bug in the basic token logic | The ERC-20 and ownership logic comes from OpenZeppelin Contracts rather than being rewritten. |
| Keys leak through the repository | Keys stay in Hardhat's encrypted keystore, and `.gitignore` excludes `.env` files, key files and seed phrase files. |

## Known limits

- **Key holders matter most.** Two signers acting together, or two stolen keys, can do anything in the right-hand column. If one person holds all three keys, the multisig demonstrates the mechanism but doesn't separate control. Real protection needs independent key holders.
- **Losing keys can freeze the multisig.** If two of the three keys are lost, nobody can mint or move the multisig's PONZ again.
- **Signers can't be changed in place.** Replacing one means [moving to a new multisig](multisig.md#replacing-a-signer).
- **Pending transactions don't expire.** A forgotten transaction with 2 confirmations can still be executed later, so signers should revoke the ones they no longer want.
- **Signers approve raw data.** They should [check it before confirming](multisig.md#4-check-before-you-confirm).
- **The contracts can't be upgraded.** A bug can't be patched in place. Fixing one would mean deploying new contracts.
- **The 200,000 PONZ in the deployer's wallet aren't protected by the multisig.** One key controls them, like any normal holder's tokens.
- **Normal ERC-20 transfers don't use the multisig.** Holders own their tokens, so it only protects owner actions and its own balance.
- **`approve` has a known ERC-20 weakness.** A spender who sees an allowance being changed can spend the old value first. To change a non-zero allowance safely, set it to 0, then set the new value.
- **The contracts have not had a professional audit.** They are tested as described in the [development guide](development.md), and they are meant for a testnet only.
