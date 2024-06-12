// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable func-name-mixedcase  */

import "../AvUSDMinting.utils.sol";
import "../../../../contracts/interfaces/ISingleAdminAccessControl.sol";

contract AvUSDMintingACLTest is AvUSDMintingUtils {
  function setUp() public override {
    super.setUp();
  }

  function test_role_authorization() public {
    vm.deal(trader1, 1 ether);
    vm.deal(maker1, 1 ether);
    vm.deal(maker2, 1 ether);
    vm.startPrank(minter);
    stETHToken.mint(1 * 1e18, maker1);
    stETHToken.mint(1 * 1e18, trader1);
    vm.expectRevert(OnlyMinterErr);
    avusdToken.mint(address(maker2), 2000 * 1e18);
    vm.expectRevert(OnlyMinterErr);
    avusdToken.mint(address(trader2), 2000 * 1e18);
  }

  function test_redeem_notRedeemer_revert() public {
    (IAvUSDMinting.Order memory redeemOrder, IAvUSDMinting.Signature memory takerSignature2) =
      redeem_setup(_avusdToMint, _stETHToDeposit, 1, false);

    vm.startPrank(minter);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(minter), " is missing role ", vm.toString(redeemerRole)
        )
      )
    );
    AvUSDMintingContract.redeem(redeemOrder, takerSignature2);
  }

  function test_fuzz_notMinter_cannot_mint(address nonMinter) public {
    (
      IAvUSDMinting.Order memory mintOrder,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    ) = mint_setup(_avusdToMint, _stETHToDeposit, 1, false);

    vm.assume(nonMinter != minter);
    vm.startPrank(nonMinter);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(nonMinter), " is missing role ", vm.toString(minterRole)
        )
      )
    );
    AvUSDMintingContract.mint(mintOrder, route, takerSignature);

    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(avusdToken.balanceOf(beneficiary), 0);
  }

  function test_fuzz_nonOwner_cannot_add_supportedAsset_revert(address nonOwner) public {
    vm.assume(nonOwner != owner);
    address asset = address(20);
    vm.expectRevert();
    vm.prank(nonOwner);
    AvUSDMintingContract.addSupportedAsset(asset);
    assertFalse(AvUSDMintingContract.isSupportedAsset(asset));
  }

  function test_fuzz_nonOwner_cannot_remove_supportedAsset_revert(address nonOwner) public {
    vm.assume(nonOwner != owner);
    address asset = address(20);
    vm.prank(owner);
    vm.expectEmit(true, false, false, false);
    emit AssetAdded(asset);
    AvUSDMintingContract.addSupportedAsset(asset);
    assertTrue(AvUSDMintingContract.isSupportedAsset(asset));

    vm.expectRevert();
    vm.prank(nonOwner);
    AvUSDMintingContract.removeSupportedAsset(asset);
    assertTrue(AvUSDMintingContract.isSupportedAsset(asset));
  }

  function test_collManager_canTransfer_custody() public {
    vm.startPrank(owner);
    stETHToken.mint(1000, address(AvUSDMintingContract));
    AvUSDMintingContract.addCustodianAddress(beneficiary);
    vm.stopPrank();
    vm.prank(collManager);
    vm.expectEmit(true, true, true, true);
    emit CustodyTransfer(beneficiary, address(stETHToken), 1000);
    AvUSDMintingContract.transferToCustody(beneficiary, address(stETHToken), 1000);
    assertEq(stETHToken.balanceOf(beneficiary), 1000);
    assertEq(stETHToken.balanceOf(address(AvUSDMintingContract)), 0);
  }

  function test_fuzz_nonCollManager_cannot_transferCustody_revert(address nonMinter) public {
    vm.assume(nonMinter != collManager);
    stETHToken.mint(1000, address(AvUSDMintingContract));

    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(nonMinter), " is missing role ", vm.toString(collateralManagerRole)
        )
      )
    );
    vm.prank(nonMinter);
    AvUSDMintingContract.transferToCustody(beneficiary, address(stETHToken), 1000);
  }

  /**
   * Gatekeeper tests
   */

  function test_gatekeeper_can_remove_minter() public {
    vm.prank(gatekeeper);

    AvUSDMintingContract.removeMinterRole(minter);
    assertFalse(AvUSDMintingContract.hasRole(minterRole, minter));
  }

  function test_gatekeeper_can_remove_redeemer() public {
    vm.prank(gatekeeper);

    AvUSDMintingContract.removeRedeemerRole(redeemer);
    assertFalse(AvUSDMintingContract.hasRole(redeemerRole, redeemer));
  }

  function test_fuzz_not_gatekeeper_cannot_remove_minter_revert(address notGatekeeper) public {
    vm.assume(notGatekeeper != gatekeeper);
    vm.startPrank(notGatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ",
          Strings.toHexString(notGatekeeper),
          " is missing role ",
          vm.toString(gatekeeperRole)
        )
      )
    );
    AvUSDMintingContract.removeMinterRole(minter);
    assertTrue(AvUSDMintingContract.hasRole(minterRole, minter));
  }

  function test_fuzz_not_gatekeeper_cannot_remove_redeemer_revert(address notGatekeeper) public {
    vm.assume(notGatekeeper != gatekeeper);
    vm.startPrank(notGatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ",
          Strings.toHexString(notGatekeeper),
          " is missing role ",
          vm.toString(gatekeeperRole)
        )
      )
    );
    AvUSDMintingContract.removeRedeemerRole(redeemer);
    assertTrue(AvUSDMintingContract.hasRole(redeemerRole, redeemer));
  }

  function test_gatekeeper_cannot_add_minters_revert() public {
    vm.startPrank(gatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(gatekeeper), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    AvUSDMintingContract.grantRole(minterRole, bob);
    assertFalse(AvUSDMintingContract.hasRole(minterRole, bob), "Bob should lack the minter role");
  }

  function test_gatekeeper_can_disable_mintRedeem() public {
    vm.startPrank(gatekeeper);
    AvUSDMintingContract.disableMintRedeem();

    (
      IAvUSDMinting.Order memory order,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    ) = mint_setup(_avusdToMint, _stETHToDeposit, 1, false);

    vm.prank(minter);
    vm.expectRevert(MaxMintPerBlockExceeded);
    AvUSDMintingContract.mint(order, route, takerSignature);

    vm.prank(redeemer);
    vm.expectRevert(MaxRedeemPerBlockExceeded);
    AvUSDMintingContract.redeem(order, takerSignature);

    assertEq(AvUSDMintingContract.maxMintPerBlock(), 0, "Minting should be disabled");
    assertEq(AvUSDMintingContract.maxRedeemPerBlock(), 0, "Redeeming should be disabled");
  }

  // Ensure that the gatekeeper is not allowed to enable/modify the minting
  function test_gatekeeper_cannot_enable_mint_revert() public {
    test_fuzz_nonAdmin_cannot_enable_mint_revert(gatekeeper);
  }

  // Ensure that the gatekeeper is not allowed to enable/modify the redeeming
  function test_gatekeeper_cannot_enable_redeem_revert() public {
    test_fuzz_nonAdmin_cannot_enable_redeem_revert(gatekeeper);
  }

  function test_fuzz_not_gatekeeper_cannot_disable_mintRedeem_revert(address notGatekeeper) public {
    vm.assume(notGatekeeper != gatekeeper);
    vm.startPrank(notGatekeeper);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ",
          Strings.toHexString(notGatekeeper),
          " is missing role ",
          vm.toString(gatekeeperRole)
        )
      )
    );
    AvUSDMintingContract.disableMintRedeem();

    assertTrue(AvUSDMintingContract.maxMintPerBlock() > 0);
    assertTrue(AvUSDMintingContract.maxRedeemPerBlock() > 0);
  }

  /**
   * Admin tests
   */
  function test_admin_can_disable_mint(bool performCheckMint) public {
    vm.prank(owner);
    AvUSDMintingContract.setMaxMintPerBlock(0);

    if (performCheckMint) maxMint_perBlock_exceeded_revert(1e18);

    assertEq(AvUSDMintingContract.maxMintPerBlock(), 0, "The minting should be disabled");
  }

  function test_admin_can_disable_redeem(bool performCheckRedeem) public {
    vm.prank(owner);
    AvUSDMintingContract.setMaxRedeemPerBlock(0);

    if (performCheckRedeem) maxRedeem_perBlock_exceeded_revert(1e18);

    assertEq(AvUSDMintingContract.maxRedeemPerBlock(), 0, "The redeem should be disabled");
  }

  function test_admin_can_enable_mint() public {
    vm.startPrank(owner);
    AvUSDMintingContract.setMaxMintPerBlock(0);

    assertEq(AvUSDMintingContract.maxMintPerBlock(), 0, "The minting should be disabled");

    // Re-enable the minting
    AvUSDMintingContract.setMaxMintPerBlock(_maxMintPerBlock);

    vm.stopPrank();

    executeMint();

    assertTrue(AvUSDMintingContract.maxMintPerBlock() > 0, "The minting should be enabled");
  }

  function test_fuzz_nonAdmin_cannot_enable_mint_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);

    test_admin_can_disable_mint(false);

    vm.prank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    AvUSDMintingContract.setMaxMintPerBlock(_maxMintPerBlock);

    maxMint_perBlock_exceeded_revert(1e18);

    assertEq(AvUSDMintingContract.maxMintPerBlock(), 0, "The minting should remain disabled");
  }

  function test_fuzz_nonAdmin_cannot_enable_redeem_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);

    test_admin_can_disable_redeem(false);

    vm.prank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    AvUSDMintingContract.setMaxRedeemPerBlock(_maxRedeemPerBlock);

    maxRedeem_perBlock_exceeded_revert(1e18);

    assertEq(AvUSDMintingContract.maxRedeemPerBlock(), 0, "The redeeming should remain disabled");
  }

  function test_admin_can_enable_redeem() public {
    vm.startPrank(owner);
    AvUSDMintingContract.setMaxRedeemPerBlock(0);

    assertEq(AvUSDMintingContract.maxRedeemPerBlock(), 0, "The redeem should be disabled");

    // Re-enable the redeeming
    AvUSDMintingContract.setMaxRedeemPerBlock(_maxRedeemPerBlock);

    vm.stopPrank();

    executeRedeem();

    assertTrue(AvUSDMintingContract.maxRedeemPerBlock() > 0, "The redeeming should be enabled");
  }

  function test_admin_can_add_minter() public {
    vm.startPrank(owner);
    AvUSDMintingContract.grantRole(minterRole, bob);

    assertTrue(AvUSDMintingContract.hasRole(minterRole, bob), "Bob should have the minter role");
    vm.stopPrank();
  }

  function test_admin_can_remove_minter() public {
    test_admin_can_add_minter();

    vm.startPrank(owner);
    AvUSDMintingContract.revokeRole(minterRole, bob);

    assertFalse(AvUSDMintingContract.hasRole(minterRole, bob), "Bob should no longer have the minter role");

    vm.stopPrank();
  }

  function test_admin_can_add_gatekeeper() public {
    vm.startPrank(owner);
    AvUSDMintingContract.grantRole(gatekeeperRole, bob);

    assertTrue(AvUSDMintingContract.hasRole(gatekeeperRole, bob), "Bob should have the gatekeeper role");
    vm.stopPrank();
  }

  function test_admin_can_remove_gatekeeper() public {
    test_admin_can_add_gatekeeper();

    vm.startPrank(owner);
    AvUSDMintingContract.revokeRole(gatekeeperRole, bob);

    assertFalse(AvUSDMintingContract.hasRole(gatekeeperRole, bob), "Bob should no longer have the gatekeeper role");

    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_remove_minter(address notAdmin) public {
    test_admin_can_add_minter();

    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    AvUSDMintingContract.revokeRole(minterRole, bob);

    assertTrue(AvUSDMintingContract.hasRole(minterRole, bob), "Bob should maintain the minter role");
    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_remove_gatekeeper(address notAdmin) public {
    test_admin_can_add_gatekeeper();

    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    AvUSDMintingContract.revokeRole(gatekeeperRole, bob);

    assertTrue(AvUSDMintingContract.hasRole(gatekeeperRole, bob), "Bob should maintain the gatekeeper role");

    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_add_minter(address notAdmin) public {
    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    AvUSDMintingContract.grantRole(minterRole, bob);

    assertFalse(AvUSDMintingContract.hasRole(minterRole, bob), "Bob should lack the minter role");
    vm.stopPrank();
  }

  function test_fuzz_notAdmin_cannot_add_gatekeeper(address notAdmin) public {
    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);
    vm.expectRevert(
      bytes(
        string.concat(
          "AccessControl: account ", Strings.toHexString(notAdmin), " is missing role ", vm.toString(adminRole)
        )
      )
    );
    AvUSDMintingContract.grantRole(gatekeeperRole, bob);

    assertFalse(AvUSDMintingContract.hasRole(gatekeeperRole, bob), "Bob should lack the gatekeeper role");

    vm.stopPrank();
  }

  function test_base_transferAdmin() public {
    vm.prank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    assertTrue(AvUSDMintingContract.hasRole(adminRole, owner));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, newOwner));

    vm.prank(newOwner);
    AvUSDMintingContract.acceptAdmin();
    assertFalse(AvUSDMintingContract.hasRole(adminRole, owner));
    assertTrue(AvUSDMintingContract.hasRole(adminRole, newOwner));
  }

  function test_transferAdmin_notAdmin() public {
    vm.startPrank(randomer);
    vm.expectRevert();
    AvUSDMintingContract.transferAdmin(randomer);
  }

  function test_grantRole_AdminRoleExternally() public {
    vm.startPrank(randomer);
    vm.expectRevert(
      "AccessControl: account 0xc91041eae7bf78e1040f4abd7b29908651f45546 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    AvUSDMintingContract.grantRole(adminRole, randomer);
    vm.stopPrank();
  }

  function test_revokeRole_notAdmin() public {
    vm.startPrank(randomer);
    vm.expectRevert(
      "AccessControl: account 0xc91041eae7bf78e1040f4abd7b29908651f45546 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    AvUSDMintingContract.revokeRole(adminRole, owner);
  }

  function test_revokeRole_AdminRole() public {
    vm.startPrank(owner);
    vm.expectRevert();
    AvUSDMintingContract.revokeRole(adminRole, owner);
  }

  function test_renounceRole_notAdmin() public {
    vm.startPrank(randomer);
    vm.expectRevert(InvalidAdminChange);
    AvUSDMintingContract.renounceRole(adminRole, owner);
  }

  function test_renounceRole_AdminRole() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAdminChange);
    AvUSDMintingContract.renounceRole(adminRole, owner);
  }

  function test_revoke_AdminRole() public {
    vm.prank(owner);
    vm.expectRevert(InvalidAdminChange);
    AvUSDMintingContract.revokeRole(adminRole, owner);
  }

  function test_grantRole_nonAdminRole() public {
    vm.prank(owner);
    AvUSDMintingContract.grantRole(minterRole, randomer);
    assertTrue(AvUSDMintingContract.hasRole(minterRole, randomer));
  }

  function test_revokeRole_nonAdminRole() public {
    vm.startPrank(owner);
    AvUSDMintingContract.grantRole(minterRole, randomer);
    AvUSDMintingContract.revokeRole(minterRole, randomer);
    vm.stopPrank();
    assertFalse(AvUSDMintingContract.hasRole(minterRole, randomer));
  }

  function test_renounceRole_nonAdminRole() public {
    vm.prank(owner);
    AvUSDMintingContract.grantRole(minterRole, randomer);
    vm.prank(randomer);
    AvUSDMintingContract.renounceRole(minterRole, randomer);
    assertFalse(AvUSDMintingContract.hasRole(minterRole, randomer));
  }

  function testCanRepeatedlyTransferAdmin() public {
    vm.startPrank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    AvUSDMintingContract.transferAdmin(randomer);
    vm.stopPrank();
  }

  function test_renounceRole_forDifferentAccount() public {
    vm.prank(randomer);
    vm.expectRevert("AccessControl: can only renounce roles for self");
    AvUSDMintingContract.renounceRole(minterRole, owner);
  }

  function testCancelTransferAdmin() public {
    vm.startPrank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    AvUSDMintingContract.transferAdmin(address(0));
    vm.stopPrank();
    assertTrue(AvUSDMintingContract.hasRole(adminRole, owner));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, address(0)));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, newOwner));
  }

  function test_admin_cannot_transfer_self() public {
    vm.startPrank(owner);
    vm.expectRevert(InvalidAdminChange);
    AvUSDMintingContract.transferAdmin(owner);
    vm.stopPrank();
    assertTrue(AvUSDMintingContract.hasRole(adminRole, owner));
  }

  function testAdminCanCancelTransfer() public {
    vm.startPrank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    AvUSDMintingContract.transferAdmin(address(0));
    vm.stopPrank();

    vm.prank(newOwner);
    vm.expectRevert(ISingleAdminAccessControl.NotPendingAdmin.selector);
    AvUSDMintingContract.acceptAdmin();

    assertTrue(AvUSDMintingContract.hasRole(adminRole, owner));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, address(0)));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, newOwner));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.startPrank(owner);
    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    AvUSDMintingContract.renounceRole(adminRole, owner);

    vm.expectRevert(ISingleAdminAccessControl.InvalidAdminChange.selector);
    AvUSDMintingContract.revokeRole(adminRole, owner);
    vm.stopPrank();
    assertEq(AvUSDMintingContract.owner(), owner);
    assertTrue(AvUSDMintingContract.hasRole(adminRole, owner));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    assertEq(AvUSDMintingContract.owner(), owner);
    assertTrue(AvUSDMintingContract.hasRole(adminRole, owner));
    assertNotEq(AvUSDMintingContract.owner(), newOwner);
    assertFalse(AvUSDMintingContract.hasRole(adminRole, newOwner));
  }

  function testCanTransferOwnership() public {
    vm.prank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    vm.prank(newOwner);
    AvUSDMintingContract.acceptAdmin();
    assertTrue(AvUSDMintingContract.hasRole(adminRole, newOwner));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, owner));
  }

  function testNewOwnerCanPerformOwnerActions() public {
    vm.prank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    vm.startPrank(newOwner);
    AvUSDMintingContract.acceptAdmin();
    AvUSDMintingContract.grantRole(gatekeeperRole, bob);
    vm.stopPrank();
    assertTrue(AvUSDMintingContract.hasRole(adminRole, newOwner));
    assertTrue(AvUSDMintingContract.hasRole(gatekeeperRole, bob));
  }

  function testOldOwnerCantPerformOwnerActions() public {
    vm.prank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    vm.prank(newOwner);
    AvUSDMintingContract.acceptAdmin();
    assertTrue(AvUSDMintingContract.hasRole(adminRole, newOwner));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    AvUSDMintingContract.grantRole(gatekeeperRole, bob);
    assertFalse(AvUSDMintingContract.hasRole(gatekeeperRole, bob));
  }

  function testOldOwnerCantTransferOwnership() public {
    vm.prank(owner);
    AvUSDMintingContract.transferAdmin(newOwner);
    vm.prank(newOwner);
    AvUSDMintingContract.acceptAdmin();
    assertTrue(AvUSDMintingContract.hasRole(adminRole, newOwner));
    assertFalse(AvUSDMintingContract.hasRole(adminRole, owner));
    vm.prank(owner);
    vm.expectRevert(
      "AccessControl: account 0xe05fcc23807536bee418f142d19fa0d21bb0cff7 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    AvUSDMintingContract.transferAdmin(bob);
    assertFalse(AvUSDMintingContract.hasRole(adminRole, bob));
  }

  function testNonAdminCanRenounceRoles() public {
    vm.prank(owner);
    AvUSDMintingContract.grantRole(gatekeeperRole, bob);
    assertTrue(AvUSDMintingContract.hasRole(gatekeeperRole, bob));

    vm.prank(bob);
    AvUSDMintingContract.renounceRole(gatekeeperRole, bob);
    assertFalse(AvUSDMintingContract.hasRole(gatekeeperRole, bob));
  }

  function testCorrectInitConfig() public {
    AvUSDMinting avUSDMinting2 = new AvUSDMinting(
      IAvUSD(address(avusdToken)),
      IWAVAX(address(token)),
      assets,
      custodians,
      randomer,
      _maxMintPerBlock,
      _maxRedeemPerBlock
    );
    assertFalse(avUSDMinting2.hasRole(adminRole, owner));
    assertNotEq(avUSDMinting2.owner(), owner);
    assertTrue(avUSDMinting2.hasRole(adminRole, randomer));
    assertEq(avUSDMinting2.owner(), randomer);
  }
}
