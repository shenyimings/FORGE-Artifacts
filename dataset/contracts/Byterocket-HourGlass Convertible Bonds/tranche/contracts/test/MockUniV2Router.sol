pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniV2Router {
    uint256 public constant SWAP_RATE_GRANULARITY = 10000;
    uint256 public swapRate = 10000; // start with swap at 1 for 1

    function setSwapRate(uint256 newRate) public {
        swapRate = newRate;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(block.timestamp <= deadline, "Deadline");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        uint256 amountOut = (amountIn * swapRate) / SWAP_RATE_GRANULARITY;
        IERC20(path[1]).transfer(to, amountOut);

        require(amountOut >= amountOutMin, "AmountOutMin");
        amounts = new uint256[](1);
        amounts[0] = amountOut;
    }
}
