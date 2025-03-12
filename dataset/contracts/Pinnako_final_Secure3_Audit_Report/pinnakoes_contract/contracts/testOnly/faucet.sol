// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "hardhat/console.sol";

contract Faucet is Ownable {
    string public name = "faucet";
    mapping(address => uint) lastClaimed;
    uint256 public minInterval = 24 hours;

    struct FaucetToken {
        address tokenAddress;
        uint256 faucetBalance;
    }

    FaucetToken[] public supportedTokens;

    function addTokens(address[] memory tokens, uint256[] memory amounts)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            addToken(tokens[i], amounts[i]);
        }
    }

    function adminClaim(address to, uint256 amount) public onlyOwner {
        for (uint i = 0; i < supportedTokens.length; i++) {
            require(
                IERC20(supportedTokens[i].tokenAddress).balanceOf(
                    address(this)
                ) >= supportedTokens[i].faucetBalance,
                "insufficient balance"
            );

            IERC20(supportedTokens[i].tokenAddress).transfer(to, amount);
        }
    }

    function claim() public {
        console.log("claim... %s.", msg.sender);
        uint256 t1 = lastClaimed[msg.sender] + minInterval;
        uint256 t2 = block.timestamp;
        console.log("claim... t1: %s, t2: %s", t1, t2);
        require(
            lastClaimed[msg.sender] + minInterval < block.timestamp,
            "already claimed recently"
        );

        lastClaimed[msg.sender] = block.timestamp;
        for (uint i = 0; i < supportedTokens.length; i++) {
            require(
                IERC20(supportedTokens[i].tokenAddress).balanceOf(
                    address(this)
                ) >= supportedTokens[i].faucetBalance,
                "insufficient balance"
            );

            IERC20(supportedTokens[i].tokenAddress).transfer(
                msg.sender,
                supportedTokens[i].faucetBalance
            );

            console.log(
                "claim... token: %s, amount: %s",
                supportedTokens[i].tokenAddress,
                supportedTokens[i].faucetBalance
            );
        }
    }

    function withdraw() public onlyOwner {
        for (uint i = 0; i < supportedTokens.length; i++) {
            IERC20(supportedTokens[i].tokenAddress).transfer(
                msg.sender,
                IERC20(supportedTokens[i].tokenAddress).balanceOf(address(this))
            );
        }
    }

    function addToken(address token, uint256 faucetAmount) public onlyOwner {
        console.log(
            "addtoken, token: %s, faucetAmount: %s",
            token,
            faucetAmount
        );
        for (uint i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i].tokenAddress == token) {
                _removeTokenByIndex(i);
                supportedTokens.push(FaucetToken(token, faucetAmount));
                return;
            }
        }
        supportedTokens.push(FaucetToken(token, faucetAmount));
    }

    function _removeTokenByIndex(uint index) public onlyOwner {
        supportedTokens[index] = supportedTokens[supportedTokens.length - 1];
        supportedTokens.pop();
    }

    function setInterval(uint256 interval) public onlyOwner {
        minInterval = interval;
    }
}
