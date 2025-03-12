// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IButtonWrapper.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MockRebasingERC20.sol";

contract MockButtonWrapper is Context, MockRebasingERC20, IButtonWrapper {
    IERC20 public _underlying;

    /**
     * @dev Initializes ERC20 token
     */
    constructor(
        IERC20 underlying_,
        string memory name,
        string memory symbol
    ) MockRebasingERC20(name, symbol, IERC20Metadata(address(underlying_)).decimals()) {
        _underlying = underlying_;
    }

    /**
     * @inheritdoc IButtonWrapper
     */
    function deposit(uint256 uAmount) external override returns (uint256) {
        SafeERC20.safeTransferFrom(_underlying, msg.sender, address(this), uAmount);
        uint256 amount = (uAmount * multiplier) / MULTIPLIER_GRANULARITY;
        _mint(msg.sender, amount);
        return uAmount;
    }

    /**
     * @inheritdoc IButtonWrapper
     */
    function underlying() external view override returns (address) {
        return address(_underlying);
    }
}
