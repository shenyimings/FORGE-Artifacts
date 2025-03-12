// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IStEth } from "./interfaces/IStEth.sol";
import { IOracle } from "./interfaces/IOracle.sol";

import { YToken } from "./YToken.sol";
import { HodlToken } from "./HodlToken.sol";

contract Vault {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION_FACTOR = 1 ether;

    IStEth public immutable stEth;
    YToken public immutable yToken;
    HodlToken public immutable hodlToken;
    uint256 public deposits;

    IOracle public immutable oracle;

    uint256 public immutable strike;
    bool public didTrigger = false;
    uint256 public claimed;
    uint256 public immutable deployedAt;
    uint256 public immutable deployedRoundId;

    constructor(string memory name_,
                string memory symbol_,
                uint256 strike_,
                address stEth_,
                address oracle_) {

        // Strike price with 8 decimals
        strike = strike_;

        yToken = new YToken(address(this),
                            string.concat("Yield ", name_),
                            string.concat("y", symbol_));

        hodlToken = new HodlToken(address(this),
                                  string.concat("PRT ", name_),
                                  string.concat("prt", symbol_));

        stEth = IStEth(stEth_);
        oracle = IOracle(oracle_);

        deployedAt = block.timestamp;
        deployedRoundId = oracle.roundId();
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function mint() external payable {
        require(!didTrigger, "already triggered");

        uint256 before = stEth.balanceOf(address(this));
        stEth.submit{value: msg.value}(address(0));
        uint256 delta = stEth.balanceOf(address(this)) - before;
        deposits += delta;

        hodlToken.mint(msg.sender, delta);

        // mint yToken second for proper accounting
        yToken.mint(msg.sender, delta);
    }

    function redeem(uint256 amount) external {
        require(didTrigger || IERC20(address(yToken)).balanceOf(msg.sender) >= amount);
        require(IERC20(address(hodlToken)).balanceOf(msg.sender) >= amount);

        hodlToken.burn(msg.sender, amount);

        if (!didTrigger) {
            // burn yToken second for proper accounting
            yToken.burn(msg.sender, amount);
        }

        amount = _min(amount, stEth.balanceOf(address(this)));
        stEth.transfer(msg.sender, amount);

        deposits -= amount;
    }

    function disburse(address recipient, uint256 amount) external {
        require(msg.sender == address(yToken) || msg.sender == address(hodlToken));

        IERC20(stEth).safeTransfer(recipient, amount);
        claimed += amount;
    }

    function trigger(uint80 roundId) external {
        require(roundId == 0 || oracle.timestamp(roundId) >= deployedAt, "timestamp");
        require(oracle.price(roundId) >= strike, "strike");

        yToken.trigger();
        didTrigger = true;  // do this in the middle for proper accounting
        hodlToken.trigger();
    }

    function cumulativeYield() external view returns (uint256) {
        uint256 delta = stEth.balanceOf(address(this)) - deposits;
        uint256 result = delta + claimed;
        return result;
    }
}
