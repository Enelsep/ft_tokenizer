import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// The values come from a parameters file, see ../parameters/sepolia-multisig.json
export default buildModule("Ponzi42MultisigModule", (m) => {
  const tokenAddress = m.getParameter("tokenAddress");
  const signers = m.getParameter("signers");
  const requiredConfirmations = m.getParameter("requiredConfirmations");

  const multisig = m.contract("Ponzi42Multisig", [
    tokenAddress,
    signers,
    requiredConfirmations,
  ]);

  return { multisig };
});
