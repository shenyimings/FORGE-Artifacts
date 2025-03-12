// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Extended ERC20 interface for gTokens
interface IGToken is IERC20 {
    function mint(
        address recipient,
        uint256 factor,
        uint256 amount
    ) external;

    function burn(
        address recipient,
        uint256 factor,
        uint256 amount
    ) external;

    function burnAll(address account) external;

    function totalSupplyBase() external view returns (uint256);

    function factor() external view returns (uint256);

    function factor(uint256 amount) external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function getPricePerShare() external view returns (uint256);

    function getShareAssets(uint256 shares) external view returns (uint256);

    function getAssets(address account) external view returns (uint256);
}
