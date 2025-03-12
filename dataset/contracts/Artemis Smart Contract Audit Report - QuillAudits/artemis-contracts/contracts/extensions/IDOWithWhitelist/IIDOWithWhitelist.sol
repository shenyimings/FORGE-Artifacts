//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
interface IIDOWithWhitelist {
    function WHITELISTED_ROLE() external view returns(bytes32);
    function WHITELISTER_ROLE() external view returns(bytes32);
}