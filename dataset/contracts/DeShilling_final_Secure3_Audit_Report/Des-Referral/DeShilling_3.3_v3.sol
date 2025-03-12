//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';

contract ReferralInvestment {
    using SafeERC20 for IERC20;

    event investmentERC20(address investor, uint256 amount, address _referralAddress, string referralId);
    event investmentETH(address investor, uint256 amount, address _referralAddress, string referralId);

    struct Campaign {
        address vendor;
        uint256 fee;
        address campaignWallet;
        Round[] rounds;
    }

    struct Earning {
        uint256 amount;
        address wallet;
    }

    struct Round {
        uint256 startDate;
        uint256 endDate;
        uint256 maxEth;
        uint256 investedEth;
        uint256 maxToken;
        uint256 investedToken;
    }

    mapping(uint256 => Campaign) public campaigns;

    address public token;
    address admin;

    constructor(address _token) {
        token = _token;
        admin = msg.sender;
    }

    function startCampaign(uint256 id, uint256 _fee, address _vendor, address _campaignWallet, Round[] memory _rounds) public {
        require(msg.sender != admin, "Must be Master Admin.");
        require(campaigns[id].vendor == address(0), "Campaign exists.");
        require(_fee < (10**8), "Invalid commission value.");
        require(_rounds.length > 0, "Requires one set of dates.");
        require(_vendor != address(0), "Campaign must have a vendor.");
        require(_campaignWallet != address(0), "Campaign must have a Campaign Wallet.");
        campaigns[id].vendor = _vendor;
        campaigns[id].fee = _fee;
        campaigns[id].campaignWallet = _campaignWallet;
        for(uint i=0; i<_rounds.length; i++){
            campaigns[id].rounds.push(Round(_rounds[i].startDate, _rounds[i].endDate, _rounds[i].maxEth, 0, _rounds[i].maxToken, 0));
        }
    }

    function invest(uint256 _amount, uint256 _campaignId, address _referralAddress, string memory _referralId) public payable {
        require(msg.sender != campaigns[_campaignId].vendor, "Invalid Investor.");
        require(_referralAddress != msg.sender, "Invalid Referral");
        require(_referralAddress != campaigns[_campaignId].vendor, "Invalid Referral");
        require(campaigns[_campaignId].vendor != address(0), "Campaign does not exist.");

        bool pass = false;
        uint i;
        Round memory round;
        for(i=0; i<campaigns[_campaignId].rounds.length; i++){
            round = campaigns[_campaignId].rounds[i];
            if (block.timestamp >= round.startDate && block.timestamp <= round.endDate){
                pass = true;
                break;
            }
        }
        require (pass, "No Active Round of Funding.");
        address payable campaignW = payable(campaigns[_campaignId].campaignWallet);
        if (msg.value > 0){
            require (round.investedEth + msg.value < round.maxEth || round.maxEth == 0, "Max Investment Reached.");
            if (_referralAddress != address(0)){
                uint256 toCampaignWallet = msg.value*campaigns[_campaignId].fee/(10**8);
                uint256 toVendor = msg.value - toCampaignWallet;
                campaignW.transfer(toCampaignWallet);
                payable(campaigns[_campaignId].vendor).transfer(toVendor);
            }
            else{
                payable(campaigns[_campaignId].vendor).transfer(msg.value);
            }
            campaigns[_campaignId].rounds[i].investedEth += msg.value;
            emit investmentETH(msg.sender, msg.value, _referralAddress, _referralId);
        }
        else if (_amount > 0){
            require (round.investedToken + _amount < round.maxToken || round.maxToken == 0, "Max Investment Reached.");
            if (_referralAddress != address(0)){
                uint256 toCampaignWallet = _amount*campaigns[_campaignId].fee/(10**8);
                uint256 toVendor = _amount - toCampaignWallet;
                IERC20(token).safeTransferFrom(msg.sender, campaignW, toCampaignWallet);
                IERC20(token).safeTransferFrom(msg.sender, campaigns[_campaignId].vendor, toVendor);
            }
            else{
                IERC20(token).safeTransferFrom(msg.sender, campaigns[_campaignId].vendor, _amount);
            }
            campaigns[_campaignId].rounds[i].investedToken += _amount;
            emit investmentERC20(msg.sender, _amount, _referralAddress, _referralId);
        }
    }

    function changeCampaignWallet(uint256 _campaignId, address _campaignWallet) public {
        require (msg.sender == admin , "Only Admin can Access");
        campaigns[_campaignId].campaignWallet = _campaignWallet;
    }

    function distribute(Earning[] memory _earnings) public payable {
        for(uint i=0; i<_earnings.length; i++){
            address payable earningWallet = payable(_earnings[i].wallet);
            earningWallet.transfer(_earnings[i].amount);
        } 
    }

    function distributeToken(Earning[] memory _earnings) public payable {
        for(uint i=0; i<_earnings.length; i++){
            address payable earningWallet = payable(_earnings[i].wallet);
            IERC20(token).safeTransferFrom(msg.sender, earningWallet, _earnings[i].amount);
        } 
    }
}
