// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Test} from "forge-std/Test.sol";
import {Ponzi42} from "./Ponzi42.sol";
import {Ponzi42Multisig} from "./Ponzi42Multisig.sol";

contract Ponzi42MultisigTest is Test {
  uint256 constant ONE_TOKEN = 10 ** 18;
  uint256 constant MAX_SUPPLY = 42_000_000 * ONE_TOKEN;
  uint256 constant INITIAL_SUPPLY = 4_200_000 * ONE_TOKEN;
  uint256 constant REQUIRED_CONFIRMATIONS = 2;

  address deployer = makeAddr("deployer");
  address signerA = makeAddr("signerA");
  address signerB = makeAddr("signerB");
  address signerC = makeAddr("signerC");
  address outsider = makeAddr("outsider");
  address recipient = makeAddr("recipient");

  Ponzi42 token;
  Ponzi42Multisig multisig;
  bytes mintOneToken;

  function setUp() public {
    token = new Ponzi42(deployer, INITIAL_SUPPLY);
    multisig = new Ponzi42Multisig(address(token), _signers(signerA, signerB, signerC), REQUIRED_CONFIRMATIONS);
    mintOneToken = abi.encodeCall(Ponzi42.mint, (recipient, ONE_TOKEN));

    // Same handover as on the live network: the deployer proposes, the signers accept
    vm.prank(deployer);
    token.transferOwnership(address(multisig));
    uint256 acceptOwnership = _submit(signerA, abi.encodeCall(token.acceptOwnership, ()));
    _confirm(signerB, acceptOwnership);
    _execute(signerA, acceptOwnership);
  }

  // Deployment

  function test_DeploymentStoresConfiguration() public view {
    assertEq(multisig.token(), address(token));
    assertEq(multisig.requiredConfirmations(), REQUIRED_CONFIRMATIONS);
    assertEq(multisig.getSigners().length, 3);
    assertTrue(multisig.isSigner(signerA));
    assertTrue(multisig.isSigner(signerB));
    assertTrue(multisig.isSigner(signerC));
    assertFalse(multisig.isSigner(outsider));
  }

  function test_DeploymentRevertsWhenTokenHasNoCode() public {
    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.TokenHasNoCode.selector, outsider));
    new Ponzi42Multisig(outsider, _signers(signerA, signerB, signerC), REQUIRED_CONFIRMATIONS);
  }

  function test_DeploymentRevertsWithoutSigners() public {
    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.InvalidRequiredConfirmations.selector, 2, 0));
    new Ponzi42Multisig(address(token), new address[](0), 2);
  }

  function testFuzz_DeploymentRevertsBelowTwoConfirmations(uint256 confirmationsNeeded) public {
    confirmationsNeeded = bound(confirmationsNeeded, 0, 1);

    vm.expectRevert(
      abi.encodeWithSelector(Ponzi42Multisig.InvalidRequiredConfirmations.selector, confirmationsNeeded, 3)
    );
    new Ponzi42Multisig(address(token), _signers(signerA, signerB, signerC), confirmationsNeeded);
  }

  function testFuzz_DeploymentRevertsAboveSignerCount(uint256 confirmationsNeeded) public {
    confirmationsNeeded = bound(confirmationsNeeded, 4, type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(Ponzi42Multisig.InvalidRequiredConfirmations.selector, confirmationsNeeded, 3)
    );
    new Ponzi42Multisig(address(token), _signers(signerA, signerB, signerC), confirmationsNeeded);
  }

  function test_DeploymentAcceptsAllSignersRequired() public {
    Ponzi42Multisig unanimous = new Ponzi42Multisig(address(token), _signers(signerA, signerB, signerC), 3);
    assertEq(unanimous.requiredConfirmations(), 3);
  }

  function test_DeploymentRevertsForZeroAddressSigner() public {
    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.InvalidSigner.selector, address(0)));
    new Ponzi42Multisig(address(token), _signers(signerA, address(0), signerC), REQUIRED_CONFIRMATIONS);
  }

  function test_DeploymentRevertsForDuplicateSigner() public {
    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.DuplicateSigner.selector, signerA));
    new Ponzi42Multisig(address(token), _signers(signerA, signerB, signerA), REQUIRED_CONFIRMATIONS);
  }

  // Taking over the token

  function test_MultisigOwnsTheToken() public view {
    assertEq(token.owner(), address(multisig));
    assertEq(token.pendingOwner(), address(0));
  }

  function test_PreviousOwnerLosesMintRights() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, deployer));
    vm.prank(deployer);
    token.mint(deployer, ONE_TOKEN);
  }

  function testFuzz_SignerCannotBypassMultisigToMint(uint256 signerIndex) public {
    address signer = _signers(signerA, signerB, signerC)[bound(signerIndex, 0, 2)];

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, signer));
    vm.prank(signer);
    token.mint(signer, ONE_TOKEN);
  }

  function test_OwnershipTakeoverNeedsTwoConfirmations() public {
    Ponzi42 otherToken = new Ponzi42(deployer, 0);
    Ponzi42Multisig otherMultisig = new Ponzi42Multisig(
      address(otherToken),
      _signers(signerA, signerB, signerC),
      REQUIRED_CONFIRMATIONS
    );
    vm.prank(deployer);
    otherToken.transferOwnership(address(otherMultisig));

    vm.prank(signerA);
    uint256 transactionId = otherMultisig.submitTransaction(abi.encodeCall(token.acceptOwnership, ()));

    vm.expectRevert(
      abi.encodeWithSelector(Ponzi42Multisig.NotEnoughConfirmations.selector, transactionId, 1, REQUIRED_CONFIRMATIONS)
    );
    vm.prank(signerA);
    otherMultisig.executeTransaction(transactionId);

    assertEq(otherToken.owner(), deployer);
  }

  // Submitting

  function test_SubmitStoresTransactionAndCountsAsConfirmation() public {
    uint256 countBefore = multisig.getTransactionCount();

    uint256 transactionId = _submit(signerA, mintOneToken);

    assertEq(transactionId, countBefore);
    assertEq(multisig.getTransactionCount(), countBefore + 1);
    assertTrue(multisig.hasConfirmed(transactionId, signerA));

    (bytes memory data, uint256 confirmationCount, bool executed) = multisig.transactions(transactionId);
    assertEq(data, mintOneToken);
    assertEq(confirmationCount, 1);
    assertFalse(executed);
  }

  function test_SubmitAloneDoesNotChangeTheToken() public {
    _submit(signerA, mintOneToken);

    assertEq(token.balanceOf(recipient), 0);
    assertEq(token.totalSupply(), INITIAL_SUPPLY);
  }

  function test_SubmitEmitsEvents() public {
    uint256 transactionId = multisig.getTransactionCount();

    vm.expectEmit();
    emit Ponzi42Multisig.TransactionSubmitted(transactionId, signerA, mintOneToken);
    vm.expectEmit();
    emit Ponzi42Multisig.TransactionConfirmed(transactionId, signerA);
    _submit(signerA, mintOneToken);
  }

  // Confirming

  function test_ConfirmIncreasesCount() public {
    uint256 transactionId = _submit(signerA, mintOneToken);

    _confirm(signerB, transactionId);

    assertTrue(multisig.hasConfirmed(transactionId, signerB));
    assertEq(_confirmationCount(transactionId), 2);
  }

  function test_SignerCannotConfirmTwice() public {
    uint256 transactionId = _submit(signerA, mintOneToken);

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.AlreadyConfirmed.selector, transactionId, signerA));
    vm.prank(signerA);
    multisig.confirmTransaction(transactionId);

    assertEq(_confirmationCount(transactionId), 1);
  }

  function test_ConfirmRevertsForUnknownTransaction() public {
    uint256 unknownId = multisig.getTransactionCount();

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.TransactionNotFound.selector, unknownId));
    vm.prank(signerA);
    multisig.confirmTransaction(unknownId);
  }

  // Revoking

  function test_RevokeWithdrawsConfirmation() public {
    uint256 transactionId = _submit(signerA, mintOneToken);
    _confirm(signerB, transactionId);

    vm.prank(signerB);
    multisig.revokeConfirmation(transactionId);

    assertFalse(multisig.hasConfirmed(transactionId, signerB));
    assertEq(_confirmationCount(transactionId), 1);
  }

  function test_RevokedTransactionCannotExecute() public {
    uint256 transactionId = _submit(signerA, mintOneToken);
    _confirm(signerB, transactionId);
    vm.prank(signerB);
    multisig.revokeConfirmation(transactionId);

    vm.expectRevert(
      abi.encodeWithSelector(Ponzi42Multisig.NotEnoughConfirmations.selector, transactionId, 1, REQUIRED_CONFIRMATIONS)
    );
    vm.prank(signerA);
    multisig.executeTransaction(transactionId);
  }

  function test_SignerCanConfirmAgainAfterRevoking() public {
    uint256 transactionId = _submit(signerA, mintOneToken);
    vm.startPrank(signerA);
    multisig.revokeConfirmation(transactionId);
    multisig.confirmTransaction(transactionId);
    vm.stopPrank();

    assertEq(_confirmationCount(transactionId), 1);
  }

  function test_CannotRevokeWithoutConfirming() public {
    uint256 transactionId = _submit(signerA, mintOneToken);

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.NotConfirmed.selector, transactionId, signerB));
    vm.prank(signerB);
    multisig.revokeConfirmation(transactionId);
  }

  function test_RevokeRevertsForUnknownTransaction() public {
    uint256 unknownId = multisig.getTransactionCount();

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.TransactionNotFound.selector, unknownId));
    vm.prank(signerA);
    multisig.revokeConfirmation(unknownId);
  }

  // Executing

  function test_ExecuteMintsOnceEnoughSignersConfirmed() public {
    uint256 transactionId = _submit(signerA, mintOneToken);
    _confirm(signerC, transactionId);

    vm.expectEmit();
    emit Ponzi42Multisig.TransactionExecuted(transactionId, signerB);
    _execute(signerB, transactionId);

    assertEq(token.balanceOf(recipient), ONE_TOKEN);
    (, , bool executed) = multisig.transactions(transactionId);
    assertTrue(executed);
  }

  function test_ExecuteRevertsWithOneConfirmation() public {
    uint256 transactionId = _submit(signerA, mintOneToken);

    vm.expectRevert(
      abi.encodeWithSelector(Ponzi42Multisig.NotEnoughConfirmations.selector, transactionId, 1, REQUIRED_CONFIRMATIONS)
    );
    vm.prank(signerA);
    multisig.executeTransaction(transactionId);

    assertEq(token.balanceOf(recipient), 0);
  }

  function test_ExecuteRevertsForUnknownTransaction() public {
    uint256 unknownId = multisig.getTransactionCount();

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.TransactionNotFound.selector, unknownId));
    vm.prank(signerA);
    multisig.executeTransaction(unknownId);
  }

  function test_ExecutedTransactionCannotRunAgain() public {
    uint256 transactionId = _submit(signerA, mintOneToken);
    _confirm(signerB, transactionId);
    _execute(signerA, transactionId);

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.TransactionAlreadyExecuted.selector, transactionId));
    vm.prank(signerA);
    multisig.executeTransaction(transactionId);

    assertEq(token.balanceOf(recipient), ONE_TOKEN);
  }

  function test_ExecutedTransactionCannotBeConfirmedOrRevoked() public {
    uint256 transactionId = _submit(signerA, mintOneToken);
    _confirm(signerB, transactionId);
    _execute(signerA, transactionId);

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.TransactionAlreadyExecuted.selector, transactionId));
    vm.prank(signerC);
    multisig.confirmTransaction(transactionId);

    vm.expectRevert(abi.encodeWithSelector(Ponzi42Multisig.TransactionAlreadyExecuted.selector, transactionId));
    vm.prank(signerA);
    multisig.revokeConfirmation(transactionId);
  }

  // The token's cap still applies, and a failed call leaves the transaction pending
  function test_FailedCallRevertsWithTokenErrorAndStaysPending() public {
    uint256 tooMuch = MAX_SUPPLY - INITIAL_SUPPLY + 1;
    uint256 transactionId = _submit(signerA, abi.encodeCall(Ponzi42.mint, (recipient, tooMuch)));
    _confirm(signerB, transactionId);

    vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, MAX_SUPPLY + 1, MAX_SUPPLY));
    vm.prank(signerA);
    multisig.executeTransaction(transactionId);

    (, uint256 confirmationCount, bool executed) = multisig.transactions(transactionId);
    assertFalse(executed);
    assertEq(confirmationCount, 2);
    assertEq(token.totalSupply(), INITIAL_SUPPLY);
  }

  // Using the multisig for the token's privileged actions

  function test_MultisigCanMoveItsOwnTokens() public {
    vm.prank(deployer);
    token.transfer(address(multisig), ONE_TOKEN);

    uint256 transactionId = _submit(signerA, abi.encodeCall(token.transfer, (recipient, ONE_TOKEN)));
    _confirm(signerB, transactionId);
    _execute(signerA, transactionId);

    assertEq(token.balanceOf(recipient), ONE_TOKEN);
    assertEq(token.balanceOf(address(multisig)), 0);
  }

  // Replacing signers: ownership moves to a new multisig, which accepts it with its own signers
  function test_OwnershipCanMigrateToNewMultisig() public {
    address signerD = makeAddr("signerD");
    Ponzi42Multisig newMultisig = new Ponzi42Multisig(
      address(token),
      _signers(signerA, signerB, signerD),
      REQUIRED_CONFIRMATIONS
    );

    uint256 transferId = _submit(signerA, abi.encodeCall(token.transferOwnership, (address(newMultisig))));
    _confirm(signerB, transferId);
    _execute(signerA, transferId);
    assertEq(token.owner(), address(multisig));
    assertEq(token.pendingOwner(), address(newMultisig));

    vm.prank(signerA);
    uint256 acceptId = newMultisig.submitTransaction(abi.encodeCall(token.acceptOwnership, ()));
    vm.prank(signerD);
    newMultisig.confirmTransaction(acceptId);
    vm.prank(signerD);
    newMultisig.executeTransaction(acceptId);

    assertEq(token.owner(), address(newMultisig));
  }

  // Access control

  function testFuzz_NonSignerCannotUseWallet(address caller) public {
    vm.assume(caller != signerA && caller != signerB && caller != signerC);
    uint256 transactionId = _submit(signerA, mintOneToken);
    _confirm(signerB, transactionId);
    bytes memory notSigner = abi.encodeWithSelector(Ponzi42Multisig.CallerIsNotSigner.selector, caller);

    vm.startPrank(caller);
    vm.expectRevert(notSigner);
    multisig.submitTransaction(mintOneToken);
    vm.expectRevert(notSigner);
    multisig.confirmTransaction(transactionId);
    vm.expectRevert(notSigner);
    multisig.revokeConfirmation(transactionId);
    vm.expectRevert(notSigner);
    multisig.executeTransaction(transactionId);
    vm.stopPrank();
  }

  function test_WalletRejectsEth() public {
    vm.deal(outsider, 1 ether);

    vm.prank(outsider);
    (bool success, ) = address(multisig).call{value: 1 ether}("");

    assertFalse(success);
    assertEq(address(multisig).balance, 0);
  }

  // Helpers

  function _signers(address first, address second, address third) private pure returns (address[] memory signers) {
    signers = new address[](3);
    signers[0] = first;
    signers[1] = second;
    signers[2] = third;
  }

  function _submit(address signer, bytes memory data) private returns (uint256) {
    vm.prank(signer);
    return multisig.submitTransaction(data);
  }

  function _confirm(address signer, uint256 transactionId) private {
    vm.prank(signer);
    multisig.confirmTransaction(transactionId);
  }

  function _execute(address signer, uint256 transactionId) private {
    vm.prank(signer);
    multisig.executeTransaction(transactionId);
  }

  function _confirmationCount(uint256 transactionId) private view returns (uint256 confirmationCount) {
    (, confirmationCount, ) = multisig.transactions(transactionId);
  }
}
