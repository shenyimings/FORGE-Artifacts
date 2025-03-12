// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IMasterEntertainer.sol";

contract BalanceHelper {
    using Address for address;
    using SafeMath for uint256;

    IERC20 _token;
    IMasterEntertainer _masterEntertainer;

    struct Stake {
        uint32 VestingDays;
        uint256 TokenBalance;
    }

    
    constructor(IERC20 token, IMasterEntertainer masterEntertainer) {
        _token = token;
        _masterEntertainer = masterEntertainer;
    }

    function getTokenBalanceOf(address[] memory userAddresses) public view returns(uint256) {
        uint256 tokenBalance = 0;
        for (uint i = 0; i < userAddresses.length; i++) 
        {
            tokenBalance = tokenBalance.add(_token.balanceOf(userAddresses[i]));
        }
        return tokenBalance;
    }

    function GetStakedBalance(uint32[] memory vestingDays, address[] memory userAddresses) public view returns(Stake[] memory) {
        Stake[] memory stakes = new Stake[](vestingDays.length);
        for (uint i = 0; i < vestingDays.length; i++) 
        {
            stakes[i].VestingDays = vestingDays[i];
            stakes[i].TokenBalance = 0;
        }
        for (uint i = 0; i < userAddresses.length; i++) 
        {
            for (uint z = 0; z < vestingDays.length; z++) 
            {
                stakes[z].TokenBalance = stakes[z].TokenBalance.add(_masterEntertainer.getBalanceOf(userAddresses[i], vestingDays[z]));
            }
        }
        return stakes;
    }
    

}