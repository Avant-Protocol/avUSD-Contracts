// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IStakedAvUSDV3 is IERC20 {
  function bridgeRedeem(uint256 shares) external returns (uint256 assets);

  /** @dev See {IERC4626-deposit}. */
  function deposit(uint256 assets, address receiver) external returns (uint256);
}
