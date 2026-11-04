# 42ponzi (PONZ)

An ERC-20 token on the Ethereum Sepolia testnet, built for the 42 Tokenizer project. A 2-of-3 multisig wallet owns it, so no single key can mint tokens.

**PONZ has no monetary value.** It exists only on a testnet. The name is a joke: the project takes no deposits, pays no returns, and is not an investment.

## Deployment

| | |
|---|---|
| **Network** | Ethereum Sepolia testnet (chain ID 11155111) |
| **Token contract** | [`0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9`](https://sepolia.etherscan.io/address/0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9) |
| **Multisig contract** | [`0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF`](https://sepolia.etherscan.io/address/0x9F4b2d9d53Fe2DFC00F13cDc54A2208f770b3adF) |
| **Token on Etherscan** | [sepolia.etherscan.io/token/0x7466...A8E9](https://sepolia.etherscan.io/token/0x74660A13c625d6d6AAcD9D0DB5FfB3E96afFA8E9) |

The source code of both contracts is verified on Etherscan.

## The token

| Property | Value |
|---|---|
| Name | `42ponzi` |
| Ticker | `PONZ` |
| Standard | ERC-20 |
| Decimals | 18 |
| Maximum supply | 42,000,000 PONZ |
| Minted at deployment | 4,200,000 PONZ |
| Owner | The multisig (2 of 3 signers) |

## Choices and reasons

### Blockchain and tools

| Choice | Reason | Alternatives considered |
|---|---|---|
| **Ethereum** | It has the most widely used token standard, and plenty of tools and documentation to learn from. | BSC works the same way but has a smaller testing ecosystem. Solana uses a different programming model and no ERC-20. |
| **Sepolia testnet** | The subject forbids spending real money. Sepolia is an actively maintained Ethereum testnet, with free test ETH and full Etherscan support. | Ethereum mainnet would cost real money. |
| **Solidity** | It is the main language for Ethereum contracts, and the one OpenZeppelin is written in. | Vyper has fewer libraries and learning resources. |
| **ERC-20** | The subject requires following the chain's standard. It also makes PONZ work with wallets and explorers without extra setup. | - |
| **OpenZeppelin Contracts** | Token and ownership logic is easy to get subtly wrong, so this project reuses widely audited code instead of rewriting it. | Writing ERC-20 by hand would add risk with no benefit. |
| **Hardhat 3** | It is named in the subject and supports tests in Solidity. Ignition keeps a record of each deployment, and the keystore encrypts private keys. | Foundry was not installed, while the Node tools were. Remix makes tests and repeatable deployments harder. |

### Token design

| Choice | Reason |
|---|---|
| **Name `42ponzi`, ticker `PONZ`** | The subject requires `42` in the name. The joke makes it hard to mistake this for a serious investment. |
| **18 decimals** | This is the ERC-20 convention, so wallets and tools display amounts correctly. |
| **Hard cap of 42,000,000** (`ERC20Capped`) | Holders can read the limit in the contract and know that no owner can ever pass it. |
| **4,200,000 minted at deployment** | This is 10% of the cap, which is enough to use while leaving room to demonstrate minting. |
| **Owner can only mint** | Fewer privileges mean less to trust. The owner can't freeze accounts, pause transfers, or take anyone's tokens. |
| **Two-step ownership** (`Ownable2Step`) | The new owner must accept, so a mistyped address can't lose the contract. It also let the multisig take over without redeploying the token. |
| **No upgrades** | Holders can trust that the published code stays as it is. The cost is that a bug can't be patched in place. |

### Bonus: multisig design

| Choice | Reason |
|---|---|
| **The multisig owns the token** | Every privileged action now needs several signers, which adapts the bonus to the token itself. |
| **2 of 3 signers** | One stolen key can't act alone, and one lost key doesn't freeze the wallet. |
| **At least 2 confirmations, enforced at deployment** | The contract can't be set up as a single-signer wallet by mistake. |
| **Written as its own small contract** | The subject asks for a smart contract with required signatures, and writing it makes it possible to explain every line. |
| **Calls can only go to the token** | Even two compromised signers can't use it to call other contracts. |
| **Holds PONZ, and rejects ETH** | Most of the supply gets multisig protection, and no ETH can get stuck in it. |
| **Fixed signers** | Replacing signers means moving ownership to a new multisig, which needs far less code than add and remove logic, and so less risk. |

**What the multisig doesn't cover:** normal transfers between holders, because ERC-20 balances belong to their holders. It protects owner actions and its own balance. The limits are listed in the [security model](documentation/security.md).

## Repository

```
.
├── README.md
├── code/                 Contracts, tests and Hardhat configuration
│   └── contracts/
│       ├── Ponzi42.sol             The token
│       ├── Ponzi42Multisig.sol     The multisig
│       └── *.t.sol                 Tests
├── deployment/
│   ├── ignition/         Deployment modules, parameters and on-chain records
│   └── scripts/          Script that encodes mint and transfer calls
└── documentation/        Whitepaper, guides and security model
```

## Quick start

```bash
cd code
npm ci
npx hardhat test
```

Using the live token only needs a wallet on Sepolia, as described in the [usage guide](documentation/usage.md).

## Documentation

- [Whitepaper](documentation/whitepaper.md): what the token is and how its supply works
- [Using the token](documentation/usage.md): holding, sending and approving PONZ
- [Multisig guide](documentation/multisig.md): minting and spending as a signer
- [Security model](documentation/security.md): who can do what, and the known limits
- [Development guide](documentation/development.md): building, testing and deploying
- [Demonstration](documentation/demo.md): showing the project working during an evaluation
