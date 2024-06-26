// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IStablePoolKeeper {
  function onPrepare(uint256 amount, bytes calldata data) external;
}
