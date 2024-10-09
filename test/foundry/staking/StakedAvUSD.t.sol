// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "forge-std/SigUtils.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import "../../../contracts/AvUSD.sol";
import "../../../contracts/StakedAvUSD.sol";
import "../../../contracts/interfaces/IAvUSD.sol";
import "../../../contracts/interfaces/IERC20Events.sol";

contract StakedAvUSDTest is Test, IERC20Events {
  AvUSD public avusdToken;
  StakedAvUSD public stakedAvUSD;
  SigUtils public sigUtilsAvUSD;
  SigUtils public sigUtilsStakedAvUSD;

  address public owner;
  address public rewarder;
  address public alice;
  address public bob;
  address public greg;

  bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event RewardsReceived(uint256 amount);

  function setUp() public virtual {
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

    vm.prank(owner);
    stakedAvUSD = new StakedAvUSD(IAvUSD(address(avusdToken)), rewarder, owner);

    sigUtilsAvUSD = new SigUtils(avusdToken.DOMAIN_SEPARATOR());
    sigUtilsStakedAvUSD = new SigUtils(stakedAvUSD.DOMAIN_SEPARATOR());

    avusdToken.setMinter(address(this), true);
  }

  function _mintApproveDeposit(address staker, uint256 amount) internal {
    avusdToken.mint(staker, amount);

    vm.startPrank(staker);
    avusdToken.approve(address(stakedAvUSD), amount);

    vm.expectEmit(true, true, true, false);
    emit Deposit(staker, staker, amount, amount);

    stakedAvUSD.deposit(amount, staker);
    vm.stopPrank();
  }

  function _redeem(address staker, uint256 amount) internal {
    vm.startPrank(staker);

    vm.expectEmit(true, true, true, false);
    emit Withdraw(staker, staker, staker, amount, amount);

    stakedAvUSD.redeem(amount, staker, staker);
    vm.stopPrank();
  }

  function _transferRewards(uint256 amount, uint256 expectedNewVestingAmount) internal {
    avusdToken.mint(address(rewarder), amount);
    vm.startPrank(rewarder);

    avusdToken.approve(address(stakedAvUSD), amount);

    vm.expectEmit(true, false, false, true);
    emit Transfer(rewarder, address(stakedAvUSD), amount);
    vm.expectEmit(true, false, false, false);
    emit RewardsReceived(amount);

    stakedAvUSD.transferInRewards(amount);

    assertApproxEqAbs(stakedAvUSD.getUnvestedAmount(), expectedNewVestingAmount, 1);
    vm.stopPrank();
  }

  function _assertVestedAmountIs(uint256 amount) internal {
    assertApproxEqAbs(stakedAvUSD.totalAssets(), amount, 2);
  }

  function testInitialStake() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);

    assertEq(avusdToken.balanceOf(alice), 0);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), amount);
    assertEq(stakedAvUSD.balanceOf(alice), amount);
  }

  function testInitialStakeBelowMin() public {
    uint256 amount = 0.99 ether;
    avusdToken.mint(alice, amount);
    vm.startPrank(alice);
    avusdToken.approve(address(stakedAvUSD), amount);
    vm.expectRevert(IStakedAvUSD.MinSharesViolation.selector);
    stakedAvUSD.deposit(amount, alice);

    assertEq(avusdToken.balanceOf(alice), amount);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), 0);
    assertEq(stakedAvUSD.balanceOf(alice), 0);
  }

  function testCantWithdrawBelowMinShares() public {
    _mintApproveDeposit(alice, 1 ether);

    vm.startPrank(alice);
    avusdToken.approve(address(stakedAvUSD), 0.01 ether);
    vm.expectRevert(IStakedAvUSD.MinSharesViolation.selector);
    stakedAvUSD.redeem(0.5 ether, alice, alice);
  }

  function testCannotStakeWithoutApproval() public {
    uint256 amount = 100 ether;
    avusdToken.mint(alice, amount);

    vm.startPrank(alice);
    // vm.expectRevert("ERC20: insufficient allowance");
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, stakedAvUSD, 0, amount));
    stakedAvUSD.deposit(amount, alice);
    vm.stopPrank();

    assertEq(avusdToken.balanceOf(alice), amount);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), 0);
    assertEq(stakedAvUSD.balanceOf(alice), 0);
  }

  function testStakeUnstake() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);

    assertEq(avusdToken.balanceOf(alice), 0);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), amount);
    assertEq(stakedAvUSD.balanceOf(alice), amount);

    _redeem(alice, amount);

    assertEq(avusdToken.balanceOf(alice), amount);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), 0);
    assertEq(stakedAvUSD.balanceOf(alice), 0);
  }

  function testOnlyRewarderCanReward() public {
    uint256 amount = 100 ether;
    uint256 rewardAmount = 0.5 ether;
    _mintApproveDeposit(alice, amount);

    avusdToken.mint(bob, rewardAmount);
    vm.startPrank(bob);

    // vm.expectRevert("AccessControl: account 0x72c7a47c5d01bddf9067eabb345f5daabdead13f is missing role 0xbeec13769b5f410b0584f69811bfd923818456d5edcf426b0e31cf90eed7a3f6");
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, REWARDER_ROLE));
    stakedAvUSD.transferInRewards(rewardAmount);
    vm.stopPrank();
    assertEq(avusdToken.balanceOf(alice), 0);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), amount);
    assertEq(stakedAvUSD.balanceOf(alice), amount);
    _assertVestedAmountIs(amount);
    assertEq(avusdToken.balanceOf(bob), rewardAmount);
  }

  function testStakingAndUnstakingBeforeAfterReward() public {
    uint256 amount = 100 ether;
    uint256 rewardAmount = 100 ether;
    _mintApproveDeposit(alice, amount);
    _transferRewards(rewardAmount, rewardAmount);
    _redeem(alice, amount);
    assertEq(avusdToken.balanceOf(alice), amount);
    assertEq(stakedAvUSD.totalSupply(), 0);
  }

  function testFuzzNoJumpInVestedBalance(uint256 amount) public {
    vm.assume(amount > 0 && amount < 1e60);
    _transferRewards(amount, amount);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(amount / 2);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), amount);
  }

  function testOwnerCannotRescueAvUSD() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);
    bytes4 selector = bytes4(keccak256("InvalidToken()"));
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(selector));
    stakedAvUSD.rescueTokens(address(avusdToken), amount, owner);
  }

  function testOwnerCanRescuestAvUSD() public {
    uint256 amount = 100 ether;
    _mintApproveDeposit(alice, amount);
    vm.prank(alice);
    stakedAvUSD.transfer(address(stakedAvUSD), amount);
    assertEq(stakedAvUSD.balanceOf(owner), 0);
    vm.startPrank(owner);
    stakedAvUSD.rescueTokens(address(stakedAvUSD), amount, owner);
    assertEq(stakedAvUSD.balanceOf(owner), amount);
  }

  function testOwnerCanChangeRewarder() public {
    assertTrue(stakedAvUSD.hasRole(REWARDER_ROLE, address(rewarder)));
    address newRewarder = address(0x123);
    vm.startPrank(owner);
    stakedAvUSD.revokeRole(REWARDER_ROLE, rewarder);
    stakedAvUSD.grantRole(REWARDER_ROLE, newRewarder);
    assertTrue(!stakedAvUSD.hasRole(REWARDER_ROLE, address(rewarder)));
    assertTrue(stakedAvUSD.hasRole(REWARDER_ROLE, newRewarder));
    vm.stopPrank();

    avusdToken.mint(rewarder, 1 ether);
    avusdToken.mint(newRewarder, 1 ether);

    vm.startPrank(rewarder);
    avusdToken.approve(address(stakedAvUSD), 1 ether);
    // vm.expectRevert("AccessControl: account 0x5c664540bc6bb6b22e9d1d3d630c73c02edd94b7 is missing role 0xbeec13769b5f410b0584f69811bfd923818456d5edcf426b0e31cf90eed7a3f6");
    vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, rewarder, REWARDER_ROLE));
    stakedAvUSD.transferInRewards(1 ether);
    vm.stopPrank();

    vm.startPrank(newRewarder);
    avusdToken.approve(address(stakedAvUSD), 1 ether);
    stakedAvUSD.transferInRewards(1 ether);
    vm.stopPrank();

    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), 1 ether);
    assertEq(avusdToken.balanceOf(rewarder), 1 ether);
    assertEq(avusdToken.balanceOf(newRewarder), 0);
  }

  function testAvUSDValuePerStAvUSD() public {
    _mintApproveDeposit(alice, 100 ether);
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(150 ether);
    assertEq(stakedAvUSD.convertToAssets(1 ether), 1.5 ether - 1);
    assertEq(stakedAvUSD.totalSupply(), 100 ether);
    // rounding
    _mintApproveDeposit(bob, 75 ether);
    _assertVestedAmountIs(225 ether);
    assertEq(stakedAvUSD.balanceOf(alice), 100 ether);
    assertEq(stakedAvUSD.balanceOf(bob), 50 ether);
    assertEq(stakedAvUSD.convertToAssets(1 ether), 1.5 ether - 1);

    vm.warp(block.timestamp + 4 hours);

    uint256 vestedAmount = 275 ether;
    _assertVestedAmountIs(vestedAmount);

    assertApproxEqAbs(stakedAvUSD.convertToAssets(1 ether), (vestedAmount * 1 ether) / 150 ether, 1);

    // rounding
    _redeem(bob, stakedAvUSD.balanceOf(bob));

    _redeem(alice, 100 ether);

    assertEq(stakedAvUSD.balanceOf(alice), 0);
    assertEq(stakedAvUSD.balanceOf(bob), 0);
    assertEq(stakedAvUSD.totalSupply(), 0);

    assertApproxEqAbs(avusdToken.balanceOf(alice), (vestedAmount * 2) / 3, 2);

    assertApproxEqAbs(avusdToken.balanceOf(bob), vestedAmount / 3, 2);

    assertApproxEqAbs(avusdToken.balanceOf(address(stakedAvUSD)), 0, 1);
  }

  function testFairStakeAndUnstakePrices() public {
    uint256 aliceAmount = 100 ether;
    uint256 bobAmount = 1000 ether;
    uint256 rewardAmount = 200 ether;
    _mintApproveDeposit(alice, aliceAmount);
    _transferRewards(rewardAmount, rewardAmount);
    vm.warp(block.timestamp + 4 hours);
    _mintApproveDeposit(bob, bobAmount);
    vm.warp(block.timestamp + 4 hours);
    _redeem(alice, aliceAmount);
    _assertVestedAmountIs(bobAmount + (rewardAmount * 5) / 12);
  }

  function testFuzzFairStakeAndUnstakePrices(
    uint256 amount1,
    uint256 amount2,
    uint256 amount3,
    uint256 rewardAmount,
    uint256 waitSeconds
  ) public {
    vm.assume(
      amount1 >= 100 ether && amount2 > 0 && amount3 > 0 && rewardAmount > 0 && waitSeconds <= 9 hours
      // 100 trillion USD with 18 decimals
      && amount1 < 1e32 && amount2 < 1e32 && amount3 < 1e32 && rewardAmount < 1e32
    );

    uint256 totalContributions = amount1;

    _mintApproveDeposit(alice, amount1);

    _transferRewards(rewardAmount, rewardAmount);

    vm.warp(block.timestamp + waitSeconds);

    uint256 vestedAmount;
    if (waitSeconds > 8 hours) {
      vestedAmount = amount1 + rewardAmount;
    } else {
      vestedAmount = amount1 + rewardAmount - (rewardAmount * (8 hours - waitSeconds)) / 8 hours;
    }

    _assertVestedAmountIs(vestedAmount);

    uint256 bobStakedAvUSD = (amount2 * (amount1 + 1)) / (vestedAmount + 1);
    if (bobStakedAvUSD > 0) {
      _mintApproveDeposit(bob, amount2);
      totalContributions += amount2;
    }

    vm.warp(block.timestamp + waitSeconds);

    if (waitSeconds > 4 hours) {
      vestedAmount = totalContributions + rewardAmount;
    } else {
      vestedAmount = totalContributions + rewardAmount - ((4 hours - waitSeconds) * rewardAmount) / 4 hours;
    }

    _assertVestedAmountIs(vestedAmount);

    uint256 gregStakedAvUSD = (amount3 * (stakedAvUSD.totalSupply() + 1)) / (vestedAmount + 1);
    if (gregStakedAvUSD > 0) {
      _mintApproveDeposit(greg, amount3);
      totalContributions += amount3;
    }

    vm.warp(block.timestamp + 8 hours);

    vestedAmount = totalContributions + rewardAmount;

    _assertVestedAmountIs(vestedAmount);

    uint256 avusdPerStakedAvUSDBefore = stakedAvUSD.convertToAssets(1 ether);
    uint256 bobUnstakeAmount = (stakedAvUSD.balanceOf(bob) * (vestedAmount + 1)) / (stakedAvUSD.totalSupply() + 1);
    uint256 gregUnstakeAmount = (stakedAvUSD.balanceOf(greg) * (vestedAmount + 1)) / (stakedAvUSD.totalSupply() + 1);

    if (bobUnstakeAmount > 0) _redeem(bob, stakedAvUSD.balanceOf(bob));
    uint256 avusdPerStakedAvUSDAfter = stakedAvUSD.convertToAssets(1 ether);
    if (avusdPerStakedAvUSDAfter != 0) assertApproxEqAbs(avusdPerStakedAvUSDAfter, avusdPerStakedAvUSDBefore, 1 ether);

    if (gregUnstakeAmount > 0) _redeem(greg, stakedAvUSD.balanceOf(greg));
    avusdPerStakedAvUSDAfter = stakedAvUSD.convertToAssets(1 ether);
    if (avusdPerStakedAvUSDAfter != 0) assertApproxEqAbs(avusdPerStakedAvUSDAfter, avusdPerStakedAvUSDBefore, 1 ether);

    _redeem(alice, amount1);

    assertEq(stakedAvUSD.totalSupply(), 0);
    assertApproxEqAbs(stakedAvUSD.totalAssets(), 0, 10 ** 12);
  }

  function testTransferRewardsFailsInsufficientBalance() public {
    avusdToken.mint(address(rewarder), 99);
    vm.startPrank(rewarder);

    avusdToken.approve(address(stakedAvUSD), 100);

    // vm.expectRevert("ERC20: transfer amount exceeds balance");
    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, rewarder, 99, 100));

    stakedAvUSD.transferInRewards(100);
    vm.stopPrank();
  }

  function testTransferRewardsFailsZeroAmount() public {
    avusdToken.mint(address(rewarder), 100);
    vm.startPrank(rewarder);

    avusdToken.approve(address(stakedAvUSD), 100);

    vm.expectRevert(IStakedAvUSD.InvalidAmount.selector);
    stakedAvUSD.transferInRewards(0);
    vm.stopPrank();
  }

  function testDecimalsIs18() public {
    assertEq(stakedAvUSD.decimals(), 18);
  }

  function testMintWithSlippageCheck(uint256 amount) public {
    amount = bound(amount, 1 ether, type(uint256).max / 2);
    avusdToken.mint(alice, amount * 2);

    assertEq(stakedAvUSD.balanceOf(alice), 0);

    vm.startPrank(alice);
    avusdToken.approve(address(stakedAvUSD), amount);
    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, amount, amount);
    stakedAvUSD.mint(amount, alice);

    assertEq(stakedAvUSD.balanceOf(alice), amount);

    avusdToken.approve(address(stakedAvUSD), amount);
    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, amount, amount);
    stakedAvUSD.mint(amount, alice);

    assertEq(stakedAvUSD.balanceOf(alice), amount * 2);
  }

  function testMintToDiffRecipient() public {
    avusdToken.mint(alice, 1 ether);

    vm.startPrank(alice);

    avusdToken.approve(address(stakedAvUSD), 1 ether);

    stakedAvUSD.deposit(1 ether, bob);

    assertEq(stakedAvUSD.balanceOf(alice), 0);
    assertEq(stakedAvUSD.balanceOf(bob), 1 ether);
  }

  function testCannotTransferRewardsWhileVesting() public {
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 4 hours);
    _assertVestedAmountIs(50 ether);
    vm.prank(rewarder);
    vm.expectRevert(IStakedAvUSD.StillVesting.selector);
    stakedAvUSD.transferInRewards(100 ether);
    _assertVestedAmountIs(50 ether);
    assertEq(stakedAvUSD.vestingAmount(), 100 ether);
  }

  function testCanTransferRewardsAfterVesting() public {
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 8 hours);
    _assertVestedAmountIs(100 ether);
    _transferRewards(100 ether, 100 ether);
    vm.warp(block.timestamp + 8 hours);
    _assertVestedAmountIs(200 ether);
  }

  function testDonationAttack() public {
    uint256 initialStake = 1 ether;
    uint256 donationAmount = 10_000_000_000 ether;
    uint256 bobStake = 100 ether;
    _mintApproveDeposit(alice, initialStake);
    assertEq(stakedAvUSD.totalSupply(), initialStake);
    avusdToken.mint(alice, donationAmount);
    vm.prank(alice);
    avusdToken.transfer(address(stakedAvUSD), donationAmount);
    assertEq(stakedAvUSD.totalSupply(), initialStake);
    assertEq(avusdToken.balanceOf(address(stakedAvUSD)), initialStake + donationAmount);
    _mintApproveDeposit(bob, bobStake);
    uint256 bobStAvUSDBal = stakedAvUSD.balanceOf(bob);
    uint256 bobStAvAVUSDxpectedBal = (bobStake * initialStake) / (initialStake + donationAmount);
    assertApproxEqAbs(bobStAvUSDBal, bobStAvAVUSDxpectedBal, 1e9);
    assertTrue(bobStAvUSDBal > 0);
  }
}
