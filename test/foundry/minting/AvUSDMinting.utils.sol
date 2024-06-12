// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable func-name-mixedcase  */

import "./MintingBaseSetup.sol";
import "forge-std/console.sol";

// These functions are reused across multiple files
contract AvUSDMintingUtils is MintingBaseSetup {
  function maxMint_perBlock_exceeded_revert(uint256 excessiveMintAmount) public {
    // This amount is always greater than the allowed max mint per block
    vm.assume(excessiveMintAmount > AvUSDMintingContract.maxMintPerBlock());
    (
      IAvUSDMinting.Order memory order,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    ) = mint_setup(excessiveMintAmount, _stETHToDeposit, 1, false);

    vm.prank(minter);
    vm.expectRevert(MaxMintPerBlockExceeded);
    AvUSDMintingContract.mint(order, route, takerSignature);

    assertEq(avusdToken.balanceOf(beneficiary), 0, "The beneficiary balance should be 0");
    assertEq(stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "The avUSD minting stETH balance should be 0");
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in stETH balance");
  }

  function maxRedeem_perBlock_exceeded_revert(uint256 excessiveRedeemAmount) public {
    // Set the max mint per block to the same value as the max redeem in order to get to the redeem
    vm.prank(owner);
    AvUSDMintingContract.setMaxMintPerBlock(excessiveRedeemAmount);

    (IAvUSDMinting.Order memory redeemOrder, IAvUSDMinting.Signature memory takerSignature2) =
      redeem_setup(excessiveRedeemAmount, _stETHToDeposit, 1, false);

    vm.startPrank(redeemer);
    vm.expectRevert(MaxRedeemPerBlockExceeded);
    AvUSDMintingContract.redeem(redeemOrder, takerSignature2);

    assertEq(stETHToken.balanceOf(address(AvUSDMintingContract)), _stETHToDeposit, "Mismatch in stETH balance");
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in stETH balance");
    assertEq(avusdToken.balanceOf(beneficiary), excessiveRedeemAmount, "Mismatch in AvUSD balance");

    vm.stopPrank();
  }

  function executeMint() public {
    (
      IAvUSDMinting.Order memory order,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    ) = mint_setup(_avusdToMint, _stETHToDeposit, 1, false);

    vm.prank(minter);
    AvUSDMintingContract.mint(order, route, takerSignature);
  }

  function executeRedeem() public {
    (IAvUSDMinting.Order memory redeemOrder, IAvUSDMinting.Signature memory takerSignature2) =
      redeem_setup(_avusdToMint, _stETHToDeposit, 1, false);
    vm.prank(redeemer);
    AvUSDMintingContract.redeem(redeemOrder, takerSignature2);
  }
}
