// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;


contract Helper {
    
    // Data1 : Bit 0: Guaranteed | Bit 1 onwards: Amount in Currency
    // Data2 : 120 bits: OverSub Amt, 120 bits: EggBurnAmt, 8 bits: Priority 
    // uint pack1 = (amtBasic << 1) | (isGuaranteed ? 1 : 0);
    // uint pack2 = (amtOverSub) | (eggTotalQty << 120) | (priority << 240);
    
    function pack(bool isGuaranteed, uint amtBasic, uint amtOverSub, uint eggTotalQty, uint priority) external pure returns (uint, uint) {
        uint pack1 = (amtBasic << 1) | (isGuaranteed ? 1 : 0);
        uint pack2 = (amtOverSub) | (eggTotalQty << 120) | (priority << 240);
        return (pack1, pack2);
    }
         
    function unPack(uint data1, uint data2) external pure returns(bool, uint, uint, uint, uint) {

        bool isGuaranteed = (data1 & 1) > 0 ? true : false;
        uint amtBasic = (data1 >> 1);
        uint amtOverSub = uint120(data2);
        uint eggTotalQty = uint120(data2 >> 120);
        uint priority = uint16(data2 >> 240);
        return (isGuaranteed, amtBasic, amtOverSub, eggTotalQty, priority);
    }
}