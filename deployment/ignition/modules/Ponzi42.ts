import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// 4,200,000 PONZ in base units (18 decimals), which is 10% of the cap
const INITIAL_SUPPLY = 4_200_000n * 10n ** 18n;

export default buildModule("Ponzi42Module", (m) => {
  // The deploying account owns the contract and receives the initial supply
  const initialOwner = m.getAccount(0);

  const token = m.contract("Ponzi42", [initialOwner, INITIAL_SUPPLY]);

  return { token };
});
