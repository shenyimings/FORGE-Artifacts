// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IFeePool {

    function earned(address account) external view returns(uint, uint);

    function notifyBORFeeAmount(uint amount) external;
    function notifyBTokenFeeAmount(uint amount) external;
    function notifyPTokenAmount(address account, uint amount) external;
    
    function withdraw(address account, uint amount) external;

}