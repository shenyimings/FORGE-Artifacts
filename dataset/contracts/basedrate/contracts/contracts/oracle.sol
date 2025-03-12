// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPool.sol";

// import "hardhat/console.sol";

contract Oracle is Ownable {
    address public token0;
    address public token1;
    IPool public pair;
    uint256 public window = 12;
    uint256 public windowTwap = 2;

    constructor(IPool _pair) {
        pair = _pair;
        token0 = pair.token0();
        token1 = pair.token1();
    }

    function observationLength() external view returns (uint256 length) {
        length = pair.observationLength();
    }

    function consult(
        address _token,
        uint256 _amountIn
    ) external view returns (uint256 amountOut) {
        uint256 currentWindow;
        uint256 length = pair.observationLength();
        if (length <= 2) {
            amountOut = 1 ether;
            return amountOut;
        } else if (length <= window + 1) {
            currentWindow = length - 1;
        } else if (length > window + 1) {
            currentWindow = window;
        }
        if (_token == token0) {
            amountOut = pair.sample(token0, _amountIn, 1, currentWindow)[0];
        } else {
            require(_token == token1, "Oracle: INVALID_TOKEN");
            amountOut = pair.sample(token1, _amountIn, 1, currentWindow)[0];
        }
    }

    function twap(
        address _token,
        uint256 _amountIn
    ) external view returns (uint256 amountOut) {
        uint256 currentWindow;
        uint256 length = pair.observationLength();
        if (length <= 2) {
            amountOut = 1 ether;
            return amountOut;
        } else if (length <= windowTwap + 1) {
            currentWindow = length - 1;
        } else if (length > windowTwap + 1) {
            currentWindow = windowTwap;
        }
        if (_token == token0) {
            amountOut = pair.sample(token0, _amountIn, 1, currentWindow)[0];
        } else {
            require(_token == token1, "Oracle: INVALID_TOKEN");
            amountOut = pair.sample(token1, _amountIn, 1, currentWindow)[0];
        }
    }

    function setWindows(
        uint256 _window,
        uint256 _windowTwap
    ) external onlyOwner {
        window = _window;
        windowTwap = _windowTwap;
    }

    function setPair(IPool _pair) external onlyOwner {
        require(address(_pair) != address(0), "Oracle: Invalid pair address");
        pair = _pair;
        token0 = pair.token0();
        token1 = pair.token1();
    }
}
