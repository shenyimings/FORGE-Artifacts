// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice $MATE staking pool contract. You come in with some $MATE, and leave with more! The longer you stay, the more $MATE you get.
 * @dev Inspired by Sushibar contract (https://github.com/sushiswap/sushiswap/blob/canary/contracts/SushiBar.sol)
 */
contract StakingPool is ERC20("xMate", "xMATE") {
    using SafeERC20 for IERC20;
    IERC20 public mate;

    constructor(IERC20 _mate) {
        mate = _mate;
    }

    /**
     * @notice Locks $MATE and mints $xMATE
     */
    function enter(uint256 _amount) public {
        uint256 totalMate = mate.balanceOf(address(this));

        uint256 totalShares = totalSupply();

        if (totalShares == 0 || totalMate == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = (_amount * totalShares) / totalMate;
            _mint(msg.sender, what);
        }

        mate.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Unlocks staked + gained $MATE and burns $xMATE
     */
    function leave(uint256 _share) public {
        uint256 totalShares = totalSupply();

        uint256 what = (_share * mate.balanceOf(address(this))) / totalShares;
        _burn(msg.sender, _share);
        mate.safeTransfer(msg.sender, what);
    }
}
