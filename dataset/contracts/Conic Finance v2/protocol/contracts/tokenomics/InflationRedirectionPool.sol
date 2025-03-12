// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../LpToken.sol";
import "../../interfaces/IController.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract InflationRedirectionPool {
    event Shutdown();
    event Claim(uint256 amount);

    address public constant CONIC_MULTISIG = 0xB27DC5f8286f063F11491c8f349053cB37718bea;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IERC20Metadata public constant CNC = IERC20Metadata(0x9aE380F0272E2162340a5bB646c354271c0F5cFC);

    IController public controller;
    ILpToken public immutable lpToken;
    bool public isShutdown;

    constructor(IController _controller) {
        controller = _controller;
        lpToken = new LpToken(
            address(_controller),
            address(this),
            6,
            "Inflation redirection pool dummy token",
            "IRPDT"
        );
    }

    function underlying() external pure returns (address) {
        return USDC_ADDRESS;
    }

    function cachedTotalUnderlying() external pure returns (uint256) {
        return 1e6;
    }

    function usdExchangeRate() external pure returns (uint256) {
        return 1e18;
    }

    function rewardManager() external view returns (address) {
        return address(this);
    }

    function shutdown() external {
        require(!isShutdown, "InflationRedirectionPool: pool is shutdown");
        require(
            msg.sender == CONIC_MULTISIG,
            "InflationRedirectionPool: only multisig can shutdown"
        );
        withdrawInflation();
        isShutdown = true;
        emit Shutdown();
    }

    function poolCheckpoint() public returns (bool) {
        require(!isShutdown, "InflationRedirectionPool: pool is shutdown");
        uint256 balanceBefore = CNC.balanceOf(address(this));
        controller.lpTokenStaker().claimCNCRewardsForPool(address(this));
        emit Claim(CNC.balanceOf(address(this)) - balanceBefore);
        return true;
    }

    function withdrawInflation() public {
        poolCheckpoint();
        CNC.transfer(CONIC_MULTISIG, CNC.balanceOf(address(this)));
    }
}
