// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

library intToString {
    function uint2str(uint _i, bool returnOnlyDecimals) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        if(returnOnlyDecimals){
            int only4Digits = 0;
            bytes memory bstr2 = new bytes(len - 1);
            for (uint i=0; i < bstr.length-1; i++){
                bstr2[i] = bstr[i+1];
                if(bstr[i]!='0'){
                    only4Digits += 1; // returns only 4 digits after all the zeros to avoid long price on frontend
                    if(only4Digits == 4){
                        break;
                    }
                }
            }
            return string(bstr2);
        }
        else{
            return string(bstr);
        }
    }
}