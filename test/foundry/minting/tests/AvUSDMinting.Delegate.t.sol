// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../AvUSDMinting.utils.sol";

contract AvUSDMintingDelegateTest is AvUSDMintingUtils {
  function setUp() public override {
    super.setUp();
  }

  function testDelegateSuccessfulMint() public {
    (IAvUSDMinting.Order memory order,, IAvUSDMinting.Route memory route) =
      mint_setup(_avusdToMint, _stETHToDeposit, 1, false);

    vm.prank(benefactor);
    AvUSDMintingContract.setDelegatedSigner(trader2);

    vm.prank(trader2);
    AvUSDMintingContract.confirmDelegatedSigner(benefactor);

    bytes32 digest1 = AvUSDMintingContract.hashOrder(order);

    IAvUSDMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IAvUSDMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(avusdToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary AvUSD balance before mint");

    vm.prank(minter);
    AvUSDMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance after mint");
    assertEq(avusdToken.balanceOf(beneficiary), _avusdToMint, "Mismatch in beneficiary AvUSD balance after mint");
  }

  function testDelegateFailureMint() public {
    (IAvUSDMinting.Order memory order,, IAvUSDMinting.Route memory route) =
      mint_setup(_avusdToMint, _stETHToDeposit, 1, false);

    // omit delegation by benefactor

    bytes32 digest1 = AvUSDMintingContract.hashOrder(order);
    vm.prank(trader2);
    IAvUSDMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IAvUSDMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(avusdToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary AvUSD balance before mint");

    vm.prank(minter);
    vm.expectRevert(InvalidSignature);
    AvUSDMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(avusdToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary AvUSD balance after mint");
  }

  function testDelegateSuccessfulRedeem() public {
    (IAvUSDMinting.Order memory order,) = redeem_setup(_avusdToMint, _stETHToDeposit, 1, false);

    vm.prank(beneficiary);
    AvUSDMintingContract.setDelegatedSigner(trader2);

    vm.prank(trader2);
    AvUSDMintingContract.confirmDelegatedSigner(beneficiary);

    bytes32 digest1 = AvUSDMintingContract.hashOrder(order);
    IAvUSDMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IAvUSDMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance before mint");
    assertEq(avusdToken.balanceOf(beneficiary), _avusdToMint, "Mismatch in beneficiary AvUSD balance before mint");

    vm.prank(redeemer);
    AvUSDMintingContract.redeem(order, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(avusdToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary AvUSD balance after mint");
  }

  function testDelegateFailureRedeem() public {
    (IAvUSDMinting.Order memory order,) = redeem_setup(_avusdToMint, _stETHToDeposit, 1, false);

    // omit delegation by beneficiary

    bytes32 digest1 = AvUSDMintingContract.hashOrder(order);
    vm.prank(trader2);
    IAvUSDMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IAvUSDMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance before mint");
    assertEq(avusdToken.balanceOf(beneficiary), _avusdToMint, "Mismatch in beneficiary AvUSD balance before mint");

    vm.prank(redeemer);
    vm.expectRevert(InvalidSignature);
    AvUSDMintingContract.redeem(order, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance after mint");
    assertEq(avusdToken.balanceOf(beneficiary), _avusdToMint, "Mismatch in beneficiary AvUSD balance after mint");
  }

  function testCanUndelegate() public {
    (IAvUSDMinting.Order memory order,, IAvUSDMinting.Route memory route) =
      mint_setup(_avusdToMint, _stETHToDeposit, 1, false);

    // delegate and then undelegate
    vm.startPrank(benefactor);
    AvUSDMintingContract.setDelegatedSigner(trader2);
    AvUSDMintingContract.removeDelegatedSigner(trader2);
    vm.stopPrank();

    bytes32 digest1 = AvUSDMintingContract.hashOrder(order);
    vm.prank(trader2);
    IAvUSDMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IAvUSDMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(avusdToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary AvUSD balance before mint");

    vm.prank(minter);
    vm.expectRevert(InvalidSignature);
    AvUSDMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(AvUSDMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(avusdToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary AvUSD balance after mint");
  }
}
