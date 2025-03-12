// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

interface IResource is IERC20MetadataUpgradeable {

    /**
     * @dev Mint resource tokens
     */
    function mint(address to, uint256 amount) external;


}