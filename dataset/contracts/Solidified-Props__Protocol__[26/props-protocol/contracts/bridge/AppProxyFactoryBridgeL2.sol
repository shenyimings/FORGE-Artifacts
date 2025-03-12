// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "../../fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";
import "../IAppProxyFactoryBridged.sol";

/**
 * @title  AppProxyFactoryBridgeL2
 * @author Props
 * @dev    This contract is responsible for handling incoming app deployments from L1.
 */
contract AppProxyFactoryBridgeL2 is FxBaseChildTunnel {
    address public appProxyFactory;

    constructor(address _fxChild, address _appProxyFactory) FxBaseChildTunnel(_fxChild) {
        appProxyFactory = _appProxyFactory;
    }

    /**
     * @dev Handles app deployments relayed from L1 via the bridge.
     */
    function _processMessageFromRoot(
        uint256,
        address _sender,
        bytes memory _data
    ) internal override validateSender(_sender) {
        (
            address l1AppPoints,
            string memory name,
            string memory symbol,
            address owner,
            uint256 dailyRewardEmission
        ) = abi.decode(_data, (address, string, string, address, uint256));

        IAppProxyFactoryBridged(appProxyFactory).deployApp(
            l1AppPoints,
            name,
            symbol,
            owner,
            dailyRewardEmission
        );
    }
}
