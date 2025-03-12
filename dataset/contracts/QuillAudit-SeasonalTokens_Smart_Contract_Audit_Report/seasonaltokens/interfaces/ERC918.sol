    //SPDX-License-Identifier: MIT
    pragma solidity 0.8.5;


    // ----------------------------------------------------------------------------

    // ERC Token Standard #918 Interface

    // https://eips.ethereum.org/EIPS/eip-918

    // ----------------------------------------------------------------------------

    interface ERC918  {

        function mint(uint256 nonce) external returns (bool success);

        function getAdjustmentInterval() external view returns (uint);

        function getChallengeNumber() external view returns (bytes32);

        function getMiningDifficulty() external view returns (uint);

        function getMiningTarget() external view returns (uint);

        function getMiningReward() external view returns (uint);
       
        function decimals() external view returns (uint8);


        event Mint(address indexed from, uint rewardAmount, uint epochCount, bytes32 newChallengeNumber);
    }