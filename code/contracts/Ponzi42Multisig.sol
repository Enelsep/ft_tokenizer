// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Ponzi42Multisig
 * @notice Multisignature wallet that owns the 42ponzi token and can hold PONZ.
 *
 * Any action on the token (minting, moving the wallet's PONZ, changing the
 * token's owner) must be submitted as a transaction, then confirmed by several
 * different signers before it can be executed.
 *
 * Transactions can only ever call the token, and the wallet cannot receive ETH.
 *
 * The signers and the number of confirmations are fixed at deployment. To replace
 * a signer, deploy a new multisig and transfer the token's ownership to it.
 */
contract Ponzi42Multisig {
  struct Transaction {
    /// @dev Encoded function call sent to the token, e.g. mint(recipient, amount).
    bytes data;
    uint256 confirmationCount;
    bool executed;
  }

  /// @notice The only contract this wallet can call.
  address public immutable token;

  /// @notice Number of different signers that must confirm a transaction before it can run.
  uint256 public immutable requiredConfirmations;

  /// @notice True for each address allowed to act on this wallet.
  mapping(address => bool) public isSigner;

  /// @notice Whether a signer currently confirms a transaction: transaction ID => signer => confirmed.
  mapping(uint256 => mapping(address => bool)) public hasConfirmed;

  /// @notice Every submitted transaction. A transaction's ID is its index in this list.
  Transaction[] public transactions;

  address[] private signers;

  event TransactionSubmitted(uint256 indexed transactionId, address indexed signer, bytes data);
  event TransactionConfirmed(uint256 indexed transactionId, address indexed signer);
  event ConfirmationRevoked(uint256 indexed transactionId, address indexed signer);
  event TransactionExecuted(uint256 indexed transactionId, address indexed signer);

  error TokenHasNoCode(address tokenAddress);
  error InvalidRequiredConfirmations(uint256 requiredConfirmations, uint256 signerCount);
  error InvalidSigner(address signer);
  error DuplicateSigner(address signer);
  error CallerIsNotSigner(address caller);
  error TransactionNotFound(uint256 transactionId);
  error TransactionAlreadyExecuted(uint256 transactionId);
  error AlreadyConfirmed(uint256 transactionId, address signer);
  error NotConfirmed(uint256 transactionId, address signer);
  error NotEnoughConfirmations(uint256 transactionId, uint256 confirmationCount, uint256 requiredConfirmations);

  modifier onlySigner() {
    if (!isSigner[msg.sender]) {
      revert CallerIsNotSigner(msg.sender);
    }
    _;
  }

  modifier onlyPending(uint256 transactionId) {
    if (transactionId >= transactions.length) {
      revert TransactionNotFound(transactionId);
    }
    if (transactions[transactionId].executed) {
      revert TransactionAlreadyExecuted(transactionId);
    }
    _;
  }

  /**
   * @param tokenAddress Token controlled by this wallet.
   * @param initialSigners Addresses allowed to act on this wallet, without duplicates.
   * @param confirmationsNeeded Confirmations needed per transaction, from 2 up to the number of signers.
   */
  constructor(address tokenAddress, address[] memory initialSigners, uint256 confirmationsNeeded) {
    if (tokenAddress.code.length == 0) {
      revert TokenHasNoCode(tokenAddress);
    }
    // Requiring at least 2 guarantees that one signer can never act alone
    if (confirmationsNeeded < 2 || confirmationsNeeded > initialSigners.length) {
      revert InvalidRequiredConfirmations(confirmationsNeeded, initialSigners.length);
    }

    for (uint256 i = 0; i < initialSigners.length; i++) {
      address signer = initialSigners[i];
      if (signer == address(0)) {
        revert InvalidSigner(signer);
      }
      if (isSigner[signer]) {
        revert DuplicateSigner(signer);
      }
      isSigner[signer] = true;
    }

    token = tokenAddress;
    requiredConfirmations = confirmationsNeeded;
    signers = initialSigners;
  }

  /**
   * @notice Proposes a call to the token. This also counts as the caller's confirmation.
   * @param data Encoded function call to send to the token.
   * @return transactionId ID to use when confirming, revoking or executing.
   */
  function submitTransaction(bytes calldata data) external onlySigner returns (uint256 transactionId) {
    transactionId = transactions.length;
    transactions.push(Transaction({data: data, confirmationCount: 0, executed: false}));
    emit TransactionSubmitted(transactionId, msg.sender, data);

    _confirm(transactionId);
  }

  /**
   * @notice Adds the caller's confirmation to a pending transaction.
   * @param transactionId Transaction to confirm.
   */
  function confirmTransaction(uint256 transactionId) external onlySigner onlyPending(transactionId) {
    _confirm(transactionId);
  }

  /**
   * @notice Withdraws the caller's confirmation from a pending transaction.
   * @dev Transactions never expire, so this is how signers cancel one they no longer want.
   * @param transactionId Transaction to withdraw the confirmation from.
   */
  function revokeConfirmation(uint256 transactionId) external onlySigner onlyPending(transactionId) {
    if (!hasConfirmed[transactionId][msg.sender]) {
      revert NotConfirmed(transactionId, msg.sender);
    }

    hasConfirmed[transactionId][msg.sender] = false;
    transactions[transactionId].confirmationCount -= 1;
    emit ConfirmationRevoked(transactionId, msg.sender);
  }

  /**
   * @notice Sends a sufficiently confirmed transaction to the token.
   * @dev If the token call fails, everything reverts with the token's error and the
   * transaction stays pending.
   * @param transactionId Transaction to execute.
   */
  function executeTransaction(uint256 transactionId) external onlySigner onlyPending(transactionId) {
    Transaction storage transaction = transactions[transactionId];
    if (transaction.confirmationCount < requiredConfirmations) {
      revert NotEnoughConfirmations(transactionId, transaction.confirmationCount, requiredConfirmations);
    }

    // Marked before the external call so that a transaction can never run twice
    transaction.executed = true;
    Address.functionCall(token, transaction.data);
    emit TransactionExecuted(transactionId, msg.sender);
  }

  /// @notice Returns every address allowed to act on this wallet.
  function getSigners() external view returns (address[] memory) {
    return signers;
  }

  /// @notice Returns the number of submitted transactions, which is also the next transaction ID.
  function getTransactionCount() external view returns (uint256) {
    return transactions.length;
  }

  /// @dev Records the caller's confirmation, rejecting a second one from the same signer.
  function _confirm(uint256 transactionId) private {
    if (hasConfirmed[transactionId][msg.sender]) {
      revert AlreadyConfirmed(transactionId, msg.sender);
    }

    hasConfirmed[transactionId][msg.sender] = true;
    transactions[transactionId].confirmationCount += 1;
    emit TransactionConfirmed(transactionId, msg.sender);
  }
}
