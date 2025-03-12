// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

interface IdETH is IERC20Upgradeable, IERC20PermitUpgradeable {
    function mint(address _receiver, uint256 _amount) external;

    function burn(uint256 _amount) external;

    function burnFrom(address _account, uint256 _amount) external;

    function minterMint(address _receiver, uint256 _amount) external;

    function minterBurn(uint256 _amount) external;

    function mintCap(address _minter) external view returns (uint256);

    function mintAmount(address _minter) external view returns (uint256);
}
