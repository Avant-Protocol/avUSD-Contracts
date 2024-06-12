// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import "../../../contracts/AvUSD.sol";
import "../../../contracts/StakedAvUSD.sol";
import "../../../contracts/interfaces/IStakedAvUSD.sol";
import "../../../contracts/interfaces/IAvUSD.sol";
import "../../../contracts/interfaces/IERC20Events.sol";
import "../../../contracts/interfaces/ISingleAdminAccessControl.sol";

contract StakedAvUSDACL is Test, IERC20Events {
  AvUSD public avusdToken;
  StakedAvUSD public stakedAvUSD;
  SigUtils public sigUtilsAvUSD;
  SigUtils public sigUtilsStakedAvUSD;

  address public owner;
  address public rewarder;
  address public alice;
  address public newOwner;
  address public greg;

  bytes32 public DEFAULT_ADMIN_ROLE;
  bytes32 public constant BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
  bytes32 public constant FULL_RESTRICTED_STAKER_ROLE = keccak256("FULL_RESTRICTED_STAKER_ROLE");

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event RewardsReceived(uint256 indexed amount, uint256 newVestingAvUSDAmount);

  function setUp() public virtual {
    avusdToken = new AvUSD(address(this));

    alice = vm.addr(0xB44DE);
    newOwner = vm.addr(0x1DE);
    greg = vm.addr(0x6ED);
    owner = vm.addr(0xA11CE);
    rewarder = vm.addr(0x1DEA);
    vm.label(alice, "alice");
    vm.label(newOwner, "newOwner");
    vm.label(greg, "greg");
    vm.label(owner, "owner");
    vm.label(rewarder, "rewarder");

    vm.prank(owner);
    stakedAvUSD = new StakedAvUSD(IAvUSD(address(avusdToken)), rewarder, owner);

    DEFAULT_ADMIN_ROLE = stakedAvUSD.DEFAULT_ADMIN_ROLE();

    sigUtilsAvUSD = new SigUtils(avusdToken.DOMAIN_SEPARATOR());
    sigUtilsStakedAvUSD = new SigUtils(stakedAvUSD.DOMAIN_SEPARATOR());
  }

  function testCorrectSetup() public {
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testCancelTransferAdmin() public {
    vm.startPrank(owner);
    stakedAvUSD.transferAdmin(newOwner);
    stakedAvUSD.transferAdmin(address(0));
    vm.stopPrank();
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, address(0)));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
  }

  function test_admin_cannot_transfer_self() public {
    vm.startPrank(owner);
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    stakedAvUSD.transferAdmin(owner);
    vm.stopPrank();
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testAdminCanCancelTransfer() public {
    vm.startPrank(owner);
    stakedAvUSD.transferAdmin(newOwner);
    stakedAvUSD.transferAdmin(address(0));
    vm.stopPrank();

    vm.prank(newOwner);
    vm.expectRevert(ISingleAdminAccessControl.NotPendingAdmin.selector);
    stakedAvUSD.acceptAdmin();

    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, address(0)));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.startPrank(owner);
    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    stakedAvUSD.renounceRole(DEFAULT_ADMIN_ROLE, owner);

    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    stakedAvUSD.revokeRole(DEFAULT_ADMIN_ROLE, owner);
    vm.stopPrank();
    assertEq(stakedAvUSD.owner(), owner);
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(owner);
    stakedAvUSD.transferAdmin(newOwner);
    assertEq(stakedAvUSD.owner(), owner);
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
    assertNotEq(stakedAvUSD.owner(), newOwner);
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
  }

  function testCanTransferOwnership() public {
    vm.prank(owner);
    stakedAvUSD.transferAdmin(newOwner);
    vm.prank(newOwner);
    stakedAvUSD.acceptAdmin();
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
  }

  function testNewOwnerCanPerformOwnerActions() public {
    vm.prank(owner);
    stakedAvUSD.transferAdmin(newOwner);
    vm.startPrank(newOwner);
    stakedAvUSD.acceptAdmin();
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, newOwner);
    stakedAvUSD.addToBlacklist(alice, true);
    vm.stopPrank();
    assertTrue(stakedAvUSD.hasRole(FULL_RESTRICTED_STAKER_ROLE, alice));
  }

  function testOldOwnerCantPerformOwnerActions() public {
    vm.prank(owner);
    stakedAvUSD.transferAdmin(newOwner);
    vm.prank(newOwner);
    stakedAvUSD.acceptAdmin();
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertFalse(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
  }

  function testOldOwnerCantTransferOwnership() public {
    vm.prank(owner);
    stakedAvUSD.transferAdmin(newOwner);
    vm.prank(newOwner);
    stakedAvUSD.acceptAdmin();
    assertTrue(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, newOwner));
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    stakedAvUSD.transferAdmin(alice);
    assertFalse(stakedAvUSD.hasRole(DEFAULT_ADMIN_ROLE, alice));
  }

  function testNonAdminCantRenounceRoles() public {
    vm.prank(owner);
    stakedAvUSD.grantRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));

    vm.prank(alice);
    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    stakedAvUSD.renounceRole(BLACKLIST_MANAGER_ROLE, alice);
    assertTrue(stakedAvUSD.hasRole(BLACKLIST_MANAGER_ROLE, alice));
  }
}
