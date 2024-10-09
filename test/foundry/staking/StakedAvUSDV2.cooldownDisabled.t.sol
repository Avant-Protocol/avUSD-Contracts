// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable func-name-mixedcase  */
/* solhint-disable private-vars-leading-underscore  */

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import "../../../contracts/AvUSD.sol";
import "../../../contracts/StakedAvUSDV2.sol";
import "../../../contracts/interfaces/IAvUSD.sol";
import "../../../contracts/interfaces/IERC20Events.sol";
import "./StakedAvUSD.t.sol";

/// @dev Run all StakedAvUSDV1 tests against StakedAvUSDV2 with cooldown duration zero, to ensure backwards compatibility
contract StakedAvUSDV2CooldownDisabledTest is StakedAvUSDTest {
  StakedAvUSDV2 stakedAvUSDV2;

  function setUp() public virtual override {
    avusdToken = new AvUSD(address(this));

    alice = vm.addr(0xB44DE);
    bob = vm.addr(0x1DE);
    greg = vm.addr(0x6ED);
    owner = vm.addr(0xA11CE);
    rewarder = vm.addr(0x1DEA);
    vm.label(alice, "alice");
    vm.label(bob, "bob");
    vm.label(greg, "greg");
    vm.label(owner, "owner");
    vm.label(rewarder, "rewarder");

    vm.startPrank(owner);
    stakedAvUSD = new StakedAvUSDV2(IAvUSD(address(avusdToken)), rewarder, owner);
    stakedAvUSDV2 = StakedAvUSDV2(address(stakedAvUSD));

    // Disable cooldown and unstake methods, enable StakedAvUSDV1 methods
    stakedAvUSDV2.setCooldownDuration(0);
    vm.stopPrank();

    sigUtilsAvUSD = new SigUtils(avusdToken.DOMAIN_SEPARATOR());
    sigUtilsStakedAvUSD = new SigUtils(stakedAvUSD.DOMAIN_SEPARATOR());

    avusdToken.setMinter(address(this), true);
  }

  function test_cooldownShares_fails_cooldownDuration_zero() external {
    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    stakedAvUSDV2.cooldownShares(0);
  }

  function test_cooldownAssets_fails_cooldownDuration_zero() external {
    vm.expectRevert(IStakedAvUSD.OperationNotAllowed.selector);
    stakedAvUSDV2.cooldownAssets(0);
  }
}
