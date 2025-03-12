// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract TokenScript {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public constant NAME = "TokenScript";

    IERC20Upgradeable immutable token;

    constructor(address _tokenAddress) {
        token = IERC20Upgradeable(_tokenAddress);
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {
        return token.transfer(recipient, amount);
    }

    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return token.allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        return token.approve(spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        return token.transferFrom(sender, recipient, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        token.safeIncreaseAllowance(spender, addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        token.safeDecreaseAllowance(spender, subtractedValue);
        return true;
    }
}
