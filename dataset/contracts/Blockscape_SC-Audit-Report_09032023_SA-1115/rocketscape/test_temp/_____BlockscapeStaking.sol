// // SPDX-License-Identifier: BUSL-1.1

// pragma solidity 0.8.16;


// /// @dev for a token the validator can only be set once otherwise revert
// error ValidatorAlreadySet(address _vali);

// // TODO: add all natspec
// abstract contract BlockscapeStaking {
//     /** 
//         @notice initial tokenID
//         @dev the tokenID is used to identify the ETH NFTs
//     */
//     uint256 tokenID = 1;

//     // TODO: implement change function
//     uint256 timelockWithdraw = 7 days;

//     /// @notice Current initial withdraw fee
//     uint256 public initWithdrawFee = 20 * 1e18;

//     /// @dev Mappings of tokenID to timestamp to track a request withdrawal
//     mapping(address => uint256) public senderToTimestamp;

//     /// @dev Metadata struct
//     struct Metadata {
//         uint256 stakedETH;
//         uint256 stakedTimestamp;
//     }

//     /// @dev event for when a batch is tried to withdrawn but not enough rpl
//     /// are available yet
//     // TODO: Not used??
//     // event RPLStakeRequired(uint256 _availRPL, uint256 _requiredRPL);

    

//     /// @dev Mappings of tokenID to Metadata
//     mapping(uint256 => Metadata) tokenIDtoMetadata;

//     /// @dev Mappings of tokenID to the final exit reward for the staker
//     mapping(uint256 => uint256) public tokenIDToExitReward;

//     /**
//         @notice creates and mints metadata for a given NFT tokenID
//         @param _stakedETH staked amount from the sender
//         @param _tokenID Identifier of the vault
//     */
   
// }
