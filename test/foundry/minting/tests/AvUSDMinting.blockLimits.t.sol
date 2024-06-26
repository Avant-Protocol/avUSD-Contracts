// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable func-name-mixedcase  */

import "../AvUSDMinting.utils.sol";

contract AvUSDMintingBlockLimitsTest is AvUSDMintingUtils {
  /**
   * Max mint per block tests
   */

  // Ensures that the minted per block amount raises accordingly
  // when multiple mints are performed
  function test_multiple_mints() public {
    uint256 maxMintAmount = AvUSDMintingContract.maxMintPerBlock();
    uint256 firstMintAmount = maxMintAmount / 4;
    uint256 secondMintAmount = maxMintAmount / 2;
    (
      IAvUSDMinting.Order memory aOrder,
      IAvUSDMinting.Signature memory aTakerSignature,
      IAvUSDMinting.Route memory aRoute
    ) = mint_setup(firstMintAmount, _stETHToDeposit, 1, false);

    vm.prank(minter);
    AvUSDMintingContract.mint(aOrder, aRoute, aTakerSignature);

    vm.prank(owner);
    stETHToken.mint(_stETHToDeposit, benefactor);

    (
      IAvUSDMinting.Order memory bOrder,
      IAvUSDMinting.Signature memory bTakerSignature,
      IAvUSDMinting.Route memory bRoute
    ) = mint_setup(secondMintAmount, _stETHToDeposit, 2, true);
    vm.prank(minter);
    AvUSDMintingContract.mint(bOrder, bRoute, bTakerSignature);

    assertEq(
      AvUSDMintingContract.mintedPerBlock(block.number), firstMintAmount + secondMintAmount, "Incorrect minted amount"
    );
    assertTrue(
      AvUSDMintingContract.mintedPerBlock(block.number) < maxMintAmount, "Mint amount exceeded without revert"
    );
  }

  function test_fuzz_maxMint_perBlock_exceeded_revert(uint256 excessiveMintAmount) public {
    // This amount is always greater than the allowed max mint per block
    vm.assume(excessiveMintAmount > AvUSDMintingContract.maxMintPerBlock());

    maxMint_perBlock_exceeded_revert(excessiveMintAmount);
  }

  function test_fuzz_mint_maxMint_perBlock_exceeded_revert(uint256 excessiveMintAmount) public {
    vm.assume(excessiveMintAmount > AvUSDMintingContract.maxMintPerBlock());
    (
      IAvUSDMinting.Order memory mintOrder,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    ) = mint_setup(excessiveMintAmount, _stETHToDeposit, 1, false);

    // maker
    vm.startPrank(minter);
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit);
    assertEq(avusdToken.balanceOf(beneficiary), 0);

    vm.expectRevert(MaxMintPerBlockExceeded);
    // minter passes in permit signature data
    AvUSDMintingContract.mint(mintOrder, route, takerSignature);

    assertEq(
      stETHToken.balanceOf(benefactor),
      _stETHToDeposit,
      "The benefactor stEth balance should be the same as the minted stEth"
    );
    assertEq(avusdToken.balanceOf(beneficiary), 0, "The beneficiary AvUSD balance should be 0");
  }

  function test_fuzz_nextBlock_mint_is_zero(uint256 mintAmount) public {
    vm.assume(mintAmount < AvUSDMintingContract.maxMintPerBlock() && mintAmount > 0);
    (
      IAvUSDMinting.Order memory order,
      IAvUSDMinting.Signature memory takerSignature,
      IAvUSDMinting.Route memory route
    ) = mint_setup(_avusdToMint, _stETHToDeposit, 1, false);

    vm.prank(minter);
    AvUSDMintingContract.mint(order, route, takerSignature);

    vm.roll(block.number + 1);

    assertEq(
      AvUSDMintingContract.mintedPerBlock(block.number), 0, "The minted amount should reset to 0 in the next block"
    );
  }

  function test_fuzz_maxMint_perBlock_setter(uint256 newMaxMintPerBlock) public {
    vm.assume(newMaxMintPerBlock > 0);

    uint256 oldMaxMintPerBlock = AvUSDMintingContract.maxMintPerBlock();

    vm.prank(owner);
    vm.expectEmit();
    emit MaxMintPerBlockChanged(oldMaxMintPerBlock, newMaxMintPerBlock);

    AvUSDMintingContract.setMaxMintPerBlock(newMaxMintPerBlock);

    assertEq(AvUSDMintingContract.maxMintPerBlock(), newMaxMintPerBlock, "The max mint per block setter failed");
  }

  /**
   * Max redeem per block tests
   */

  // Ensures that the redeemed per block amount raises accordingly
  // when multiple mints are performed
  function test_multiple_redeem() public {
    uint256 maxRedeemAmount = AvUSDMintingContract.maxRedeemPerBlock();
    uint256 firstRedeemAmount = maxRedeemAmount / 4;
    uint256 secondRedeemAmount = maxRedeemAmount / 2;

    (IAvUSDMinting.Order memory redeemOrder, IAvUSDMinting.Signature memory takerSignature2) =
      redeem_setup(firstRedeemAmount, _stETHToDeposit, 1, false);

    vm.prank(redeemer);
    AvUSDMintingContract.redeem(redeemOrder, takerSignature2);

    vm.prank(owner);
    stETHToken.mint(_stETHToDeposit, benefactor);

    (IAvUSDMinting.Order memory bRedeemOrder, IAvUSDMinting.Signature memory bTakerSignature2) =
      redeem_setup(secondRedeemAmount, _stETHToDeposit, 2, true);

    vm.prank(redeemer);
    AvUSDMintingContract.redeem(bRedeemOrder, bTakerSignature2);

    assertEq(
      AvUSDMintingContract.mintedPerBlock(block.number),
      firstRedeemAmount + secondRedeemAmount,
      "Incorrect minted amount"
    );
    assertTrue(
      AvUSDMintingContract.redeemedPerBlock(block.number) < maxRedeemAmount, "Redeem amount exceeded without revert"
    );
  }

  function test_fuzz_maxRedeem_perBlock_exceeded_revert(uint256 excessiveRedeemAmount) public {
    // This amount is always greater than the allowed max redeem per block
    vm.assume(excessiveRedeemAmount > AvUSDMintingContract.maxRedeemPerBlock());

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

  function test_fuzz_nextBlock_redeem_is_zero(uint256 redeemAmount) public {
    vm.assume(redeemAmount < AvUSDMintingContract.maxRedeemPerBlock() && redeemAmount > 0);
    (IAvUSDMinting.Order memory redeemOrder, IAvUSDMinting.Signature memory takerSignature2) =
      redeem_setup(redeemAmount, _stETHToDeposit, 1, false);

    vm.startPrank(redeemer);
    AvUSDMintingContract.redeem(redeemOrder, takerSignature2);

    vm.roll(block.number + 1);

    assertEq(
      AvUSDMintingContract.redeemedPerBlock(block.number), 0, "The redeemed amount should reset to 0 in the next block"
    );
    vm.stopPrank();
  }

  function test_fuzz_maxRedeem_perBlock_setter(uint256 newMaxRedeemPerBlock) public {
    vm.assume(newMaxRedeemPerBlock > 0);

    uint256 oldMaxRedeemPerBlock = AvUSDMintingContract.maxMintPerBlock();

    vm.prank(owner);
    vm.expectEmit();
    emit MaxRedeemPerBlockChanged(oldMaxRedeemPerBlock, newMaxRedeemPerBlock);
    AvUSDMintingContract.setMaxRedeemPerBlock(newMaxRedeemPerBlock);

    assertEq(AvUSDMintingContract.maxRedeemPerBlock(), newMaxRedeemPerBlock, "The max redeem per block setter failed");
  }
}
