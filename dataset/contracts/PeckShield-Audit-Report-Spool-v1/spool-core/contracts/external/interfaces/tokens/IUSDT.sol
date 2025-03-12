// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IUSDT {
    function name() external view returns (string memory);

    function deprecate(address _upgradedAddress) external;

    function approve(address _spender, uint256 _value) external;

    function deprecated() external view returns (bool);

    function addBlackList(address _evilUser) external;

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external;

    function upgradedAddress() external view returns (address);

    function balances(address) external view returns (uint256);

    function decimals() external view returns (uint256);

    function maximumFee() external view returns (uint256);

    function _totalSupply() external view returns (uint256);

    function unpause() external;

    function getBlackListStatus(address _maker) external view returns (bool);

    function allowed(address, address) external view returns (uint256);

    function paused() external view returns (bool);

    function balanceOf(address who) external view returns (uint256);

    function pause() external;

    function getOwner() external view returns (address);

    function owner() external view returns (address);

    function symbol() external view returns (string memory);

    function transfer(address _to, uint256 _value) external;

    function setParams(uint256 newBasisPoints, uint256 newMaxFee) external;

    function issue(uint256 amount) external;

    function redeem(uint256 amount) external;

    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    function basisPointsRate() external view returns (uint256);

    function isBlackListed(address) external view returns (bool);

    function removeBlackList(address _clearedUser) external;

    function MAX_UINT() external view returns (uint256);

    function transferOwnership(address newOwner) external;

    function destroyBlackFunds(address _blackListedUser) external;
}
