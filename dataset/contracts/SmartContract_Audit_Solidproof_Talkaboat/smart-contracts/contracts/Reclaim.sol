// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IMasterEntertainer.sol";
import "./chains/kardiachain/AboatToken.sol";

contract Buyback is Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    IERC20 public rewardToken; //ABOAT

    mapping(address => uint256) private claimAmount;
    mapping(address => bool) private claimed;

    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    
    event Claimed(address indexed buyer, uint256 indexed amount);
    
    constructor(IERC20 _rewardToken) {
        rewardToken = _rewardToken;
    }

    receive() external payable {}

    function getRemainingBalance() public view returns(uint256) {
        bool isRewardTokenEthToken = address(rewardToken) == address(0);
        if(isRewardTokenEthToken) {
            return address(this).balance;
        } else {
            return IERC20(rewardToken).balanceOf(address(this));
        }
    }

    function getRewardAmount() public view returns(uint256) {
        return claimAmount[msg.sender];
    }
    
    /* =====================================================================================================================
                                                        Owner
    ===================================================================================================================== */



    function claimRemainingBalance() public onlyOwner {
        bool isRewardTokenEthToken = address(rewardToken) == address(0);
        if(isRewardTokenEthToken) {
            TransferHelper.safeTransferETH(owner(), getRemainingBalance());
        } else {
            TransferHelper.safeTransfer(address(rewardToken), owner(), getRemainingBalance());
        }
    }
    
    /* =====================================================================================================================
                                                        Investors
    ===================================================================================================================== */
    
    function reclaim(address newWallet) public payable {
        require(claimAmount[msg.sender] > 0, "You are not eligible to claim tokens!");
        require(!claimed[msg.sender], "ABOAT::reclaim: You already claimed your tokens!");
        require(msg.sender != newWallet, "ABOAT::reclaim: You can't claim to the same address!");
        claimed[msg.sender] = true;
        TransferHelper.safeTransfer(address(rewardToken), newWallet, claimAmount[msg.sender]);

        emit Claimed(msg.sender, claimAmount[msg.sender]);
    }
}