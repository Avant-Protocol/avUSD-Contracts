// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2015, 2016, 2017 Dapphub
// Adapted by Ethereum Community 2021
pragma solidity 0.8.20;

import "./IWETH.sol";

/// @dev Wrapped Ether v10 (ETH10) is an Ether (ETH) ERC-20 wrapper. You can `deposit` ETH and obtain a ETH10 balance which can then be operated as an ERC-20 token. You can
/// `withdraw` ETH from ETH10, which will then burn ETH10 token in your wallet. The amount of ETH10 token in any wallet is always identical to the
/// balance of ETH deposited minus the ETH withdrawn with that specific wallet.
interface IETH10 {
  /// @dev `msg.value` of ETH sent to this contract grants caller account a matching increase in ETH10 token balance.
  /// Emits {Transfer} event to reflect ETH10 token mint of `msg.value` from `address(0)` to caller account.
  function deposit() external payable;

  /// @dev `msg.value` of ETH sent to this contract grants `to` account a matching increase in ETH10 token balance.
  /// Emits {Transfer} event to reflect ETH10 token mint of `msg.value` from `address(0)` to `to` account.
  function depositTo(address to) external payable;

  /// @dev Burn `value` ETH10 token from caller account and withdraw matching ETH to the same.
  /// Emits {Transfer} event to reflect ETH10 token burn of `value` to `address(0)` from caller account.
  /// Requirements:
  ///   - caller account must have at least `value` balance of ETH10 token.
  function withdraw(uint256 value) external;

  /// @dev Burn `value` ETH10 token from caller account and withdraw matching ETH to account (`to`).
  /// Emits {Transfer} event to reflect ETH10 token burn of `value` to `address(0)` from caller account.
  /// Requirements:
  ///   - caller account must have at least `value` balance of ETH10 token.
  function withdrawTo(address payable to, uint256 value) external;

  /// @dev Burn `value` ETH10 token from account (`from`) and withdraw matching ETH to account (`to`).
  /// Emits {Approval} event to reflect reduced allowance `value` for caller account to spend from account (`from`),
  /// unless allowance is set to `type(uint256).max`
  /// Emits {Transfer} event to reflect ETH10 token burn of `value` to `address(0)` from account (`from`).
  /// Requirements:
  ///   - `from` account must have at least `value` balance of ETH10 token.
  ///   - `from` account must have approved caller to spend at least `value` of ETH10 token, unless `from` and caller are the same account.
  function withdrawFrom(address from, address payable to, uint256 value) external;

  /// @dev `msg.value` of ETH sent to this contract grants `to` account a matching increase in ETH10 token balance,
  /// after which a call is executed to an ERC677-compliant contract with the `data` parameter.
  /// Emits {Transfer} event.
  /// Returns boolean value indicating whether operation succeeded.
  /// For more information on {transferAndCall} format, see https://github.com/ethereum/EIPs/issues/677.
  function depositToAndCall(address to, bytes calldata data) external payable returns (bool);

  /// @dev Sets `value` as allowance of `spender` account over caller account's ETH10 token,
  /// after which a call is executed to an ERC677-compliant contract with the `data` parameter.
  /// Emits {Approval} event.
  /// Returns boolean value indicating whether operation succeeded.
  /// For more information on {approveAndCall} format, see https://github.com/ethereum/EIPs/issues/677.
  function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);

  /// @dev Moves `value` ETH10 token from caller's account to account (`to`),
  /// after which a call is executed to an ERC677-compliant contract with the `data` parameter.
  /// A transfer to `address(0)` triggers an ETH withdraw matching the sent ETH10 token in favor of caller.
  /// Emits {Transfer} event.
  /// Returns boolean value indicating whether operation succeeded.
  /// Requirements:
  ///   - caller account must have at least `value` ETH10 token.
  /// For more information on {transferAndCall} format, see https://github.com/ethereum/EIPs/issues/677.
  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);
}
