pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import './dependencies/token/ERC20/ERC20.sol';
import './dependencies/token/ERC20/SafeERC20.sol';

contract AToken is ERC20 {
    using SafeERC20 for IERC20;

    address internal _underlyingAsset;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function initialize(address underlyingAsset) public {
        _underlyingAsset = underlyingAsset;
    }

    function burn(
        address user,
        address receiverOfUnderlying,
        uint256 amount //, //uint256 index
    ) public {
        _burn(user, amount);
        IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
    }

    function mint(address user, uint256 amount) public returns (bool) {
        _mint(user, amount);
        return true;
    }

    function transferUnderlyingTo(address target, uint256 amount) external returns (uint256) {
        IERC20(_underlyingAsset).safeTransfer(target, amount);
        return amount;
    }
}
