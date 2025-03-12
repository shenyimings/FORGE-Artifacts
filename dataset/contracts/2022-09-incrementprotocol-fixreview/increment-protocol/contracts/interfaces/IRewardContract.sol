// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

interface IRewardContract {
    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function updatePosition(address market, address lp) external;
}
