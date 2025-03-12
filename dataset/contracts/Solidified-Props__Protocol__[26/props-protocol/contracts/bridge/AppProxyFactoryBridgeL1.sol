// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "../../fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";
import "../IAppProxyFactoryBridged.sol";

/**
 * @title  AppProxyFactoryBridgeL1
 * @author Props
 * @dev    This contract is responsible for relaying app deployments to L2.
 */
contract AppProxyFactoryBridgeL1 is FxBaseRootTunnel, IAppProxyFactoryBridged {
    address public appProxyFactory;

    constructor(
        address _checkpointManager,
        address _fxRoot,
        address _appProxyFactory
    ) FxBaseRootTunnel(_checkpointManager, _fxRoot) {
        appProxyFactory = _appProxyFactory;
    }

    /**
     * @dev Trigger an L2 app deployment by relaying it over the bridge.
     * @param _l1AppPoints The L1 AppPoints token of the app
     * @param _name The name of the app
     * @param _symbol The symbol of the app
     * @param _owner The owner of the app
     * @param _dailyRewardEmission The daily reward emission parameter for the app points staking contract
     */
    function deployApp(
        address _l1AppPoints,
        string calldata _name,
        string calldata _symbol,
        address _owner,
        uint256 _dailyRewardEmission
    ) external override {
        require(msg.sender == appProxyFactory, "Unauthorized");
        _sendMessageToChild(abi.encode(_l1AppPoints, _name, _symbol, _owner, _dailyRewardEmission));
    }

    function _processMessageFromChild(bytes memory) internal pure override {
        // We don't relay messages from L2 to L1 over this bridge
    }
}
