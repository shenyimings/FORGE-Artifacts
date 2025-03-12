//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOpinionBounties {
    struct Bounty {
        uint amount;
        address depositor;
        uint blockHeight;
    }

    function addBountiableToken(address token) external;
    function removeBountiableToken(address token) external;
    function depositBounty(address addy, address user, address depositor, address token, uint amount) external payable;
    function rescindBounty(address addy, address user, address token) external;
    function getBountyInfo(address addy, address user, address token) external view returns (Bounty[] memory);
    function claimBounty(address addy, address token) external; //?
    function getAmountDepositedByUser(address addy, address user, address token) external view returns (uint);
    function getBountyAmountPayable(address addy, address user, address token) external view returns (uint);
    function setBountyFees(address token, uint8 fee) external;
    function toggleFeeSwitch() external;
}