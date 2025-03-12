// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IEToken is IERC20Upgradeable {
    event CollateralManagerAddressChanged(address _collateralManagerAddress);
    event TokenAddressChanged(address _tokenAddress);

    function mint(address _account, uint256 _amount) external returns (uint256);

    function burn(address _account, uint256 _amount) external returns (uint256);

    function clear(address _account) external;

    function reset(
        address _account,
        uint256 _amount
    ) external returns (uint256);

    function sharesOf(address _account) external view returns (uint256);

    function getShare(uint256 _amount) external view returns (uint256);

    function getAmount(uint256 _share) external view returns (uint256);
}
