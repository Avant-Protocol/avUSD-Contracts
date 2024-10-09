// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IAvUSDDefinitions {
  /// @notice This event is fired when a minter changes
  event MinterUpdated(address indexed minter, bool isMinter);

  /// @notice Zero address not allowed
  error ZeroAddressException();
  /// @notice It's not possible to renounce the ownership
  error CannotRenounceOwnership();
  /// @notice Only the minter role can perform an action
  error OnlyMinter();
}
