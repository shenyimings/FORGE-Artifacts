// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../lib/forge-std/src/Test.sol";

// test currencies
IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
IERC20 constant EUROC = IERC20(0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c);
IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

contract ERC20Helper is Test {
    using stdStorage for StdStorage;

    /** 
        @notice sets the balance of who to amount. This is only possible in a test environment.
        taken from here: https://mirror.xyz/brocke.eth/PnX7oAcU4LJCxcoICiaDhq_MUUu9euaM8Y5r465Rd2U
    */
    function writeERC20Balance(address who, address _token, uint256 amount) public {
        stdstore.target(_token).sig(IERC20(_token).balanceOf.selector).with_key(who).checked_write(amount);

        require(IERC20(_token).balanceOf(who) == amount, "ERC20Helper: balance not set");
    }
}
