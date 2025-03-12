// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "../IAppProxyFactoryBridged.sol";

/**
 * @dev Mock of the L1 side of the app deployment bridge used in tests.
 */
contract MockAppProxyFactoryBridgeL1 is IAppProxyFactoryBridged {
    address public appProxyFactory;

    event AppDeployed(
        address l1AppPoints,
        string name,
        string symbol,
        address owner,
        uint256 dailyRewardEmission
    );

    constructor(address _appProxyFactory) {
        appProxyFactory = _appProxyFactory;
    }

    function deployApp(
        address _l1AppPoints,
        string calldata _name,
        string calldata _symbol,
        address _owner,
        uint256 _dailyRewardEmission
    ) external override {
        require(msg.sender == appProxyFactory, "Unauthorized");
        emit AppDeployed(_l1AppPoints, _name, _symbol, _owner, _dailyRewardEmission);
    }
}
