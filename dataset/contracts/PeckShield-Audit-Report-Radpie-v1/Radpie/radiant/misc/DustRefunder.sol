// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IWETH.sol";

contract DustRefunder {
    using SafeERC20 for IERC20;

    function refundDust(address _rdnt, address _weth, address _refundAddress) internal {
        IERC20 rdnt = IERC20(_rdnt);
        IWETH weth = IWETH(_weth);

        uint256 dustWETH = weth.balanceOf(address(this));
        if (dustWETH > 0) {
            weth.transfer(_refundAddress, dustWETH);
        }
        uint256 dustRdnt = rdnt.balanceOf(address(this));
        if (dustRdnt > 0) {
            rdnt.safeTransfer(_refundAddress, dustRdnt);
        }
    }
}
