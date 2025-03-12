// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LiquidityIncentive is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    string public constant NAME = "LiquidityIncentive";

    function initialize() public initializer {
        __Ownable_init();
    }

    function transferETH(address _to, uint256 _amount) external onlyOwner {
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Treasury: sending ETH failed");
    }

    function transferERC20(
        address _to,
        address _token,
        uint256 _amount
    ) external onlyOwner {
        IERC20Upgradeable(_token).transfer(_to, _amount);
    }

    // --- Fallback function ---
    receive() external payable {}
}
