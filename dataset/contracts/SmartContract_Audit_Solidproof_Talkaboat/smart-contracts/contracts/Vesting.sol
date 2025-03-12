// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/TransferHelper.sol";

contract Vesting is Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    //0x27C91AEEd9951f6A249331b1137F12233dC6F7d8
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    IERC20 public rewardToken; //Aboat Token
    uint256 public claimOpen = 0;
    uint256 constant public period = 30; //How many days are between each claim 
    uint256 constant public initialClaimPercentage = 50; //How much can investors claim directly after sale ended | 100 = 10%
    uint256 constant public percentagePerPeriod = 25; //How much can investors claim per period after the initial claim | 100 = 10%
    uint256 constant public cliffPeriod = 0; //How many days after initial claim before percentagePerPeriod takes place

    uint256 constant public timeMultiplier = 1 days;
    
    bool public requireWhitelist = true;    //flag to determine whether buyers have to be whitelisted or not
    
    mapping(address => uint256) public bought;  //tracks who bought how many aboat token
    mapping(address => uint256) public claimed; //tracks who claimed how much percentage of his tokens
    mapping(address => uint256) public claimedTokens; //tracks who claimed how many aboat token
    mapping(address => address) public lastClaimAddress; //In case we have to swap the token contract

    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    event ClaimOpened(uint256 indexed claimDate);
    event Claimed(address indexed owner, uint256 indexed amount);
    event Bought(address indexed buyer, uint256 indexed amount);
    event ChangeRewardToken(address indexed newToken);
    event DepositedInVestingPool(address indexed owner, uint256 indexed amount);
    event AddedToWhitelist(uint256 indexed amount);
    event AddedToWhitelistFromSaft(uint256 indexed amount);
    
    constructor(IERC20 _rewardToken) {
        rewardToken = _rewardToken;
    }
    
    
    /* =====================================================================================================================
                                                        Owner
    ===================================================================================================================== */

    function openClaim() public onlyOwner {
        require(claimOpen == 0, "Claim is already opened");
        claimOpen = block.timestamp;
        emit ClaimOpened(block.timestamp);
    }
    
    
    //Will only be required if the token security audit displays errors that have to be fixed
    //which would mean a new contract has to be deployed.
    //With this function we can ensure that early investors will still be able to get the right coin before release
    function updateRewardToken(IERC20 _newRewardToken) public onlyOwner {
        require(_newRewardToken != rewardToken, "ABOAT::updateRewardToken: New reward should be different from current.");
        require(_newRewardToken.balanceOf(address(this)) == rewardToken.balanceOf(address(this)), "ABOAT::updateRewardToken: The contract should contain atleast the same amount of tokens as from the current rewardToken");
        rewardToken = _newRewardToken;
        emit ChangeRewardToken(address(rewardToken));
    }
    

    function whitelistFromSAFT(address[] memory addresses, uint256[] memory amounts) public onlyOwner {
        require(addresses.length <= 100, "ABOAT::whitelist: You can't add more than 100 addresses at the same time");
        for(uint index = 0; index < addresses.length; index++) {
            bought[addresses[index]] = bought[addresses[index]].add(amounts[index]);
            lastClaimAddress[addresses[index]] = address(rewardToken);
        }
        emit AddedToWhitelistFromSaft(addresses.length);
    }
    
    /* =====================================================================================================================
                                                        General
    ===================================================================================================================== */
    
    function getCurrentPercentage() public view returns (uint256) {
        uint256 cliffEnded = claimOpen.add(cliffPeriod);
        uint256 deltaPeriod = cliffEnded;
        uint256 percentage = claimOpen > 0 && block.timestamp > deltaPeriod
        ? block.timestamp.sub(deltaPeriod)
            .div(period * timeMultiplier)
            .mul(percentagePerPeriod)
            .add(initialClaimPercentage) 
        : initialClaimPercentage;
        return percentage > 1000 ? 1000 : percentage;
    }
    
    
    /* =====================================================================================================================
                                                        Investors
    ===================================================================================================================== */
       
    //returns the reward token if softcap is reached and owner ended the sale
    //otherwise it returns the paid paymentToken
    function claim() public {
        require(claimOpen != 0, "ABOAT::claim: Claim is not open yet!");
        uint256 currentPercentage = getCurrentPercentage();
        require(currentPercentage > 0, "ABOAT::claim: The percentage of token you can claim is currently zero. Please try again later");
        if(lastClaimAddress[msg.sender] != address(rewardToken)) {
            lastClaimAddress[msg.sender] = address(rewardToken);
            claimed[msg.sender] = 0;
            claimedTokens[msg.sender] = 0;
        }
        require(claimed[msg.sender] < currentPercentage, "ABOAT::claim: Already claimed your currently eligible tokens");

            uint256 currentlyClaimed = claimed[msg.sender];
            claimed[msg.sender] = currentPercentage;
            uint256 amount = bought[msg.sender].mul(currentPercentage.sub(currentlyClaimed)).div(1000);
            claimedTokens[msg.sender] = claimedTokens[msg.sender].add(amount);
            if(address(rewardToken) != address(0)) {
                TransferHelper.safeTransfer(address(rewardToken), msg.sender, amount);
            } else {
                TransferHelper.safeTransferETH(msg.sender, amount);
            }
            emit Claimed(msg.sender, amount);
       
    }
}