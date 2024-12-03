// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/oapp/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAvUSD} from "./interfaces/IAvUSD.sol";
import {IStakedAvUSDV3} from "./interfaces/IStakedAvUSDV3.sol";

contract AvUSDBridging is
  ReentrancyGuard, //                                            Bridge (send) function protection
  OApp, //                                                       LayerZero contract structure
  IAny2EVMMessageReceiver, // ─────────────────────────────────╮ CCIP message receiver interface
  IERC165 // ──────────────────────────────────────────────────╯ CCIP introspection for the message receiver
{
  using SafeERC20 for IERC20;
  // ┌─────────────────────────────────────────────────────────────┐
  // | Events                                                      |
  // └─────────────────────────────────────────────────────────────┘

  event CCIPMessageReceived(
    bytes32 messageId,
    uint64 sourceChainSelector,
    address tokenSender,
    address tokenReceiver,
    uint256 tokenAmount,
    bool isStaked
  );
  event CCIPMessageSent(
    bytes32 messageId,
    uint64 destinationChainSelector,
    address tokenSender,
    address tokenReceiver,
    uint256 tokenAmount,
    bool isStaked
  );
  event CCIPPeerUpdated(uint64 chainSelector, address peer);
  event CCIPRouterUpdated(address newCCIPRouter);

  event LZMessageReceived(
    bytes32 guid,
    uint32 srcEid,
    address tokenSender,
    address tokenReceiver,
    uint256 tokenAmount,
    bool isStaked
  );
  event LZMessageSent(
    bytes32 guid,
    uint32 dstEid,
    address tokenSender,
    address tokenReceiver,
    uint256 tokenAmount,
    bool isStaked
  );

  // ┌─────────────────────────────────────────────────────────────┐
  // | Custom errors                                               |
  // └─────────────────────────────────────────────────────────────┘

  error InvalidParamError();
  error NotAuthorizedError();

  // ┌─────────────────────────────────────────────────────────────┐
  // | State                                                       |
  // └─────────────────────────────────────────────────────────────┘

  address public ccipRouter; // ───────────────────────────────╮ address for Chainlink's CCIP router on the current chain
  mapping(uint64 => address) public ccipWhitelistedPeers; // ──╯ CCIP Chain Selector => Address on the peer chain

  IAvUSD public immutable avUsd; // ───────────────────────────╮ avUSD stablecoin
  IStakedAvUSDV3 public immutable savUsd; // ──────────────────╯ staked avUSD vault

  // ┌─────────────────────────────────────────────────────────────┐
  // | Constructor                                                 |
  // └─────────────────────────────────────────────────────────────┘

  /**
   * @notice Constructor to initialize the AvUSDBridging contract.
   * @param _avUsd Address of the avUSD token contract.
   * @param _savUsd Address of the savUSD (staked avUSD) vault contract.
   * @param _lzEndpoint LayerZero endpoint for message sending/receiving.
   * @param _ccipRouter Chainlink's CCIP router address for message handling.
   * @param _owner Address of the contract owner.
   * @dev Initializes the contract, sets up the LayerZero and CCIP routers, and approves the staked avUSD vault to manage avUSD tokens.
   */
  constructor(
    address _avUsd,
    address _savUsd,
    address _lzEndpoint, /// @dev immutable, if zero will permanently disable LayerZero bridging
    address _ccipRouter, /// @dev can be set to zero at the start but modified later on
    address _owner // zero address check will be performed by the Owner constructor
  ) OApp(_lzEndpoint, _owner) Ownable(_owner) {
    if (_avUsd == address(0) || _savUsd == address(0)) {
      revert InvalidParamError();
    }
    avUsd = IAvUSD(_avUsd);
    savUsd = IStakedAvUSDV3(_savUsd);
    ccipRouter = _ccipRouter;
    /// @dev allowance for StakedAvUSD to be able to capture AvUSD when depositing
    avUsd.approve(_savUsd, type(uint256).max);
  }

  // ┌─────────────────────────────────────────────────────────────┐
  // | Admin functions                                             |
  // └─────────────────────────────────────────────────────────────┘

  /**
   * @notice Sets a whitelisted peer for a specified chain using its chain selector.
   * @param _chainSelector The chain selector for which the peer is being set.
   * @param _peer The address of the whitelisted peer on the destination chain.
   * @dev Only callable by the contract owner. Allows for cross-chain messages to/from the whitelisted peer.
   * @dev Zero address is allowed (which becomes an 'unset').
   */
  function setCCIPWhitelistedPeer(uint64 _chainSelector, address _peer) external onlyOwner {
    ccipWhitelistedPeers[_chainSelector] = _peer;
    emit CCIPPeerUpdated(_chainSelector, _peer);
  }

  /**
   * @notice Sets the CCIP router address.
   * @param _ccipRouter The new address of the CCIP router.
   * @dev Only callable by the contract owner. Setting to zero disables CCIP bridging.
   * @dev Zero address is allowed (which becomes an 'unset').
   */
  function setCCIPRouter(address _ccipRouter) external onlyOwner {
    ccipRouter = _ccipRouter;
    emit CCIPRouterUpdated(_ccipRouter);
  }

  // ┌─────────────────────────────────────────────────────────────┐
  // | Layerzero functions                                         |
  // └─────────────────────────────────────────────────────────────┘

  /**
   * @notice Quotes the fee for sending a message with LayerZero.
   * @param _dstEid The destination chain's LayerZero endpoint ID.
   * @param _tokenReceiver The receiver's address on the destination chain.
   * @param _tokenAmount The amount of tokens being transferred.
   * @param _isStaked A boolean indicating if the tokens are staked or unstaked.
   * @param _options Additional LayerZero message options (e.g., gas limit).
   * @return The quoted fee in the native token of the current chain.
   * @dev This function calculates the fee required to send a message to a LayerZero endpoint.
   * @dev The fee amount is calculated in the native token of the current chain.
   */
  function quoteSendFeeWithLayerzero(
    uint32 _dstEid,
    address _tokenReceiver,
    uint256 _tokenAmount,
    bool _isStaked,
    bytes memory _options
  ) external view returns (uint256) {
    if (address(endpoint) == address(0)) {
      revert NotAuthorizedError();
    }
    bool _payInLzToken = false;
    bytes memory _message = abi.encode(msg.sender, _tokenReceiver, _tokenAmount, _isStaked);
    MessagingFee memory _fee = _quote(_dstEid, _message, _options, _payInLzToken);
    return _fee.nativeFee;
  }

  /**
   * @notice Sends tokens across chains using LayerZero protocol.
   * @param _dstEid The destination chain's LayerZero endpoint ID.
   * @param _tokenReceiver The receiver's address on the destination chain.
   * @param _tokenAmount The amount of tokens being transferred.
   * @param _isStaked A boolean indicating if the tokens are staked or unstaked.
   * @param _options Additional LayerZero message options (e.g., gas limit).
   * @dev Transfers tokens across chains, burns them on the current chain, and emits a LayerZero message event.
   */
  function sendWithLayerzero(
    uint32 _dstEid,
    address _tokenReceiver,
    uint256 _tokenAmount,
    bool _isStaked,
    bytes calldata _options
  ) external payable nonReentrant {
    if (address(endpoint) == address(0)) {
      revert NotAuthorizedError();
    }

    _tokenAmount = _transferFromAndBurnTokens(_tokenAmount, _isStaked);

    bytes memory _message = abi.encode(msg.sender, _tokenReceiver, _tokenAmount, _isStaked);

    MessagingReceipt memory _receipt = _lzSend(
      _dstEid,
      _message,
      _options,
      // Fee in native gas and ZRO token
      MessagingFee(msg.value, 0),
      // Refund address in case of failed source message
      payable(msg.sender)
    );

    emit LZMessageSent(_receipt.guid, _dstEid, msg.sender, _tokenReceiver, _tokenAmount, _isStaked);
  }

  /**
   * @notice Receives messages sent via the LayerZero protocol.
   * @param _origin Information about the origin chain.
   * @param _guid Unique identifier for tracking the message.
   * @param _payload Encoded payload of the message.
   * @dev Decodes the payload, processes the token minting, and emits an event.
   */
  function _lzReceive(
    Origin calldata _origin,
    bytes32 _guid,
    bytes calldata _payload,
    address, // Executor address as specified by the OApp.
    bytes calldata // Any extra data or options to trigger on receipt.
  ) internal override {
    (address _tokenSender, address _tokenReceiver, uint256 _tokenAmount, bool _isStaked) = abi.decode(
      _payload,
      (address, address, uint256, bool)
    );

    emit LZMessageReceived(_guid, _origin.srcEid, _tokenSender, _tokenReceiver, _tokenAmount, _isStaked);

    _mintWithOptionalStake(_tokenReceiver, _tokenAmount, _isStaked);
  }

  // ┌─────────────────────────────────────────────────────────────┐
  // | CCIP functions                                              |
  // └─────────────────────────────────────────────────────────────┘

  /**
   * @notice Quotes the fee required to send a message via CCIP.
   * @param _destinationChainSelector The selector for the destination chain.
   * @param _tokenReceiver The recipient address on the destination chain.
   * @param _tokenAmount The amount of tokens being sent.
   * @param _isStaked Whether the tokens are staked or not.
   * @return The fee in the native token required for sending the message.
   * @dev The fee amount is calculated in the native token of the current chain.
   */
  function quoteSendFeeWithCCIP(
    uint64 _destinationChainSelector,
    address _tokenReceiver,
    uint256 _tokenAmount,
    bool _isStaked
  ) external view returns (uint256) {
    if (ccipRouter == address(0)) {
      revert NotAuthorizedError();
    }
    Client.EVM2AnyMessage memory _message = _createCCIPMessage(
      _destinationChainSelector,
      _tokenReceiver,
      _tokenAmount,
      _isStaked
    );
    return IRouterClient(ccipRouter).getFee(_destinationChainSelector, _message);
  }

  /**
   * @notice Sends tokens across chains using Chainlink CCIP protocol.
   * @param _destinationChainSelector The chain selector for the destination chain.
   * @param _tokenReceiver The receiver's address on the destination chain.
   * @param _tokenAmount The amount of tokens being transferred.
   * @param _isStaked A boolean indicating if the tokens are staked or unstaked.
   * @dev Transfers tokens across chains, burns them on the current chain, and emits a CCIP message event.
   */
  function sendWithCCIP(
    uint64 _destinationChainSelector,
    address _tokenReceiver,
    uint256 _tokenAmount,
    bool _isStaked
  ) external payable nonReentrant {
    _tokenAmount = _transferFromAndBurnTokens(_tokenAmount, _isStaked);

    Client.EVM2AnyMessage memory _message = _createCCIPMessage(
      _destinationChainSelector,
      _tokenReceiver,
      _tokenAmount,
      _isStaked
    );

    IRouterClient _router = IRouterClient(ccipRouter);
    uint256 _fee = _router.getFee(_destinationChainSelector, _message);
    /// @dev fees don't change often enough to necessitate the implementation of a refund mechanism, so the contract can expect the exact amount to be sent
    if (_fee != msg.value) {
      revert InvalidParamError();
    }

    bytes32 _messageId = _router.ccipSend{value: _fee}(_destinationChainSelector, _message);

    emit CCIPMessageSent(_messageId, _destinationChainSelector, msg.sender, _tokenReceiver, _tokenAmount, _isStaked);
  }

  /**
   * @inheritdoc IAny2EVMMessageReceiver
   * @notice Receives messages sent via the Chainlink CCIP protocol.
   * @param _message Information about the received message.
   * @dev Verifies the sender, decodes the payload, processes the token minting, and emits an event.
   */
  function ccipReceive(Client.Any2EVMMessage calldata _message) external override {
    if (msg.sender != ccipRouter) {
      revert NotAuthorizedError();
    }
    address _messageSender = abi.decode(_message.sender, (address));
    if (ccipWhitelistedPeers[_message.sourceChainSelector] != _messageSender) {
      revert NotAuthorizedError();
    }
    (address _tokenSender, address _tokenReceiver, uint256 _tokenAmount, bool _isStaked) = abi.decode(
      _message.data,
      (address, address, uint256, bool)
    );

    emit CCIPMessageReceived(
      _message.messageId,
      _message.sourceChainSelector,
      _tokenSender,
      _tokenReceiver,
      _tokenAmount,
      _isStaked
    );

    _mintWithOptionalStake(_tokenReceiver, _tokenAmount, _isStaked);
  }

  /**
   * @notice Creates a CCIP message for token transfer.
   * @param _destinationChainSelector The chain selector for the destination chain.
   * @param _tokenReceiver The receiver's address on the destination chain.
   * @param _tokenAmount The amount of tokens being transferred.
   * @param _isStaked A boolean indicating if the tokens are staked or unstaked.
   * @return A CCIP message with the encoded transfer details.
   * @dev This function builds the message to be sent across chains using CCIP.
   */
  function _createCCIPMessage(
    uint64 _destinationChainSelector,
    address _tokenReceiver,
    uint256 _tokenAmount,
    bool _isStaked
  ) internal view returns (Client.EVM2AnyMessage memory) {
    address _peer = ccipWhitelistedPeers[_destinationChainSelector];
    if (_peer == address(0)) {
      revert NotAuthorizedError();
    }
    Client.EVMTokenAmount[] memory _tokensToSendDetails = new Client.EVMTokenAmount[](0);
    return
      Client.EVM2AnyMessage({
        receiver: abi.encode(_peer),
        data: abi.encode(msg.sender, _tokenReceiver, _tokenAmount, _isStaked),
        tokenAmounts: _tokensToSendDetails,
        extraArgs: "",
        feeToken: address(0)
      });
  }

  // ┌─────────────────────────────────────────────────────────────┐
  // | Internal Utility Functions                                  |
  // └─────────────────────────────────────────────────────────────┘

  /**
   * @notice Transfers and burns tokens before cross-chain messaging.
   * @param _tokenAmount The amount of tokens to transfer and burn.
   * @param _isStaked A boolean indicating if the tokens are staked or unstaked.
   * @return The actual amount of tokens transferred and burned.
   * @dev Handles the token transfer logic and burns them for cross-chain transfers.
   */
  function _transferFromAndBurnTokens(uint256 _tokenAmount, bool _isStaked) internal returns (uint256) {
    if (_isStaked) {
      IERC20(savUsd).safeTransferFrom(msg.sender, address(this), _tokenAmount);
      _tokenAmount = savUsd.bridgeRedeem(_tokenAmount);
    } else {
      IERC20(avUsd).safeTransferFrom(msg.sender, address(this), _tokenAmount);
    }
    avUsd.burn(_tokenAmount);
    return _tokenAmount;
  }

  /**
   * @notice Mints tokens to the receiver with optional staking.
   * @param _tokenReceiver The address of the token receiver.
   * @param _tokenAmount The amount of tokens to mint.
   * @param _isStaked A boolean indicating if the tokens should be staked or unstaked.
   * @dev If `_isStaked` is true, the tokens are staked in the savUSD vault.
   */
  function _mintWithOptionalStake(address _tokenReceiver, uint256 _tokenAmount, bool _isStaked) internal {
    if (_isStaked) {
      avUsd.mint(address(this), _tokenAmount);
      savUsd.deposit(_tokenAmount, _tokenReceiver);
    } else {
      avUsd.mint(_tokenReceiver, _tokenAmount);
    }
  }

  /// @dev Indicates that this contract implements IAny2EVMMessageReceiver
  function supportsInterface(bytes4 _interfaceId) public pure virtual override returns (bool) {
    return _interfaceId == type(IAny2EVMMessageReceiver).interfaceId || _interfaceId == type(IERC165).interfaceId;
  }
}
