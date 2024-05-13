// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

/* solhint-disable private-vars-leading-underscore  */
/* solhint-disable var-name-mixedcase  */
/* solhint-disable func-name-mixedcase  */

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import "../../../contracts/AvUSD.sol";
import "../../../contracts/StakedAvUSDV2.sol";
import "../../../contracts/interfaces/IAvUSD.sol";
import "../../../contracts/interfaces/IERC20Events.sol";

contract StakedAvUSDV2CooldownBlacklistTest is Test, IERC20Events {
  AvUSD public avusdToken;
  StakedAvUSDV2 public stakedAvUSD;
  SigUtils public sigUtilsAvUSD;
  SigUtils public sigUtilsStakedAvUSD;
  uint256 public _amount = 100 ether;

  address public owner;
  address public alice;
  address public bob;
  address public greg;

  bytes32 SOFT_RESTRICTED_STAKER_ROLE;
  bytes32 FULL_RESTRICTED_STAKER_ROLE;
  bytes32 DEFAULT_ADMIN_ROLE;
  bytes32 BLACKLIST_MANAGER_ROLE;
  bytes32 REWARDER_ROLE;

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event LockedAmountRedistributed(address indexed from, address indexed to, uint256 amountToDistribute);

  function setUp() public virtual {
    avusdToken = new AvUSD(address(this));

    alice = makeAddr("alice");
    bob = makeAddr("bob");
    greg = makeAddr("greg");
    owner = makeAddr("owner");

    avusdToken.setMinter(address(this));

    vm.startPrank(owner);
    stakedAvUSD = new StakedAvUSDV2(IAvUSD(address(avusdToken)), makeAddr('rewarder'), owner);
    vm.stopPrank();

    FULL_RESTRICTED_STAKER_ROLE = keccak256("FULL_RESTRICTED_STAKER_ROLE");
    SOFT_RESTRICTED_STAKER_ROLE = keccak256("SOFT_RESTRICTED_STAKER_ROLE");
    DEFAULT_ADMIN_ROLE = 0x00;
    BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
    REWARDER_ROLE = keccak256("REWARDER_ROLE");
  }

  function _mintApproveDeposit(address staker, uint256 amount, bool expectRevert) internal {
    avusdToken.mint(staker, amount);

    vm.startPrank(staker);
    avusdToken.approve(address(stakedAvUSD), amount);

    uint256 sharesBefore = stakedAvUSD.balanceOf(staker);
    if (expectRevert) {
      vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    } else {
      vm.expectEmit(true, true, true, false);
      emit Deposit(staker, staker, amount, amount);
    }
    stakedAvUSD.deposit(amount, staker);
    uint256 sharesAfter = stakedAvUSD.balanceOf(staker);
    if (expectRevert) {
      assertEq(sharesAfter, sharesBefore);
    } else {
      assertApproxEqAbs(sharesAfter - sharesBefore, amount, 1);
    }
    vm.stopPrank();
  }

  function _redeem(address staker, uint256 amount, bool expectRevert) internal {
    uint256 balBefore = avusdToken.balanceOf(staker);

    vm.startPrank(staker);

    if (expectRevert) {
      vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    } else {}

    stakedAvUSD.cooldownAssets(amount);
    (uint104 cooldownEnd, uint256 assetsOut) = stakedAvUSD.cooldowns(staker);

    vm.warp(cooldownEnd + 1);

    stakedAvUSD.unstake(staker);
    vm.stopPrank();

    uint256 balAfter = avusdToken.balanceOf(staker);

    if (expectRevert) {
      assertEq(balBefore, balAfter);
    } else {
      assertApproxEqAbs(assetsOut, balAfter - balBefore, 1);
    }
  }

  function testStakeFlowCommonUser() public {
    _mintApproveDeposit(greg, _amount, false);

    assertEq(avusdToken.balanceOf(greg), 0);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), _amount);
    assertEq(stakedAvUSD.balanceOf(greg), _amount);

    _redeem(greg, _amount, false);

    assertEq(avusdToken.balanceOf(greg), _amount);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), 0);
    assertEq(stakedAvUSD.balanceOf(greg), 0);
  }

  /**
   * Soft blacklist: mints not allowed. Burns or transfers are allowed
   */
  function test_softBlacklist_deposit_reverts() public {
    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _mintApproveDeposit(alice, _amount, true);
  }

  function test_softBlacklist_withdraw_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount, false);
  }

  function test_softBlacklist_transfer_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedAvUSD.transfer(bob, _amount);
  }

  function test_softBlacklist_transferFrom_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedAvUSD.approve(bob, _amount);

    vm.prank(bob);
    stakedAvUSD.transferFrom(alice, bob, _amount);
  }

  /**
   * Full blacklist: mints, burns or transfers are not allowed
   */

  function test_fullBlacklist_deposit_reverts() public {
    // Alice full blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _mintApproveDeposit(alice, _amount, true);
  }

  function test_fullBlacklist_withdraw_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount, true);
  }

  function test_fullBlacklist_transfer_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    vm.prank(alice);
    stakedAvUSD.transfer(bob, _amount);
  }

  function test_fullBlacklist_transferFrom_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedAvUSD.approve(bob, _amount);

    vm.prank(bob);

    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    stakedAvUSD.transferFrom(alice, bob, _amount);
  }

  function test_fullBlacklist_can_not_be_transfer_recipient() public {
    _mintApproveDeposit(alice, _amount, false);
    _mintApproveDeposit(bob, _amount, false);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    vm.prank(bob);
    stakedAvUSD.transfer(alice, _amount);
  }

  function test_fullBlacklist_user_can_not_burn_and_donate_to_vault() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(bytes("ERC20: transfer to the zero address"));
    vm.prank(alice);
    stakedAvUSD.transfer(address(0), _amount);
  }

  /**
   * Soft and Full blacklist: mints, burns or transfers are not allowed
   */
  function test_softFullBlacklist_deposit_reverts() public {
    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _mintApproveDeposit(alice, _amount, true);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();
    _mintApproveDeposit(alice, _amount, true);
  }

  function test_softFullBlacklist_withdraw_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount / 3, false);

    // Alice full blacklisted
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    _redeem(alice, _amount / 3, true);
  }

  function test_softFullBlacklist_transfer_pass() public {
    _mintApproveDeposit(alice, _amount, false);

    // Alice soft blacklisted can transfer
    vm.startPrank(owner);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.prank(alice);
    stakedAvUSD.transfer(bob, _amount / 3);

    // Alice full blacklisted cannot transfer
    vm.startPrank(owner);
    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.stopPrank();

    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    vm.prank(alice);
    stakedAvUSD.transfer(bob, _amount / 3);
  }

  /**
   * redistributeLockedAmount
   */

  function test_redistributeLockedAmount() public {
    _mintApproveDeposit(alice, _amount, false);
    uint256 aliceStakedBalance = stakedAvUSD.balanceOf(alice);
    uint256 previousTotalSupply = stakedAvUSD.totalSupply();
    assertEq(aliceStakedBalance, _amount);

    vm.startPrank(owner);

    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);

    vm.expectEmit(true, true, true, true);
    emit LockedAmountRedistributed(alice, bob, _amount);

    stakedAvUSD.redistributeLockedAmount(alice, bob);

    vm.stopPrank();

    assertEq(stakedAvUSD.balanceOf(alice), 0);
    assertEq(stakedAvUSD.balanceOf(bob), _amount);
    assertEq(stakedAvUSD.totalSupply(), previousTotalSupply);
  }

  function testCanBurnOnRedistribute() public {
    _mintApproveDeposit(alice, _amount, false);
    uint256 aliceStakedBalance = stakedAvUSD.balanceOf(alice);
    uint256 previousTotalSupply = stakedAvUSD.totalSupply();
    assertEq(aliceStakedBalance, _amount);

    vm.startPrank(owner);

    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);

    stakedAvUSD.redistributeLockedAmount(alice, address(0));

    vm.stopPrank();

    assertEq(stakedAvUSD.balanceOf(alice), 0);
    assertEq(stakedAvUSD.totalSupply(), previousTotalSupply - _amount);
  }

  /**
   * Access control
   */
  function test_renounce_reverts() public {
    vm.startPrank(owner);

    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    vm.expectRevert();
    stakedAvUSD.renounceRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.expectRevert();
    stakedAvUSD.renounceRole(SOFT_RESTRICTED_STAKER_ROLE, alice);
  }

  function test_grant_role() public {
    vm.startPrank(owner);

    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    assertEq(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);
  }

  function test_revoke_role() public {
    vm.startPrank(owner);

    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    assertEq(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);

    stakedAvUSD.revokeRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedAvUSD.revokeRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    assertEq(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), false);
    assertEq(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), false);

    vm.stopPrank();
  }

  function test_revoke_role_by_other_reverts() public {
    vm.startPrank(owner);

    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    vm.startPrank(bob);

    vm.expectRevert();
    stakedAvUSD.revokeRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.expectRevert();
    stakedAvUSD.revokeRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    assertEq(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);
  }

  function test_revoke_role_by_myself_reverts() public {
    vm.startPrank(owner);

    stakedAvUSD.grantRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    stakedAvUSD.grantRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    vm.startPrank(alice);

    vm.expectRevert();
    stakedAvUSD.revokeRole(FULL_RESTRICTED_STAKER_ROLE, alice);
    vm.expectRevert();
    stakedAvUSD.revokeRole(SOFT_RESTRICTED_STAKER_ROLE, alice);

    vm.stopPrank();

    assertEq(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice), true);
    assertEq(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, alice), true);
  }

  function testAdminCannotRenounce() public {
    vm.startPrank(owner);

    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    stakedAvUSD.renounceRole(DEFAULT_ADMIN_ROLE, owner);

    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    stakedAvUSD.revokeRole(DEFAULT_ADMIN_ROLE, owner);

    vm.stopPrank();

    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertEq(stakedAvUSD.owner(), owner);
  }

  function testBlacklistManagerCanBlacklist() public {
    vm.prank(owner);
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.startPrank(alice);
    stakedAvUSD.addToBlacklist(bob, true);
    assertTrue(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));

    stakedAvUSD.addToBlacklist(bob, false);
    assertTrue(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, bob));
    vm.stopPrank();
  }

  function testBlacklistManagerCannotRedistribute() public {
    vm.prank(owner);
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, alice));

    _mintApproveDeposit(bob, 1000 ether, false);
    assertEq(stakedAvUSD.balanceOf(bob), 1000 ether);

    vm.startPrank(alice);
    stakedAvUSD.addToBlacklist(bob, true);
    assertTrue(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));
    vm.expectRevert(
      "AccessControl: account 0x328809bc894f92807417d2dad6b7c998c1afdac6 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedAvUSD.redistributeLockedAmount(bob, alice);
    assertEq(stakedAvUSD.balanceOf(bob), 1000 ether);
    vm.stopPrank();
  }

  function testBlackListManagerCannotAddOthers() public {
    vm.prank(owner);
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.prank(alice);
    vm.expectRevert(
      "AccessControl: account 0x328809bc894f92807417d2dad6b7c998c1afdac6 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, bob);
  }

  function testBlacklistManagerCanUnblacklist() public {
    vm.prank(owner);
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.startPrank(alice);
    stakedAvUSD.addToBlacklist(bob, true);
    assertTrue(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));

    stakedAvUSD.addToBlacklist(bob, false);
    assertTrue(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, bob));

    stakedAvUSD.removeFromBlacklist(bob, true);
    assertFalse(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, bob));

    stakedAvUSD.removeFromBlacklist(bob, false);
    assertFalse(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, bob));
    vm.stopPrank();
  }

  function testBlacklistManagerCanNotBlacklistAdmin() public {
    vm.prank(owner);
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, alice));

    vm.startPrank(alice);
    vm.expectRevert(IStakedAvUSD.CantBlacklistOwner.selector);
    stakedAvUSD.addToBlacklist(owner, true);
    vm.expectRevert(IStakedAvUSD.CantBlacklistOwner.selector);
    stakedAvUSD.addToBlacklist(owner, false);
    vm.stopPrank();

    assertFalse(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, owner));
    assertFalse(stakedAvUSD.hasRole(SOFT_RESTRICTED_STAKER_ROLE, owner));
  }

  function testOwnerCanRemoveBlacklistManager() public {
    vm.startPrank(owner);
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, alice));

    stakedAvUSD.revokeRole(BLACKLIST_MANAGER_ROLE, alice);
    vm.stopPrank();

    assertFalse(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
  }
}
