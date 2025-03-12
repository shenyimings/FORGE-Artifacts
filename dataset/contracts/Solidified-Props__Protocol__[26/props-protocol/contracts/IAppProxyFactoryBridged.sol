// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

interface IAppProxyFactoryBridged {
    function deployApp(
        address _l1AppPoints,
        string calldata _name,
        string calldata _symbol,
        address _owner,
        uint256 _dailyRewardEmission
    ) external;
}
