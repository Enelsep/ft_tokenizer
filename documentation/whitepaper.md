# Whitepaper

## What PONZ represents

PONZ represents nothing of value. It is a learning project that demonstrates the full life of a token: writing it, testing it, deploying it on a public blockchain, and protecting its privileged actions.

The name is a joke, chosen to contain the required `42`. It is not a Ponzi scheme, or an investment of any kind:

- It takes no deposits. Neither contract can receive ETH.
- It pays no returns, and it promises none.
- It only exists on Sepolia, whose test ETH has no monetary value.

## What it can be used for

- Practising wallet actions: adding a token, sending it, and approving a spender.
- Reading and writing contracts through a block explorer.
- Seeing how a multisig controls a token, from proposal to execution.

## Token details

| Property | Value |
|---|---|
| Name | `42ponzi` |
| Ticker | `PONZ` |
| Standard | ERC-20 |
| Decimals | 18 |
| Maximum supply | 42,000,000 PONZ, fixed in the contract |
| Minted at deployment | 4,200,000 PONZ (10% of the maximum) |
| Network | Ethereum Sepolia testnet (chain ID 11155111) |

## Supply

| Rule | Detail |
|---|---|
| New tokens | Only the token's owner can mint them, and the owner is the multisig. Each mint needs 2 of its 3 signers. |
| The limit | Minting beyond 42,000,000 PONZ always fails, and no function can raise that limit. |
| Burning | The token has no burn function, so the supply can only grow until it reaches the maximum. |

## Distribution

Balances on 4 November 2026. [Etherscan](https://sepolia.etherscan.io/token/0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9#balances) shows the current figures.

| Holder | PONZ | Share of current supply |
|---|---|---|
| Multisig (`0x9F4b...3adF`) | 4,000,000 | 95.2% |
| Deployer (`0x0A78...5e84`) | 200,000 | 4.8% |
| **Total minted** | **4,200,000** | **100%** |
| Not minted yet | 37,800,000 | - |

There is no sale. Tokens only move when a holder or an approved spender sends them, and new ones only appear when the multisig's signers approve a mint.

## Governance

Three signers control the multisig, and any action needs two of them. They can mint up to the maximum, spend the multisig's PONZ, and change the token's owner.

They cannot touch tokens held by anyone else, unless that holder has approved the multisig as a spender. They also cannot change the maximum supply, because the contracts are not upgradeable. See the [security model](security.md) for details.
