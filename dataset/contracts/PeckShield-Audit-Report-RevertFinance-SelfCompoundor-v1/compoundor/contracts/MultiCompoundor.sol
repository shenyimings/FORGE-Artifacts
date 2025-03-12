// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "./ICompoundor.sol";
                                     
contract MultiCompoundor {

    ICompoundor compoundor = ICompoundor(0x5411894842e610C4D0F6Ed4C232DA689400f94A1);

    constructor() {
    }

    function runConv0Swap(uint256[] calldata tokenIds) external {
        uint256 count = tokenIds.length;
        uint256 i;
        for (; i < count; i++) {
           compoundor.autoCompound(ICompoundor.AutoCompoundParams(tokenIds[i], ICompoundor.RewardConversion.TOKEN_0, false, true));
        }
    }
    
    function runConv1Swap(uint256[] calldata tokenIds) external {
        uint256 count = tokenIds.length;
        uint256 i;
        for (; i < count; i++) {
           compoundor.autoCompound(ICompoundor.AutoCompoundParams(tokenIds[i], ICompoundor.RewardConversion.TOKEN_1, false, true));
        }
    }

    function runConv0NoSwap(uint256[] calldata tokenIds) external {
        uint256 count = tokenIds.length;
        uint256 i;
        for (; i < count; i++) {
           compoundor.autoCompound(ICompoundor.AutoCompoundParams(tokenIds[i], ICompoundor.RewardConversion.TOKEN_0, false, false));
        }
    }
    
    function runConv1NoSwap(uint256[] calldata tokenIds) external {
        uint256 count = tokenIds.length;
        uint256 i;
        for (; i < count; i++) {
           compoundor.autoCompound(ICompoundor.AutoCompoundParams(tokenIds[i], ICompoundor.RewardConversion.TOKEN_1, false, false));
        }
    }
}