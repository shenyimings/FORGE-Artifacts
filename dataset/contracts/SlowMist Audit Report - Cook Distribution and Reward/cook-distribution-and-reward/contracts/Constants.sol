/*
    Copyright 2020 Cook Finance Devs, based on the works of the Cook Finance Squad

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

library Constants {

    /* Oracle */
    // only for ropsten
    address private constant WETH = address(0x0635c2b5320cee919ddAa5780308CE6dE8fDFf71);
    address private constant USDC = address(0x0635c2b5320cee919ddAa5780308CE6dE8fDFf71);
    uint256 private constant ORACLE_RESERVE_MINIMUM = 1e8; // 100 USDC


    /**
     * Getters
     */
    function getWethAddress() internal pure returns (address) {
        return WETH;
    }

    function getUsdcAddress() internal pure returns (address) {
        return USDC;
    }

    function getOracleReserveMinimum() internal pure returns (uint256) {
        return ORACLE_RESERVE_MINIMUM;
    }

}
