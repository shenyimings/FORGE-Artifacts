// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces.sol";
import "./P00lsRegistryBase.sol";
import "./P00lsTokenCreator.matic.sol";
import "./P00lsTokenXCreator.v2.sol";
import "../crosschain/matic/utils.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsCreatorRegistry_Polygon is P00lsRegistryBase, IP00lsCreatorRegistry_Polygon
{
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address                     public immutable fxChild;
    address                     public fxRootTunnel;
    mapping(address => address) public childToRoot;
    mapping(address => address) public rootToChild;

    event MessageSent(bytes message);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _fxChild) {
        fxChild = _fxChild;
    }

    function setFxRootTunnel(address _fxRootTunnel)
        external
        onlyRole(REGISTRY_MANAGER_ROLE)
    {
        require(fxRootTunnel == address(0x0), "FxBaseChildTunnel: ROOT_TUNNEL_ALREADY_SET");
        fxRootTunnel = _fxRootTunnel;
    }

    /**
     * Bridge
     */
    function processMessageFromRoot(uint256, address rootSender, bytes memory message)
        external
        override
    {
        require(msg.sender == fxChild && rootSender == fxRootTunnel, "Invalid crosschain sender");
        (BRIDGE_OP op, bytes memory data) = abi.decode(message, (BRIDGE_OP, bytes));

        if (op == BRIDGE_OP.DEPLOY)
        {
            // Create
            (
                address rootToken,
                string memory name,
                string memory symbol,
                string memory xname,
                string memory xsymbol
            ) = decodeMigrateData(data);
            deployAndInitialize(owner(), rootToken, name, symbol, xname, xsymbol);
        }
        else if (op == BRIDGE_OP.DEPOSIT)
        {
            // Bridge assets
            (
                address rootToken,
                address to,
                uint256 amount
            ) = decodeDepositData(data);
            P00lsTokenCreator_Polygon(rootToChild[rootToken]).mint(to, amount);
        }
        else
        {
            revert("unsuported operation");
        }
    }

    function __withdraw(address to, uint256 amount)
        external
    {
        address rootToken = childToRoot[msg.sender];
        require(rootToken != address(0), "No known rootToken for withdrawal");
        emit MessageSent(abi.encode(rootToken, to, amount));
    }

    function deployAndInitialize(
        address holder,
        address rootToken,
        string memory name,
        string memory symbol,
        string memory xname,
        string memory xsymbol
    )
    internal virtual returns (address)
    {
        address creator  = address(new BeaconProxy{ salt: addressToSalt(rootToken) }(beaconCreator()));
        address xCreator = address(new BeaconProxy(beaconXCreator()));

        _mint(holder, addressToUint256(creator));
        childToRoot[creator] = rootToken;
        rootToChild[rootToken] = creator;

        P00lsTokenCreator_Polygon(creator).initialize(
            name,
            symbol,
            xCreator
        );
        P00lsTokenXCreator_V2(xCreator).initialize(
            xname,
            xsymbol,
            creator
        );

        return creator;
    }
}
