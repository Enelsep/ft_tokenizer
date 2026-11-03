// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Test} from "forge-std/Test.sol";
import {Ponzi42} from "./Ponzi42.sol";

contract Ponzi42Test is Test {
  uint256 constant ONE_TOKEN = 10 ** 18;
  uint256 constant MAX_SUPPLY = 42_000_000 * ONE_TOKEN;
  uint256 constant INITIAL_SUPPLY = 1_000_000 * ONE_TOKEN;

  address owner = makeAddr("owner");
  address alice = makeAddr("alice");
  address bob = makeAddr("bob");

  Ponzi42 token;

  function setUp() public {
    token = new Ponzi42(owner, INITIAL_SUPPLY);
  }

  // Token metadata

  function test_Metadata() public view {
    assertEq(token.name(), "42ponzi");
    assertEq(token.symbol(), "PONZ");
    assertEq(token.decimals(), 18);
  }

  function test_CapIs42Million() public view {
    assertEq(token.cap(), MAX_SUPPLY);
    assertEq(token.MAX_SUPPLY(), MAX_SUPPLY);
  }

  // Deployment

  function test_DeploymentSetsOwnerAndInitialSupply() public view {
    assertEq(token.owner(), owner);
    assertEq(token.totalSupply(), INITIAL_SUPPLY);
    assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
  }

  function test_DeploymentAcceptsZeroInitialSupply() public {
    Ponzi42 emptyToken = new Ponzi42(owner, 0);
    assertEq(emptyToken.totalSupply(), 0);
  }

  function test_DeploymentAcceptsInitialSupplyEqualToCap() public {
    Ponzi42 fullToken = new Ponzi42(owner, MAX_SUPPLY);
    assertEq(fullToken.totalSupply(), MAX_SUPPLY);
  }

  function test_DeploymentRevertsAboveCap() public {
    vm.expectRevert(
      abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, MAX_SUPPLY + 1, MAX_SUPPLY)
    );
    new Ponzi42(owner, MAX_SUPPLY + 1);
  }

  function test_DeploymentRevertsForZeroAddressOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new Ponzi42(address(0), INITIAL_SUPPLY);
  }

  // Transfers

  function test_TransferMovesTokens() public {
    vm.prank(owner);
    token.transfer(alice, ONE_TOKEN);

    assertEq(token.balanceOf(alice), ONE_TOKEN);
    assertEq(token.balanceOf(owner), INITIAL_SUPPLY - ONE_TOKEN);
    assertEq(token.totalSupply(), INITIAL_SUPPLY);
  }

  function test_TransferRevertsAboveBalance() public {
    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, ONE_TOKEN)
    );
    vm.prank(alice);
    token.transfer(bob, ONE_TOKEN);
  }

  function test_TransferRevertsToZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
    vm.prank(owner);
    token.transfer(address(0), ONE_TOKEN);
  }

  // Allowances

  function test_TransferFromSpendsAllowance() public {
    vm.prank(owner);
    token.approve(alice, 3 * ONE_TOKEN);

    vm.prank(alice);
    token.transferFrom(owner, bob, ONE_TOKEN);

    assertEq(token.balanceOf(bob), ONE_TOKEN);
    assertEq(token.allowance(owner, alice), 2 * ONE_TOKEN);
  }

  function test_TransferFromRevertsAboveAllowance() public {
    vm.prank(owner);
    token.approve(alice, ONE_TOKEN);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        alice,
        ONE_TOKEN,
        2 * ONE_TOKEN
      )
    );
    vm.prank(alice);
    token.transferFrom(owner, bob, 2 * ONE_TOKEN);
  }

  // The owner has no special power over other holders' tokens
  function test_OwnerCannotSpendWithoutAllowance() public {
    vm.prank(owner);
    token.transfer(alice, ONE_TOKEN);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        owner,
        0,
        ONE_TOKEN
      )
    );
    vm.prank(owner);
    token.transferFrom(alice, owner, ONE_TOKEN);
  }

  // Minting

  function test_OwnerCanMint() public {
    vm.prank(owner);
    token.mint(alice, ONE_TOKEN);

    assertEq(token.balanceOf(alice), ONE_TOKEN);
    assertEq(token.totalSupply(), INITIAL_SUPPLY + ONE_TOKEN);
  }

  function test_OwnerCanMintExactlyUpToCap() public {
    vm.prank(owner);
    token.mint(alice, MAX_SUPPLY - INITIAL_SUPPLY);

    assertEq(token.totalSupply(), MAX_SUPPLY);
  }

  function test_MintRevertsAboveCap() public {
    uint256 amountAboveCap = MAX_SUPPLY - INITIAL_SUPPLY + 1;

    vm.expectRevert(
      abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, MAX_SUPPLY + 1, MAX_SUPPLY)
    );
    vm.prank(owner);
    token.mint(alice, amountAboveCap);
  }

  function test_MintRevertsToZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
    vm.prank(owner);
    token.mint(address(0), ONE_TOKEN);
  }

  function testFuzz_NonOwnerCannotMint(address caller) public {
    vm.assume(caller != owner);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    token.mint(caller, ONE_TOKEN);
  }

  function testFuzz_SupplyNeverExceedsCap(uint256 amount) public {
    vm.prank(owner);
    try token.mint(alice, amount) {
      assertLe(token.totalSupply(), MAX_SUPPLY);
    } catch {
      assertGt(amount, MAX_SUPPLY - INITIAL_SUPPLY);
      assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }
  }

  // Two-step ownership

  function test_OwnershipTransferNeedsAcceptance() public {
    vm.prank(owner);
    token.transferOwnership(alice);

    assertEq(token.owner(), owner);
    assertEq(token.pendingOwner(), alice);

    vm.prank(alice);
    token.acceptOwnership();

    assertEq(token.owner(), alice);
    assertEq(token.pendingOwner(), address(0));
  }

  function test_PendingOwnerCannotMintBeforeAccepting() public {
    vm.prank(owner);
    token.transferOwnership(alice);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    token.mint(alice, ONE_TOKEN);
  }

  function test_OnlyPendingOwnerCanAccept() public {
    vm.prank(owner);
    token.transferOwnership(alice);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    vm.prank(bob);
    token.acceptOwnership();
  }

  function test_NonOwnerCannotStartOwnershipTransfer() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    token.transferOwnership(alice);
  }

  function test_MintRightsMoveWithOwnership() public {
    vm.prank(owner);
    token.transferOwnership(alice);
    vm.prank(alice);
    token.acceptOwnership();

    vm.prank(alice);
    token.mint(bob, ONE_TOKEN);
    assertEq(token.balanceOf(bob), ONE_TOKEN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
    vm.prank(owner);
    token.mint(owner, ONE_TOKEN);
  }

  function test_RenouncingOwnershipDisablesMinting() public {
    vm.prank(owner);
    token.renounceOwnership();

    assertEq(token.owner(), address(0));

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
    vm.prank(owner);
    token.mint(owner, ONE_TOKEN);
  }

  function test_NonOwnerCannotRenounceOwnership() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    token.renounceOwnership();
  }
}
