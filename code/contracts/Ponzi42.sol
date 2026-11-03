// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title 42ponzi (PONZ)
 * @notice ERC-20 token with a hard cap of 42,000,000 PONZ.
 *
 * Privileges: the owner can only mint new tokens, and only up to the cap.
 * Nobody can move, freeze or burn tokens belonging to another holder without
 * that holder's allowance.
 *
 * Ownership moves in two steps: the current owner proposes a new owner, who
 * must then accept. A mistyped address therefore cannot take over the contract.
 * If the owner calls renounceOwnership, minting is disabled permanently.
 */
contract Ponzi42 is ERC20Capped, Ownable2Step {
  /// @notice Maximum number of tokens that can ever exist, in base units (18 decimals).
  uint256 public constant MAX_SUPPLY = 42_000_000 * 10 ** 18;

  /**
   * @param initialOwner Address that owns the contract and receives the initial supply.
   * @param initialSupply Amount minted at deployment, in base units. Reverts if above MAX_SUPPLY.
   */
  constructor(
    address initialOwner,
    uint256 initialSupply
  ) ERC20("42ponzi", "PONZ") ERC20Capped(MAX_SUPPLY) Ownable(initialOwner) {
    _mint(initialOwner, initialSupply);
  }

  /**
   * @notice Creates new tokens. Only the owner can call this.
   * @dev ERC20Capped reverts with ERC20ExceededCap if the total supply would pass the cap.
   * @param recipient Address that receives the new tokens.
   * @param amount Amount to create, in base units.
   */
  function mint(address recipient, uint256 amount) external onlyOwner {
    _mint(recipient, amount);
  }
}
