// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakedAvUSDV2} from "./StakedAvUSDV2.sol";

contract StakedAvUSDV3 is StakedAvUSDV2 {
  /// @notice The role that is allowed to redeem shares bypassing the cooldown mechanics
  bytes32 private constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

  constructor(IERC20 _asset, address initialRewarder, address _owner) StakedAvUSDV2(_asset, initialRewarder, _owner) {}

  /// @notice redeem shares into assets bypassing the cooldown mechanics
  /// @param shares shares to redeem
  function bridgeRedeem(uint256 shares) external onlyRole(BRIDGE_ROLE) returns (uint256 assets) {
    if (shares > maxRedeem(msg.sender)) revert ExcessiveRedeemAmount();
    assets = previewRedeem(shares);
    _withdraw(msg.sender, msg.sender, msg.sender, assets, shares);
  }
}
