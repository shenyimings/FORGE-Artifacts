// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/TransferHelper.sol";

contract Airdrop is Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct User {
        address wallet;
        uint256 amount;
    }
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */


    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    
    event Airdropped(address indexed buyer, uint256 indexed amount);
    
    constructor() {
    }
    
    /* =====================================================================================================================
                                                        Investors
    ===================================================================================================================== */
    
    function airdrop(address token,  User[] memory users) public payable {
        uint arrayLength = users.length;
        require(arrayLength >= 0, "ABOAT::airdrop:There are no users for airdrop");
        for (uint i = 0; i < arrayLength; i++) {
            TransferHelper.safeTransferFrom(token, msg.sender, users[i].wallet, users[i].amount);

            emit Airdropped(users[i].wallet, users[i].amount);
        }

    }
}