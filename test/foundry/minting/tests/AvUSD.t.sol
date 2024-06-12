// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable private-vars-leading-underscore  */

import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";
import {Vm} from "forge-std/Vm.sol";

import "../../../../contracts/AvUSD.sol";
import "../AvUSDMinting.utils.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AvUSDTest is Test, IAvUSDDefinitions, AvUSDMintingUtils {
  AvUSD internal _avusdToken;

  uint256 internal _ownerPrivateKey;
  uint256 internal _newOwnerPrivateKey;
  uint256 internal _minterPrivateKey;
  uint256 internal _newMinterPrivateKey;

  address internal _owner;
  address internal _newOwner;
  address internal _minter;
  address internal _newMinter;

  function setUp() public virtual override {
    _ownerPrivateKey = 0xA11CE;
    _newOwnerPrivateKey = 0xA14CE;
    _minterPrivateKey = 0xB44DE;
    _newMinterPrivateKey = 0xB45DE;

    _owner = vm.addr(_ownerPrivateKey);
    _newOwner = vm.addr(_newOwnerPrivateKey);
    _minter = vm.addr(_minterPrivateKey);
    _newMinter = vm.addr(_newMinterPrivateKey);

    vm.label(_minter, "minter");
    vm.label(_owner, "owner");
    vm.label(_newMinter, "_newMinter");
    vm.label(_newOwner, "newOwner");

    _avusdToken = new AvUSD(_owner);
    vm.prank(_owner);
    _avusdToken.setMinter(_minter);
  }

  function testCorrectInitialConfig() public {
    assertEq(_avusdToken.owner(), _owner);
    assertEq(_avusdToken.minter(), _minter);
  }

  function testCantInitWithNoOwner() public {
    vm.expectRevert(ZeroAddressExceptionErr);
    new AvUSD(address(0));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.prank(_owner);
    vm.expectRevert(CantRenounceOwnershipErr);
    _avusdToken.renounceOwnership();
    assertEq(_avusdToken.owner(), _owner);
    assertNotEq(_avusdToken.owner(), address(0));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(_owner);
    _avusdToken.transferOwnership(_newOwner);
    assertEq(_avusdToken.owner(), _owner);
    assertNotEq(_avusdToken.owner(), _newOwner);
  }

  function testCanTransferOwnership() public {
    vm.prank(_owner);
    _avusdToken.transferOwnership(_newOwner);
    vm.prank(_newOwner);
    _avusdToken.acceptOwnership();
    assertEq(_avusdToken.owner(), _newOwner);
    assertNotEq(_avusdToken.owner(), _owner);
  }

  function testCanCancelOwnershipChange() public {
    vm.startPrank(_owner);
    _avusdToken.transferOwnership(_newOwner);
    _avusdToken.transferOwnership(address(0));
    vm.stopPrank();

    vm.prank(_newOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _newOwner));
    _avusdToken.acceptOwnership();
    assertEq(_avusdToken.owner(), _owner);
    assertNotEq(_avusdToken.owner(), _newOwner);
  }

  function testNewOwnerCanPerformOwnerActions() public {
    vm.prank(_owner);
    _avusdToken.transferOwnership(_newOwner);
    vm.startPrank(_newOwner);
    _avusdToken.acceptOwnership();
    _avusdToken.setMinter(_newMinter);
    vm.stopPrank();
    assertEq(_avusdToken.minter(), _newMinter);
    assertNotEq(_avusdToken.minter(), _minter);
  }

  function testOnlyOwnerCanSetMinter() public {
    vm.prank(_newOwner);
    vm.expectRevert("Ownable: caller is not the owner");
    _avusdToken.setMinter(_newMinter);
    assertEq(_avusdToken.minter(), _minter);
  }

  function testOwnerCantMint() public {
    vm.prank(_owner);
    vm.expectRevert(OnlyMinterErr);
    _avusdToken.mint(_newMinter, 100);
  }

  function testMinterCanMint() public {
    assertEq(_avusdToken.balanceOf(_newMinter), 0);
    vm.prank(_minter);
    _avusdToken.mint(_newMinter, 100);
    assertEq(_avusdToken.balanceOf(_newMinter), 100);
  }

  function testMinterCantMintToZeroAddress() public {
    vm.prank(_minter);
    vm.expectRevert("ERC20: mint to the zero address");
    _avusdToken.mint(address(0), 100);
  }

  function testNewMinterCanMint() public {
    assertEq(_avusdToken.balanceOf(_newMinter), 0);
    vm.prank(_owner);
    _avusdToken.setMinter(_newMinter);
    vm.prank(_newMinter);
    _avusdToken.mint(_newMinter, 100);
    assertEq(_avusdToken.balanceOf(_newMinter), 100);
  }

  function testOldMinterCantMint() public {
    assertEq(_avusdToken.balanceOf(_newMinter), 0);
    vm.prank(_owner);
    _avusdToken.setMinter(_newMinter);
    vm.prank(_minter);
    vm.expectRevert(OnlyMinterErr);
    _avusdToken.mint(_newMinter, 100);
    assertEq(_avusdToken.balanceOf(_newMinter), 0);
  }

  function testOldOwnerCantTransferOwnership() public {
    vm.prank(_owner);
    _avusdToken.transferOwnership(_newOwner);
    vm.prank(_newOwner);
    _avusdToken.acceptOwnership();
    assertNotEq(_avusdToken.owner(), _owner);
    assertEq(_avusdToken.owner(), _newOwner);
    vm.prank(_owner);
    vm.expectRevert("Ownable: caller is not the owner");
    _avusdToken.transferOwnership(_newMinter);
    assertEq(_avusdToken.owner(), _newOwner);
  }

  function testOldOwnerCantSetMinter() public {
    vm.prank(_owner);
    _avusdToken.transferOwnership(_newOwner);
    vm.prank(_newOwner);
    _avusdToken.acceptOwnership();
    assertNotEq(_avusdToken.owner(), _owner);
    assertEq(_avusdToken.owner(), _newOwner);
    vm.prank(_owner);
    vm.expectRevert("Ownable: caller is not the owner");
    _avusdToken.setMinter(_newMinter);
    assertEq(_avusdToken.minter(), _minter);
  }
}
