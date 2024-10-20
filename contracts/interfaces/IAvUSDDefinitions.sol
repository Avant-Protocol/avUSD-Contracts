// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IAvUSDDefinitions {
  /// @notice This event is fired when the minter changes
  event MinterUpdated(address indexed oldMinter, address indexed newMinter);

  /// @notice Zero address not allowed
  error ZeroAddressException();
  /// @notice It's not possible to renounce the ownership
  error CannotRenounceOwnership();
  /// @notice Only the minter role can perform an action
  error OnlyMinter();
}
