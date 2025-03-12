//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTOpinionBounties {
    struct Bounty {
        uint amount;
        address depositor;
        uint blockHeight;
    }

    function addBountiableToken(address token) external;
    function removeBountiableToken(address token) external;
    function depositBounty(uint tokenID, address user, address depositor, address token, uint amount) external payable;
    function rescindBounty(uint tokenID, address user, address token, uint amount) external;
    function getBountyInfo(uint tokenID, address user, address token) external view returns (Bounty[] memory);
    function claimBounty(uint tokenID, address token) external; //?
    function getAmountDepositedByUser(uint tokenID, address user, address depositor, address token) external view returns (uint);
    function getBountyAmountPayable(uint tokenID, address user, address token) external view returns (uint);
    function toggleFeeSwitch() external;
    function setBountyFees(address token, uint8 fee) external;
    function withdrawOwnerFees() external;
    function getOwnerFeesPayable(address token) external view returns (uint);
}