// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract NinjaBounty is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public token;
    uint8 private constant decimals = 18;
    uint256 private constant decimalFactor = 10**uint256(decimals);
    uint256 public  AVAILABLE_NINJA_FOR_AIRDROP = 120000 * decimalFactor; // 120K AIRDROP
    uint256 public  AVAILABLE_NINJA_FOR_BOUNTY = 80000 * decimalFactor; // 80K AIRDROP

    function exchangeStake(address[] memory recipients, uint256[] memory values)
        public
        onlyOwner
    {
        require(recipients.length == values.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransfer(recipients[i], values[i]);
            AVAILABLE_NINJA_FOR_BOUNTY = AVAILABLE_NINJA_FOR_BOUNTY.sub(values[i]);
        }
    }

    function airdrop(address[] memory recipients, uint256[] memory values)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransfer(recipients[i], values[i]);
            AVAILABLE_NINJA_FOR_AIRDROP = AVAILABLE_NINJA_FOR_AIRDROP.sub(values[i]);
        }
    }

    function emergencyWithdraw() public onlyOwner {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function availableNinja() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
    function updateNinjaAdd(address newNinja) public onlyOwner {
        // incase of change Ninja
        require(newNinja != address(0), "Ninja Token address invalid");
        token = IERC20(newNinja);
    }
}
