// Encodes a token call so that it can be proposed through the multisig.
// This script only prints data: it needs no private key and sends nothing to the network.
//
// Usage: node deployment/scripts/encode-token-call.ts <mint|transfer> <recipient> <amount in PONZ>
// Example: node deployment/scripts/encode-token-call.ts mint 0x0A781cca2691b57a86b6d36eB83e366d36F15e84 42.5

import { ethers } from "ethers";

const TOKEN_DECIMALS = 18;
const SUPPORTED_FUNCTIONS = ["mint", "transfer"];

const tokenInterface = new ethers.Interface([
  "function mint(address recipient, uint256 amount)",
  "function transfer(address to, uint256 value)",
]);

function exitWithError(message: string): never {
  console.error(`Error: ${message}`);
  console.error(
    "Usage: node deployment/scripts/encode-token-call.ts <mint|transfer> <recipient> <amount in PONZ>",
  );
  process.exit(1);
}

function parseRecipient(recipientInput: string): string {
  let recipient: string;
  try {
    recipient = ethers.getAddress(recipientInput);
  } catch {
    exitWithError(`"${recipientInput}" is not a valid address`);
  }
  // The token rejects the zero address, so this call could never be executed
  if (recipient === ethers.ZeroAddress) {
    exitWithError("the recipient cannot be the zero address");
  }
  return recipient;
}

function parseAmount(amountInput: string): bigint {
  let amount: bigint;
  try {
    amount = ethers.parseUnits(amountInput, TOKEN_DECIMALS);
  } catch {
    exitWithError(
      `"${amountInput}" is not a valid amount: use digits and at most one dot, with up to ${TOKEN_DECIMALS} decimals`,
    );
  }
  if (amount <= 0n) {
    exitWithError("the amount must be greater than zero");
  }
  if (amount > ethers.MaxUint256) {
    exitWithError("the amount is too large to encode");
  }
  return amount;
}

const [functionName, recipientInput, amountInput] = process.argv.slice(2);

if (amountInput === undefined) {
  exitWithError("expected a function name, a recipient and an amount");
}
if (!SUPPORTED_FUNCTIONS.includes(functionName)) {
  exitWithError(`unknown function "${functionName}"`);
}

const recipient = parseRecipient(recipientInput);
const amount = parseAmount(amountInput);
const data = tokenInterface.encodeFunctionData(functionName, [recipient, amount]);

console.log(`Call:        ${functionName}(${recipient}, ${amountInput} PONZ)`);
console.log(`Base units:  ${amount}`);
console.log(`Data:        ${data}`);
console.log("");
console.log("Pass the data to submitTransaction on the multisig.");
