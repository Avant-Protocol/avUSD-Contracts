// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/oapp/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

contract AvUSDBridging is
    ReentrancyGuard, //                                             Send (bridge) function protection
    OApp, //                                                        LayerZero contract structure
    IAny2EVMMessageReceiver, // ──────────────────────────────────╮ CCIP message receiver interface
    IERC165 // ───────────────────────────────────────────────────╯ CCIP introspection for the message receiver
{
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
        uint64 srcEid,
        address tokenSender,
        address tokenReceiver,
        uint256 tokenAmount,
        bool isStaked
    );
    event LZMessageSent(
        bytes32 guid,
        bytes32 dstEid,
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
    // | Modifiers                                                   |
    // └─────────────────────────────────────────────────────────────┘

    modifier onlyCCIPRouter() {
        if (msg.sender != ccipRouter) {
            revert NotAuthorizedError();
        }
        _;
    }

    // ┌─────────────────────────────────────────────────────────────┐
    // | State                                                       |
    // └─────────────────────────────────────────────────────────────┘

    address public ccipRouter; // ───────────────────────────────╮ address for Chainlink's CCIP router on the current chain
    mapping(uint64 => address) public ccipWhitelistedPeers; // ──╯ CCIP Chain Selector => Address on the peer chain

    ERC20Burnable public avUsd; // ──────────────────────────────╮ avUSD stablecoin
    IERC4626 public savUsd; // ──────────────────────────────────╯ staked avUSD vault

    // ┌─────────────────────────────────────────────────────────────┐
    // | Constructor                                                 |
    // └─────────────────────────────────────────────────────────────┘

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
        avUsd = _avUsd;
        savUsd = _savUsd;
        ccipRouter = _ccipRouter;
    }

    // ┌─────────────────────────────────────────────────────────────┐
    // | Admin functions                                             |
    // └─────────────────────────────────────────────────────────────┘

    /// @dev allow for a zero address (which becomes an 'unset')
    function setCCIPWhitelistedPeer(
        uint64 _chainSelector,
        address _peer
    ) external onlyOwner {
        ccipWhitelistedPeers[_chainSelector] = _peer;
        emit CCIPPeerUpdated(_chainSelector, _peer);
    }

    /// @dev allow for a zero address (which becomes an 'unset')
    function setCCIPRouter(address _ccipRouter) external onlyOwner {
        ccipRouter = _ccipRouter;
        emit CCIPRouterUpdated(_ccipRouter);
    }

    // ┌─────────────────────────────────────────────────────────────┐
    // | Layerzero functions                                         |
    // └─────────────────────────────────────────────────────────────┘

    /// @dev fee amount is calculated in the native token of the current chain
    function quoteSendFeeWithLayerzero(
        uint32 _dstEid,
        address _tokenReceiver,
        uint256 _tokenAmount,
        bool _isStaked,
        bytes memory _options
    ) external view returns (uint256) {
        if (endpoint == address(0)) {
            revert NotAuthorizedError();
        }
        bool _payInLzToken = false;
        bytes memory _message = abi.encode(
            msg.sender,
            _tokenReceiver,
            _tokenAmount,
            _isStaked
        );
        (uint256 _nativeFee, ) = _quote(
            _dstId,
            _message,
            _options,
            _payInLzToken
        );
        return _nativeFee;
    }

    function sendWithLayerzero(
        uint32 _dstEid,
        address _tokenReceiver,
        uint256 _tokenAmount,
        bool _isStaked,
        bytes calldata _options
    ) external payable nonReentrant {
        if (endpoint == address(0)) {
            revert NotAuthorizedError();
        }

        _tokenAmount = _transferFromAndBurnTokens(_tokenAmount, _isStaked);

        bytes memory _message = abi.encode(
            msg.sender,
            _tokenReceiver,
            _tokenAmount,
            _isStaked
        );

        (bytes32 _guid, , ) = _lzSend(
            _dstEid,
            _message,
            _options,
            // Fee in native gas and ZRO token
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message
            payable(msg.sender)
        );

        emit LZMessageSent(
            _guid,
            _dstEid,
            msg.sender,
            _tokenReceiver,
            _tokenAmount,
            _isStaked
        );
    }

    /**
     * @dev Called when data is received from the protocol. It overrides the equivalent function in the parent contract.
     * Protocol messages are defined as packets, comprised of the following parameters.
     * @param _origin A struct containing information about where the packet came from.
     * @param _guid A global unique identifier for tracking the packet.
     * @param _payload Encoded message.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _payload,
        address, // Executor address as specified by the OApp.
        bytes calldata // Any extra data or options to trigger on receipt.
    ) internal override {
        (
            address _tokenSender,
            address _tokenReceiver,
            uint256 _tokenAmount,
            bool _isStaked
        ) = abi.decode(_payload, (address, address, uint256, bool));

        emit LZMessageReceived(
            _guid,
            _origin.srcEid,
            _tokenSender,
            _tokenReceiver,
            _tokenAmount,
            _isStaked
        );

        _mintWithOptionalStake(_tokenReceiver, _tokenAmount, _isStaked);
    }

    // ┌─────────────────────────────────────────────────────────────┐
    // | CCIP functions                                              |
    // └─────────────────────────────────────────────────────────────┘

    /// @dev fee amount is calculated in the native token of the current chain
    function quoteSendFeeWithCCIP(
        uint64 _destinationChainSelector,
        address _tokenReceiver,
        uint256 _tokenAmount,
        bool _isStaked
    ) external view returns (uint256) {
        if (ccipRouter == address(0)) {
            revert NotAuthorizedError();
        }
        Client.EVM2AnyMessage memory _message = _createSendMessage(
            _destinationChainSelector,
            _tokenReceiver,
            _tokenAmount,
            _isStaked
        );
        return
            IRouterClient(ccipRouter).getFee(
                _destinationChainSelector,
                _message
            );
    }

    function sendWithCCIP(
        uint64 _destinationChainSelector,
        address _tokenReceiver,
        uint256 _tokenAmount,
        bool _isStaked
    ) external payable nonReentrant {
        _tokenAmount = _transferFromAndBurnTokens(_tokenAmount, _isStaked);
        Client.EVM2AnyMessage memory _message = _createSendMessage(
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
        bytes32 _messageId = _router.ccipSend{value: _fee}(
            _destinationChainSelector,
            _message
        );
        emit CCIPMessageSent(
            _messageId,
            _destinationChainSelector,
            msg.sender,
            _tokenReceiver,
            _tokenAmount,
            _isStaked
        );
    }

    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(
        Client.Any2EVMMessage calldata _message
    ) external override onlyCCIPRouter {
        address _messageSender = abi.decode(_message.sender, (address));
        if (
            ccipWhitelistedPeers[_message.sourceChainSelector] != _messageSender
        ) {
            revert NotAuthorizedError();
        }
        (
            address _tokenSender,
            address _tokenReceiver,
            uint256 _tokenAmount,
            bool _isStaked
        ) = abi.decode(_message.data, (address, address, uint256, bool));

        emit MessageReceived(
            _message.messageId,
            _message.sourceChainSelector,
            _tokenSender,
            _tokenReceiver,
            _tokenAmount
        );

        _mintWithOptionalStake(_tokenReceiver, _tokenAmount, _isStaked);
    }

    function _createSendMessage(
        uint64 _destinationChainSelector,
        address _tokenReceiver,
        uint256 _tokenAmount,
        bool _isStaked
    ) internal view returns (Client.EVM2AnyMessage memory) {
        address _peer = ccipWhitelistedPeers[_destinationChainSelector];
        if (_peer == address(0)) {
            revert NotAuthorizedError();
        }
        Client.EVMTokenAmount[]
            memory _tokensToSendDetails = new Client.EVMTokenAmount[](0);
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_peer),
                data: abi.encode(
                    msg.sender,
                    _tokenReceiver,
                    _tokenAmount,
                    _isStaked
                ),
                tokenAmounts: _tokensToSendDetails,
                extraArgs: "",
                feeToken: address(0)
            });
    }

    /// @dev Indicates that this contract implements IAny2EVMMessageReceiver
    function supportsInterface(
        bytes4 _interfaceId
    ) public pure virtual override returns (bool) {
        return
            _interfaceId == type(IAny2EVMMessageReceiver).interfaceId ||
            _interfaceId == type(IERC165).interfaceId;
    }

    // ┌─────────────────────────────────────────────────────────────┐
    // | Common/Helper functions                                     |
    // └─────────────────────────────────────────────────────────────┘

    function _transferFromAndBurnTokens(
        uint256 _tokenAmount,
        bool _isStaked
    ) internal returns (uint256) {
        if (_isStaked) {
            savUsd.transferFrom(msg.sender, address(this), _tokenAmount);
            _tokenAmount = savUsd.redeem(
                _tokenAmount,
                address(this),
                address(this)
            );
        } else {
            avUsd.transferFrom(msg.sender, address(this), _tokenAmount);
        }
        avUsd.burn(_tokenAmount);
        return _tokenAmount;
    }

    function _mintWithOptionalStake(
        address _tokenReceiver,
        uint256 _tokenAmount,
        bool _isStaked
    ) internal {
        if (_isStaked) {
            avUsd.mint(address(this), _tokenAmount);
            savUsd.deposit(_tokenAmount, _tokenReceiver);
        } else {
            avUsd.mint(_tokenReceiver, _tokenAmount);
        }
    }
}
