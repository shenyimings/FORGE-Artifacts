// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@maticnetwork/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";
import "../../tokens/interfaces.sol";
import "../../utils/convert.sol";
import "./utils.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsBridgePolygon is FxBaseRootTunnel, IERC1363Receiver {
    IERC721 public immutable registry;
    mapping(address => bool) public isBridged;

    event ContractMigrated(address indexed token);
    event BridgeDeposit(address indexed token, address indexed from, address indexed to, uint256 amount);
    event BridgeWithdraw(address indexed token, address indexed to, uint256 amount);

    constructor(address _checkpointManager, address _fxRoot, IERC721 _registry)
        FxBaseRootTunnel(_checkpointManager, _fxRoot)
    {
        registry = _registry;
    }

    modifier onlyValidToken(address token) {
        require(
            token != address(registry) &&
            registry.ownerOf(addressToUint256(token)) != address(0),
            "P00lsBridgePolygon: invalid token"
        );
        _;
    }

    modifier onlyMigrated(address token) {
        if (!isBridged[token]) migrate(token);
        _;
    }

    /**
     * Deploy token contract on child (root → child)
     */
    function migrate(address token)
        public
        onlyValidToken(token)
    {
        // mark as deployed
        isBridged[token] = true;

        IP00lsTokenCreator  rootToken  = IP00lsTokenCreator(token);
        IP00lsTokenXCreator xRootToken = rootToken.xCreatorToken();
        _sendMessageToChild(encodeMigrate(
            token,
            rootToken.name(),
            rootToken.symbol(),
            xRootToken.name(),
            xRootToken.symbol()
        ));
        emit ContractMigrated(token);
    }

    /**
     * Bridge assets to child (root → child)
     */
    function bridge(address token, address to, uint256 amount)
        public
        onlyMigrated(token)
    {
        require(to != address(0), "P00lsBridgePolygon: invalid receiver");
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        _sendMessageToChild(encodeDeposit(token, to, amount));
        emit BridgeDeposit(token, msg.sender, to, amount);
    }

    function onTransferReceived(address, address from, uint256 value, bytes calldata data)
        public
        onlyMigrated(msg.sender)
        returns (bytes4)
    {
        address to = abi.decode(data, (address));
        require(to != address(0), "P00lsBridgePolygon: invalid receiver");
        _sendMessageToChild(encodeDeposit(msg.sender, to, value));
        emit BridgeDeposit(msg.sender, from, to, value);
        return this.onTransferReceived.selector;
    }

    /**
     * Withdraw asset (child → root)
     */
    function _processMessageFromChild(bytes memory message)
        internal
        override
    {
        (address rootToken, address to, uint256 amount) = abi.decode(message, (address, address, uint256));
        SafeERC20.safeTransfer(IERC20(rootToken), to, amount);
        emit BridgeWithdraw(rootToken, to, amount);
    }
}