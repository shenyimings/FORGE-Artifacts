// SPDX-License-Identifier: agpl-3.0

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Campaign.sol";

contract Factory is IFactoryGetters, Ownable {
    using SafeMath for uint256;

    address private immutable launcherTokenAddress;
    
    struct CampaignInfo {
        address contractAddress;
        address owner;
    }
    // List of campaign and their project owner address. 
    // For security, only project owner can provide fund.
    mapping(uint256 => CampaignInfo) public allCampaigns;
    uint256 count;
    
    address private feeAddress;
    address private lpRouter; // Uniswap or PancakeSwap

    constructor(
        address _launcherTokenAddress,
        address _feeAddress,
        address _lpRouter
    ) public Ownable() 
    {
        launcherTokenAddress = _launcherTokenAddress;
        feeAddress = _feeAddress;
        lpRouter = _lpRouter;
    }

    /**
     * @dev Create a new campaign
     * @param _token - The token address
     * @param _subIndex - The fund raising round Id
     * @param _campaignOwner - Campaign owner address
     * @param _stats - Array of 5 uint256 values.
     * @notice - [0] Softcap. 1e18 = 1 BNB.
     * @notice - [1] Hardcap. 1e18 = 1 BNB.
     * @notice - [2] TokenSalesQty. The amount of tokens for sale. Example: 1e8 for 1 token with 8 decimals.
     * @notice - [3] feePcnt. 100% is 1e6.
     * @notice - [4] QualifyingTokenQty. Number of LAUNCH required to participate. In 1e18 per LAUNCH.
     * @param _dates - Array of 3 uint256 dates.
     * @notice - [0] Start date.
     * @notice - [1] End date.
     * @notice - [2] Mid date. For Accessibility.WhitelistedFirstThenEveryone only.
     * @param _buyLimits - Array of 2 uint256 values.
     * @notice - [0] Min amount in BNB, per purchase.
     * @notice - [1] Max accumulated amount in BNB.
     * @param _access - Everyone, Whitelisted-only, or hybrid.
     * @param _liquidity - Array of 3 uint256 values.
     * @notice - [0] BNB amount to use (from token sales) to be used to provide LP.
     * @notice - [1] Token amount to be used to provide LP.
     * @notice - [2] LockDuration of the LP tokens.
     * @param _burnUnSold - Indicate to burn un-sold tokens or not. For successful campaign only.
     * @return campaignAddress - The address of the new campaign smart contract created
     * @notice - Access control: Public, OnlyOwner
     */

    function createCampaign(
        address _token,
        uint256 _subIndex,             
        address _campaignOwner,     
        uint256[5] calldata _stats,  
        uint256[3] calldata _dates, 
        uint256[2] calldata _buyLimits,    
        Campaign.Accessibility _access,  
        uint256[3] calldata _liquidity, 
        bool _burnUnSold  
    ) external onlyOwner returns (address campaignAddress)
    {
        require(_stats[0] < _stats[1],"Soft cap can't be higher than hard cap" );
        require(_stats[2] > 0,"Token for sales can't be 0");
        require(_stats[3] <= 10e6, "Invalid fees value");
        require(_dates[0] < _dates[1] ,"Start date can't be higher than end date" );
        require(block.timestamp < _dates[1] ,"End date must be higher than current date ");
        require(_buyLimits[1] > 0, "Max allowed can't be 0" );
        require(_buyLimits[0] <= _buyLimits[1],"Min limit can't be greater than max." );

        if (_liquidity[0] > 0) { // Liquidity provision check //
            require(_liquidity[0] <= _stats[0], "BNB for liquidity cannot be greater than softcap");
            require(_liquidity[1] > 0, "Token for liquidity cannot be 0");
        } else {
            require(_liquidity[1] == 0, "Both liquidity BNB and token must be 0");
        }

        // Boundary check: After deducting for fee, the Softcap amt left is enough to create the LP
        uint256 feeAmt = _stats[0].mul(_stats[3]).div(1e6);
        require(_stats[0].sub(feeAmt) >= _liquidity[0], "Liquidity BNB amount is too high");

        if (_access == Campaign.Accessibility.WhitelistedFirstThenEveryone) {
            require((_dates[2] > _dates[0]) && (_dates[2] < _dates[1]) , "Invalid dates setup");
        }
        
        bytes memory bytecode = type(Campaign).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_token, _subIndex, msg.sender));
        assembly {
            campaignAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        Campaign(campaignAddress).initialize 
        (
            _token,
            _campaignOwner,
            _stats,
            _dates,
            _buyLimits,
            _access,
            _liquidity,
            _burnUnSold
        );
        
        allCampaigns[count] = CampaignInfo(campaignAddress, _campaignOwner);
        count = count.add(1);
        
        return campaignAddress;
    }

    /**
     * @dev Cancel a campaign
     * @param _campaignID - The campaign ID
     * @notice - Access control: External, OnlyOwner
     */    
    function cancelCampaign(uint256 _campaignID) external onlyOwner {

        require(_campaignID < count, "Invalid ID");

        CampaignInfo memory info = allCampaigns[_campaignID];
        require(info.contractAddress != address(0), "Invalid Campaign contract");
        
        Campaign camp = Campaign(info.contractAddress);
        camp.setCancelled();
    }


    /**
     * @dev Append whitelisted addresses to a campaign
     * @param _campaignID - The campaign ID
     * @param _addresses - Array of addresses
     * @notice - Access control: External, OnlyOwner
     */   
    function appendWhitelisted(uint256 _campaignID, address[] memory _addresses) external onlyOwner {
        
        require(_campaignID < count, "Invalid ID");

        CampaignInfo memory info = allCampaigns[_campaignID];
        require(info.contractAddress != address(0), "Invalid Campaign contract");
        
        Campaign camp = Campaign(info.contractAddress);
        camp.appendWhitelisted(_addresses);
    }

    /**
     * @dev Remove whitelisted addresses from a campaign
     * @param _campaignID - The campaign ID
     * @param _addresses - Array of addresses
     * @notice - Access control: External, OnlyOwner
     */  
    function removeWhitelisted(uint256 _campaignID, address[] memory _addresses) external onlyOwner {

        require(_campaignID < count, "Invalid ID");

        CampaignInfo memory info = allCampaigns[_campaignID];
        require(info.contractAddress != address(0), "Invalid Campaign contract");
        
        Campaign camp = Campaign(info.contractAddress);
        camp.removeWhitelisted(_addresses);
    }

    /**
     * @dev Add liquidity and lock it up. Called after a campaign has ended successfully.
     * @notice - Access control: External. OnlyOwner.
     */
    function addAndLockLP(uint256 _campaignID) external onlyOwner {
        require(_campaignID < count, "Invalid ID");

        CampaignInfo memory info = allCampaigns[_campaignID];
        require(info.contractAddress != address(0), "Invalid Campaign contract");
        
        Campaign camp = Campaign(info.contractAddress);
        camp.addAndLockLP();
    }

    /**
     * @dev Recover Unspent LP for a campaign
     * @param _campaignID - The campaign ID
     * @notice - Access control: External, OnlyOwner
     */    
    function recoverUnspentLp(uint256 _campaignID, address _campaignOwnerForCheck) external onlyOwner {

        require(_campaignID < count, "Invalid ID");

        CampaignInfo memory info = allCampaigns[_campaignID];
        require(info.contractAddress != address(0), "Invalid Campaign contract");
        require(info.owner == _campaignOwnerForCheck, "Invalid campaign owner"); // additional check
        
        Campaign camp = Campaign(info.contractAddress);
        camp.recoverUnspentLp();
    }

    /**
     * @dev Setup and turn on the vesting feature
     * @param _campaignID - The campaign ID
     * @param _periods - Array of period of the vesting.
     * @param _percents - Array of percents release of the vesting.
     * @notice - Access control: External. onlyFactory.
     */  
    function setupVestingMode(uint256 _campaignID, uint256[] calldata _periods, uint256[] calldata _percents) external onlyOwner {

        require(_campaignID < count, "Invalid ID");

        CampaignInfo memory info = allCampaigns[_campaignID];
        require(info.contractAddress != address(0), "Invalid Campaign contract");

        Campaign camp = Campaign(info.contractAddress);
        camp.setupVestingMode(_periods, _percents);
    }

    /**
     * @dev Start the vesting counter. This is normally done after public rounds and manual LP is provided.
     * @param _campaignID - The campaign ID
     * @notice - Access control: External. onlyFactory.
     */  
    function startVestingMode(uint256 _campaignID) external onlyOwner {

        require(_campaignID < count, "Invalid ID");

        CampaignInfo memory info = allCampaigns[_campaignID];
        require(info.contractAddress != address(0), "Invalid Campaign contract");

        Campaign camp = Campaign(info.contractAddress);
        camp.startVestingMode();
    }


    



    // IFactoryGetters
    /**
     * @dev Get the LP router address
     * @return - Return the LP router address
     * @notice - Access control: External
     */  
    function getLpRouter() external override view returns(address) {
        return lpRouter;
    }

    /**
     * @dev Get the fee address
     * @return - Return the fee address
     * @notice - Access control: External
     */  
    function getFeeAddress() external override view returns(address) {
        return feeAddress;
    }

    /**
     * @dev Get the launcher token address
     * @return - Return the address
     * @notice - Access control: External
     */ 
    function getLauncherToken() external override view returns(address) {
        return launcherTokenAddress;
    }
}
